import Foundation

#if !GYMTRACKER_EXTENSION

/// A concrete, end-exclusive report interval. The report never silently
/// expands a date selection to include neighbouring history.
struct TrainingReportDateRange: Equatable, Sendable {
    let start: Date
    let end: Date

    var isValid: Bool { start < end }

    func contains(_ date: Date) -> Bool {
        isValid && date >= start && date < end
    }
}

/// The export boundary is explicit. An empty workout selection means that the
/// caller intentionally selected no workouts; it does not mean "all workouts".
struct TrainingReportSelection: Equatable {
    let dateRange: TrainingReportDateRange
    let selectedPlanIDs: Set<UUID>
    let selectedWorkoutIDs: Set<UUID>
    let includeSportSpecificPerformance: Bool
    let includeMobility: Bool
    let includeProgressionReceipts: Bool
    let includeNotesAndEvidence: Bool

    init(
        dateRange: TrainingReportDateRange,
        selectedPlanIDs: Set<UUID> = [],
        selectedWorkoutIDs: Set<UUID>,
        includeSportSpecificPerformance: Bool = false,
        includeMobility: Bool = false,
        includeProgressionReceipts: Bool = false,
        includeNotesAndEvidence: Bool = false
    ) {
        self.dateRange = dateRange
        self.selectedPlanIDs = selectedPlanIDs
        self.selectedWorkoutIDs = selectedWorkoutIDs
        self.includeSportSpecificPerformance = includeSportSpecificPerformance
        self.includeMobility = includeMobility
        self.includeProgressionReceipts = includeProgressionReceipts
        self.includeNotesAndEvidence = includeNotesAndEvidence
    }
}

enum TrainingReportDataAvailability: String, Codable, CaseIterable, Hashable, Sendable {
    case recorded
    case zero
    case missing
    case unavailable
}

struct TrainingReportSourceReference: Equatable, Hashable, Sendable {
    let workoutID: UUID?
    let planID: UUID?
    let receiptID: UUID?
    let mobilitySessionID: UUID?

    init(
        workoutID: UUID? = nil,
        planID: UUID? = nil,
        receiptID: UUID? = nil,
        mobilitySessionID: UUID? = nil
    ) {
        self.workoutID = workoutID
        self.planID = planID
        self.receiptID = receiptID
        self.mobilitySessionID = mobilitySessionID
    }
}

struct TrainingReportSummaryRow: Equatable, Identifiable {
    let id: String
    let title: String
    let value: String?
    let availability: TrainingReportDataAvailability
    let source: TrainingReportSourceReference?

    var humanReadableLine: String {
        switch availability {
        case .recorded:
            return value.map { "\(title): \($0)" } ?? "\(title): Missing"
        case .zero:
            return "\(title): 0"
        case .missing:
            return "\(title): Missing"
        case .unavailable:
            return "\(title): Unavailable"
        }
    }
}

enum TrainingReportSectionKind: String, Codable, CaseIterable, Hashable, Sendable {
    case summary
    case workouts
    case sportSpecificPerformance
    case mobility
    case progressionReceipts
    case notesAndEvidence
}

struct TrainingReportSection: Equatable, Identifiable {
    let kind: TrainingReportSectionKind
    let title: String
    let rows: [TrainingReportSummaryRow]

    var id: TrainingReportSectionKind { kind }
}

/// Categories are deliberately privacy-oriented rather than UI-oriented. A
/// preview lists categories even when a future renderer changes its layout.
enum TrainingReportSensitiveCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case workoutPerformance
    case planIdentity
    case sportSpecificPerformance
    case mobility
    case progressionReceipts
    case notesAndEvidence
}

enum TrainingReportShareConfirmation: String, Codable, CaseIterable, Hashable, Sendable {
    case notConfirmed
    case explicitlyConfirmed
}

struct TrainingReportArtifactPreview: Equatable {
    let includedSensitiveCategories: [TrainingReportSensitiveCategory]
    let selectedWorkoutCount: Int
    let selectedPlanCount: Int
    let sectionCount: Int
    let rowCount: Int
    let requiresExplicitShareConfirmation: Bool
    let shareConfirmation: TrainingReportShareConfirmation

    var mayShare: Bool {
        requiresExplicitShareConfirmation && shareConfirmation == .explicitlyConfirmed
    }

    func confirmingShare() -> Self {
        Self(
            includedSensitiveCategories: includedSensitiveCategories,
            selectedWorkoutCount: selectedWorkoutCount,
            selectedPlanCount: selectedPlanCount,
            sectionCount: sectionCount,
            rowCount: rowCount,
            requiresExplicitShareConfirmation: requiresExplicitShareConfirmation,
            shareConfirmation: .explicitlyConfirmed
        )
    }
}

struct TrainingReportArtifact: Equatable {
    let selection: TrainingReportSelection
    let sections: [TrainingReportSection]
    let preview: TrainingReportArtifactPreview

    /// Deterministic text suitable for a later local file/PDF renderer. This
    /// is intentionally not a renderer and never touches the share sheet.
    var humanReadableText: String {
        sections.map { section in
            (["## \(section.title)"] + section.rows.map(\.humanReadableLine)).joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }
}

enum TrainingReportProjection {
    static func build(
        selection: TrainingReportSelection,
        workouts: [Workout],
        mobilitySessions: [MobilitySession] = [],
        progressionReceipts: [PlanProgressionRecommendationRecord] = [],
        sportConfiguration: WeightliftingAnalyticsConfiguration = .init()
    ) -> TrainingReportArtifact {
        let selectedWorkouts = workouts
            .filter { $0.status == .completed }
            .filter { selection.selectedWorkoutIDs.contains($0.id) }
            .filter { selection.dateRange.contains($0.startTime) }
            .filter { selection.selectedPlanIDs.isEmpty || $0.sourcePlanID.map(selection.selectedPlanIDs.contains) == true }
            .sorted { workoutOrder(lhs: $0, rhs: $1) }

        let selectedWorkoutIDs = Set(selectedWorkouts.map(\.id))

        var sections: [TrainingReportSection] = [summarySection(selection: selection, workouts: selectedWorkouts)]
        sections.append(workoutSection(workouts: selectedWorkouts))

        if selection.includeSportSpecificPerformance {
            sections.append(
                sportSection(
                    workouts: selectedWorkouts,
                    configuration: sportConfiguration
                )
            )
        }

        let selectedMobility = mobilitySessions
            .filter { $0.status == .completed && selection.dateRange.contains($0.startTime) }
            .sorted { lhs, rhs in
                if lhs.startTime != rhs.startTime { return lhs.startTime < rhs.startTime }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        if selection.includeMobility {
            sections.append(
                mobilitySection(
                    sessions: selectedMobility,
                    includeNotes: selection.includeNotesAndEvidence,
                    hasSelectedWorkouts: !selectedWorkouts.isEmpty
                )
            )
        }

        if selection.includeProgressionReceipts {
            let receipts = progressionReceipts
                .filter { selectedWorkoutIDs.contains($0.workoutID) }
                .sorted { lhs, rhs in
                    if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                    return lhs.id.uuidString < rhs.id.uuidString
                }
            sections.append(progressionSection(receipts: receipts, hasSelectedWorkouts: !selectedWorkouts.isEmpty))
        }

        if selection.includeNotesAndEvidence {
            sections.append(notesSection(workouts: selectedWorkouts, sessions: selectedMobility))
        }

        let categories = sensitiveCategories(
            selection: selection,
            workouts: selectedWorkouts,
            mobilitySessions: selectedMobility,
            progressionReceipts: progressionReceipts.filter { selectedWorkoutIDs.contains($0.workoutID) }
        )
        let preview = TrainingReportArtifactPreview(
            includedSensitiveCategories: categories,
            selectedWorkoutCount: selectedWorkouts.count,
            selectedPlanCount: selection.selectedPlanIDs.count,
            sectionCount: sections.count,
            rowCount: sections.reduce(0) { $0 + $1.rows.count },
            requiresExplicitShareConfirmation: true,
            shareConfirmation: .notConfirmed
        )
        return TrainingReportArtifact(selection: selection, sections: sections, preview: preview)
    }

    private static func summarySection(
        selection: TrainingReportSelection,
        workouts: [Workout]
    ) -> TrainingReportSection {
        let workoutAvailability: TrainingReportDataAvailability = workouts.isEmpty ? .zero : .recorded
        let planIDs = Set(workouts.compactMap(\.sourcePlanID))
        return TrainingReportSection(
            kind: .summary,
            title: "Report summary",
            rows: [
                TrainingReportSummaryRow(
                    id: "summary.date-range",
                    title: "Date range",
                    value: "\(iso(selection.dateRange.start)) → \(iso(selection.dateRange.end))",
                    availability: .recorded,
                    source: nil
                ),
                TrainingReportSummaryRow(
                    id: "summary.completed-workouts",
                    title: "Completed workouts",
                    value: workouts.isEmpty ? nil : String(workouts.count),
                    availability: workoutAvailability,
                    source: nil
                ),
                TrainingReportSummaryRow(
                    id: "summary.selected-plans",
                    title: "Selected plans represented",
                    value: planIDs.isEmpty ? nil : String(planIDs.count),
                    availability: planIDs.isEmpty ? .zero : .recorded,
                    source: nil
                )
            ]
        )
    }

    private static func workoutSection(workouts: [Workout]) -> TrainingReportSection {
        let rows = workouts.map { workout in
            let completedSets = workout.orderedExercises
                .flatMap(\.orderedSets)
                .filter(\.done)
                .count
            return TrainingReportSummaryRow(
                id: "workout.\(workout.id.uuidString)",
                title: workout.name ?? "Workout \(workout.id.uuidString)",
                value: "\(iso(workout.startTime)) · \(workout.orderedExercises.count) exercises · \(completedSets) completed sets",
                availability: .recorded,
                source: TrainingReportSourceReference(workoutID: workout.id, planID: workout.sourcePlanID)
            )
        }
        return TrainingReportSection(
            kind: .workouts,
            title: "Completed workouts",
            rows: rows.isEmpty ? [unavailableRow(id: "workouts.unavailable", title: "Completed workout evidence")] : rows
        )
    }

    private static func sportSection(
        workouts: [Workout],
        configuration: WeightliftingAnalyticsConfiguration
    ) -> TrainingReportSection {
        let projection = WeightliftingAnalyticsProjection.project(workouts: workouts, configuration: configuration)
        var rows: [TrainingReportSummaryRow] = []
        for lift in projection.bestCompleteSuccessfulLiftsByUnit {
            rows.append(
                TrainingReportSummaryRow(
                    id: "sport.best.\(lift.weightType.rawValue)",
                    title: "Best complete successful lift (\(lift.weightType.rawValue))",
                    value: "\(lift.weight)",
                    availability: .recorded,
                    source: TrainingReportSourceReference(workoutID: lift.workoutID)
                )
            )
        }
        if let clean = projection.cleanSuccess {
            rows.append(rateRow(id: "sport.clean", title: "Clean success", attempts: clean.attempts, successes: clean.successes))
        }
        if let jerk = projection.jerkAfterCleanSuccess {
            rows.append(rateRow(id: "sport.jerk-after-clean", title: "Jerk after clean success", attempts: jerk.attempts, successes: jerk.successes))
        }
        for distribution in projection.componentFailureDistribution {
            rows.append(
                TrainingReportSummaryRow(
                    id: "sport.failures.\(distribution.role.rawValue)",
                    title: "\(distribution.role.rawValue) component outcomes",
                    value: "made \(distribution.completed), partial \(distribution.partial), missed \(distribution.missed), skipped \(distribution.skipped)",
                    availability: .recorded,
                    source: nil
                )
            )
        }
        for point in projection.qualityTrend {
            rows.append(
                TrainingReportSummaryRow(
                    id: "sport.quality.\(point.workoutID.uuidString)",
                    title: "Quality on \(iso(point.date))",
                    value: "excellent \(point.excellent), acceptable \(point.acceptable), technically poor \(point.technicallyPoor), missed \(point.missed)",
                    availability: .recorded,
                    source: TrainingReportSourceReference(workoutID: point.workoutID)
                )
            )
        }
        return TrainingReportSection(
            kind: .sportSpecificPerformance,
            title: "Sport-specific performance",
            rows: rows.isEmpty
                ? [workouts.isEmpty
                    ? unavailableRow(id: "sport.unavailable", title: "Sport-specific performance")
                    : missingRow(id: "sport.missing", title: "Sport-specific performance")]
                : rows
        )
    }

    private static func mobilitySection(
        sessions: [MobilitySession],
        includeNotes: Bool,
        hasSelectedWorkouts: Bool
    ) -> TrainingReportSection {
        var rows: [TrainingReportSummaryRow] = []
        if !sessions.isEmpty {
            rows.append(
                TrainingReportSummaryRow(
                    id: "mobility.count",
                    title: "Completed mobility sessions",
                    value: String(sessions.count),
                    availability: .recorded,
                    source: nil
                )
            )
        }
        for session in sessions {
            let results = session.orderedEntries.flatMap(\.orderedResults)
            let completedResults = results.filter { $0.status == .completed }.count
            rows.append(
                TrainingReportSummaryRow(
                    id: "mobility.\(session.id.uuidString)",
                    title: session.sourceRoutineName ?? session.nameSnapshot,
                    value: "\(iso(session.startTime)) · \(completedResults) completed results",
                    availability: .recorded,
                    source: TrainingReportSourceReference(workoutID: session.workoutID, mobilitySessionID: session.id)
                )
            )
            if includeNotes {
                for entry in session.orderedEntries where !(entry.notesSnapshot?.isEmpty ?? true) {
                    rows.append(
                        TrainingReportSummaryRow(
                            id: "mobility.note.\(entry.id.uuidString)",
                            title: "Mobility note: \(entry.definitionNameSnapshot)",
                            value: entry.notesSnapshot,
                            availability: .recorded,
                            source: TrainingReportSourceReference(mobilitySessionID: session.id)
                        )
                    )
                }
            }
        }
        return TrainingReportSection(
            kind: .mobility,
            title: "Mobility",
            rows: rows.isEmpty
                ? [hasSelectedWorkouts
                    ? missingRow(id: "mobility.missing", title: "Mobility evidence")
                    : unavailableRow(id: "mobility.unavailable", title: "Mobility evidence")]
                : rows
        )
    }

    private static func progressionSection(
        receipts: [PlanProgressionRecommendationRecord],
        hasSelectedWorkouts: Bool
    ) -> TrainingReportSection {
        let projections = ProgressionReceiptLedgerProjection.project(records: receipts)
        let rows: [TrainingReportSummaryRow] = projections.map { entry -> TrainingReportSummaryRow in
            let proposalText: String
            if let load = entry.proposal.load {
                proposalText = String(load)
            } else {
                proposalText = "structural"
            }
            return TrainingReportSummaryRow(
                id: "receipt.\(entry.id.uuidString)",
                title: "Progression receipt \(entry.id.uuidString)",
                value: "\(decisionText(entry.decision)) · proposal \(proposalText) · evidence \(evidenceText(entry.evidence.performanceAvailability))",
                availability: .recorded,
                source: TrainingReportSourceReference(workoutID: entry.workoutID, planID: nil, receiptID: entry.id)
            )
        }
        return TrainingReportSection(
            kind: .progressionReceipts,
            title: "Progression receipts",
            rows: rows.isEmpty
                ? [hasSelectedWorkouts
                    ? missingRow(id: "receipts.missing", title: "Progression receipt evidence")
                    : unavailableRow(id: "receipts.unavailable", title: "Progression receipt evidence")]
                : rows
        )
    }

    private static func notesSection(
        workouts: [Workout],
        sessions: [MobilitySession]
    ) -> TrainingReportSection {
        var rows: [TrainingReportSummaryRow] = []
        for workout in workouts {
            if let notes = workout.notes, !notes.isEmpty {
                rows.append(
                    TrainingReportSummaryRow(
                        id: "note.workout.\(workout.id.uuidString)",
                        title: "Workout note: \(workout.name ?? workout.id.uuidString)",
                        value: notes,
                        availability: .recorded,
                        source: TrainingReportSourceReference(workoutID: workout.id, planID: workout.sourcePlanID)
                    )
                )
            }
            for entry in workout.orderedExercises {
                if let comment = entry.comment, !comment.isEmpty {
                    rows.append(
                        TrainingReportSummaryRow(
                            id: "note.entry.\(entry.id.uuidString)",
                            title: "Exercise note: \(entry.displayName)",
                            value: comment,
                            availability: .recorded,
                            source: TrainingReportSourceReference(workoutID: workout.id, planID: workout.sourcePlanID)
                        )
                    )
                }
                for set in entry.orderedSets {
                    for note in [set.userOverrideReason, set.prescriptionNotes].compactMap({ $0 }).filter({ !$0.isEmpty }) {
                        rows.append(
                            TrainingReportSummaryRow(
                                id: "note.set.\(set.id.uuidString).\(rows.count)",
                                title: "Set evidence note: \(entry.displayName)",
                                value: note,
                                availability: .recorded,
                                source: TrainingReportSourceReference(workoutID: workout.id, planID: workout.sourcePlanID)
                            )
                        )
                    }
                }
            }
        }
        for session in sessions {
            for entry in session.orderedEntries where !(entry.notesSnapshot?.isEmpty ?? true) {
                rows.append(
                    TrainingReportSummaryRow(
                        id: "note.mobility.\(entry.id.uuidString)",
                        title: "Mobility note: \(entry.definitionNameSnapshot)",
                        value: entry.notesSnapshot,
                        availability: .recorded,
                        source: TrainingReportSourceReference(mobilitySessionID: session.id)
                    )
                )
            }
        }
        return TrainingReportSection(
            kind: .notesAndEvidence,
            title: "Notes and evidence",
            rows: rows.isEmpty
                ? [workouts.isEmpty && sessions.isEmpty
                    ? unavailableRow(id: "notes.unavailable", title: "Notes and evidence")
                    : missingRow(id: "notes.missing", title: "Notes and evidence")]
                : rows
        )
    }

    private static func sensitiveCategories(
        selection: TrainingReportSelection,
        workouts: [Workout],
        mobilitySessions: [MobilitySession],
        progressionReceipts: [PlanProgressionRecommendationRecord]
    ) -> [TrainingReportSensitiveCategory] {
        var categories: Set<TrainingReportSensitiveCategory> = []
        if !workouts.isEmpty {
            categories.insert(.workoutPerformance)
            categories.insert(.planIdentity)
        }
        if !selection.selectedPlanIDs.isEmpty { categories.insert(.planIdentity) }
        if selection.includeSportSpecificPerformance { categories.insert(.sportSpecificPerformance) }
        if selection.includeMobility && !mobilitySessions.isEmpty { categories.insert(.mobility) }
        if selection.includeProgressionReceipts && !progressionReceipts.isEmpty { categories.insert(.progressionReceipts) }
        if selection.includeNotesAndEvidence { categories.insert(.notesAndEvidence) }
        return categories.sorted { $0.rawValue < $1.rawValue }
    }

    private static func rateRow(
        id: String,
        title: String,
        attempts: Int,
        successes: Int
    ) -> TrainingReportSummaryRow {
        TrainingReportSummaryRow(
            id: id,
            title: title,
            value: "\(successes)/\(attempts) successful",
            availability: attempts == 0 ? .unavailable : .recorded,
            source: nil
        )
    }

    private static func unavailableRow(id: String, title: String) -> TrainingReportSummaryRow {
        TrainingReportSummaryRow(id: id, title: title, value: nil, availability: .unavailable, source: nil)
    }

    private static func missingRow(id: String, title: String) -> TrainingReportSummaryRow {
        TrainingReportSummaryRow(id: id, title: title, value: nil, availability: .missing, source: nil)
    }

    private static func decisionText(_ decision: ProgressionReceiptLedgerProjection.DecisionState) -> String {
        switch decision {
        case .pending: "pending"
        case .accepted: "accepted"
        case .acceptedWithModifiedValue: "accepted-with-modified-value"
        case .declined: "declined"
        case .outcomeNotRecorded: "outcome-not-recorded"
        }
    }

    private static func evidenceText(_ availability: ProgressionReceiptLedgerProjection.EvidenceAvailability) -> String {
        switch availability {
        case .decoded: "recorded"
        case .absent: "not-recorded"
        case .unreadable: "unreadable"
        }
    }

    private static func workoutOrder(lhs: Workout, rhs: Workout) -> Bool {
        if lhs.startTime != rhs.startTime { return lhs.startTime < rhs.startTime }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}

#endif
