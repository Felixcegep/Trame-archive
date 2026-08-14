import Foundation

#if !GYMTRACKER_EXTENSION

/// The two competition lifts are named explicitly so an opener can never be
/// inferred from a generic strength set or a component-only result.
nonisolated enum CompetitionLift: String, Codable, CaseIterable, Hashable, Sendable {
    case snatch
    case cleanAndJerk
}

/// Read-only performed evidence supplied by History. This is an adapter value,
/// not a new persisted result truth; the source workout/set IDs keep the
/// proposal auditable back to the existing performed snapshot.
struct CompetitionLiftEvidence: Equatable, Hashable {
    let lift: CompetitionLift
    let date: Date
    let sourceWorkoutID: UUID
    let sourceSetID: UUID
    let loadKg: Double?
    let outcome: OlympicAttemptOutcome
    let liftQuality: LiftQuality?

    init(
        lift: CompetitionLift,
        date: Date,
        sourceWorkoutID: UUID,
        sourceSetID: UUID,
        loadKg: Double?,
        outcome: OlympicAttemptOutcome,
        liftQuality: LiftQuality? = nil
    ) {
        self.lift = lift
        self.date = date
        self.sourceWorkoutID = sourceWorkoutID
        self.sourceSetID = sourceSetID
        self.loadKg = loadKg
        self.outcome = outcome
        self.liftQuality = liftQuality
    }
}

enum CompetitionPreparationInsufficiencyReason: Equatable, Hashable {
    case eventDateInPast
    case planStartDateMissing
    case eventDateBeforePlanStart
    case eventDateOutsideProgramWindow
    case programDisciplineMissing
    case programIsNotOlympicWeightlifting
    case testWeekNotAuthored
    case eventDateNotInAuthoredTestWeek
    case noPriorWeekForTaper
    case noRecentSuccessfulEvidence(CompetitionLift)
    case openerLoadMissing(CompetitionLift)
    case laterAttemptsRequireReview(CompetitionLift)
}

enum CompetitionOpenerEvidencePolicy: String, Codable, Hashable {
    /// The opener is copied from the latest valid successful lift. No
    /// percentage, rounding, or unobserved load is invented by this policy.
    case latestSuccessfulLoad
}

struct CompetitionWeekWindow: Equatable, Hashable {
    let weekIndex: Int
    let name: String?
    let startDate: Date
    let endDate: Date
}

struct CompetitionOpenerProposal: Equatable, Hashable {
    let lift: CompetitionLift
    let loadKg: Double
    let evidence: CompetitionLiftEvidence
    let policy: CompetitionOpenerEvidencePolicy
}

struct CompetitionAttemptProposal: Equatable, Hashable {
    let lift: CompetitionLift
    let attemptNumber: Int
    let loadKg: Double?
    let evidence: CompetitionLiftEvidence?
    let reasons: [CompetitionPreparationInsufficiencyReason]
}

struct CompetitionPreparationRequest: Equatable {
    let eventDate: Date
    let asOfDate: Date
    let planStartDate: Date?
    let program: ProgramDefinitionPayload
    let performedEvidence: [CompetitionLiftEvidence]

    init(
        eventDate: Date,
        asOfDate: Date,
        planStartDate: Date?,
        program: ProgramDefinitionPayload,
        performedEvidence: [CompetitionLiftEvidence]
    ) {
        self.eventDate = eventDate
        self.asOfDate = asOfDate
        self.planStartDate = planStartDate
        self.program = program
        self.performedEvidence = performedEvidence
    }
}

/// A deterministic review artifact. It proposes no SwiftData mutation and
/// leaves attempt 2/3 loads for an explicit user decision after attempt 1.
struct CompetitionPreparationProposal: Equatable {
    let eventDate: Date
    let testWeek: CompetitionWeekWindow?
    let taperWeek: CompetitionWeekWindow?
    let openers: [CompetitionOpenerProposal]
    let attempts: [CompetitionAttemptProposal]
    let reasons: [CompetitionPreparationInsufficiencyReason]

    var requiresReview: Bool { !reasons.isEmpty || attempts.contains { !$0.reasons.isEmpty } }

    func opener(for lift: CompetitionLift) -> CompetitionOpenerProposal? {
        openers.first { $0.lift == lift }
    }

    func attempts(for lift: CompetitionLift) -> [CompetitionAttemptProposal] {
        attempts.filter { $0.lift == lift }.sorted { $0.attemptNumber < $1.attemptNumber }
    }
}

enum CompetitionPreparationRules {
    static let evidenceLookbackDays = 56
    private static let secondsPerDay: TimeInterval = 86_400
    private static let daysPerWeek = 7

    static func propose(
        _ request: CompetitionPreparationRequest
    ) -> CompetitionPreparationProposal {
        var reasons: [CompetitionPreparationInsufficiencyReason] = []
        func appendUnique(_ reason: CompetitionPreparationInsufficiencyReason) {
            if !reasons.contains(reason) { reasons.append(reason) }
        }

        if request.eventDate < request.asOfDate {
            appendUnique(.eventDateInPast)
        }

        let discipline = request.program.competitionDisciplineID
        if discipline == nil || discipline?.isEmpty == true {
            appendUnique(.programDisciplineMissing)
        } else if discipline != "olympicWeightlifting" {
            appendUnique(.programIsNotOlympicWeightlifting)
        }

        var testWeek: CompetitionWeekWindow?
        var taperWeek: CompetitionWeekWindow?
        if let planStartDate = request.planStartDate {
            if request.eventDate < planStartDate {
                appendUnique(.eventDateBeforePlanStart)
            }
            if request.eventDate > planStartDate.addingTimeInterval(Double(max(1, request.program.durationWeeks) * daysPerWeek) * secondsPerDay) {
                appendUnique(.eventDateOutsideProgramWindow)
            }

            if let authoredTest = authoredTestWeek(in: request.program) {
                testWeek = weekWindow(authoredTest, planStartDate: planStartDate)
                if let testWeek, !(testWeek.startDate...testWeek.endDate).contains(request.eventDate) {
                    appendUnique(.eventDateNotInAuthoredTestWeek)
                }
                if authoredTest.weekIndex > 0 {
                    taperWeek = weekWindow(
                        weekIndex: authoredTest.weekIndex - 1,
                        name: "Taper",
                        planStartDate: planStartDate
                    )
                } else {
                    appendUnique(.noPriorWeekForTaper)
                }
            } else {
                appendUnique(.testWeekNotAuthored)
            }
        } else {
            appendUnique(.planStartDateMissing)
        }

        var openers: [CompetitionOpenerProposal] = []
        var attempts: [CompetitionAttemptProposal] = []
        for lift in CompetitionLift.allCases {
            let evidence = latestSuccessfulEvidence(
                for: lift,
                before: request.eventDate,
                in: request.performedEvidence
            )
            if let evidence,
               let loadKg = evidence.loadKg,
               loadKg.isFinite,
               loadKg > 0 {
                let opener = CompetitionOpenerProposal(
                    lift: lift,
                    loadKg: loadKg,
                    evidence: evidence,
                    policy: .latestSuccessfulLoad
                )
                openers.append(opener)
                attempts.append(CompetitionAttemptProposal(
                    lift: lift,
                    attemptNumber: 1,
                    loadKg: loadKg,
                    evidence: evidence,
                    reasons: []
                ))
                for number in 2...3 {
                    let reason = CompetitionPreparationInsufficiencyReason.laterAttemptsRequireReview(lift)
                    attempts.append(CompetitionAttemptProposal(
                        lift: lift,
                        attemptNumber: number,
                        loadKg: nil,
                        evidence: evidence,
                        reasons: [reason]
                    ))
                    appendUnique(reason)
                }
            } else {
                let reason: CompetitionPreparationInsufficiencyReason =
                    evidence == nil ? .noRecentSuccessfulEvidence(lift) : .openerLoadMissing(lift)
                appendUnique(reason)
                for number in 1...3 {
                    var attemptReasons = [reason]
                    if number > 1 {
                        let laterReason = CompetitionPreparationInsufficiencyReason.laterAttemptsRequireReview(lift)
                        attemptReasons.append(laterReason)
                        appendUnique(laterReason)
                    }
                    attempts.append(CompetitionAttemptProposal(
                        lift: lift,
                        attemptNumber: number,
                        loadKg: nil,
                        evidence: evidence,
                        reasons: attemptReasons
                    ))
                }
            }
        }

        return CompetitionPreparationProposal(
            eventDate: request.eventDate,
            testWeek: testWeek,
            taperWeek: taperWeek,
            openers: openers,
            attempts: attempts,
            reasons: reasons
        )
    }

    private static func latestSuccessfulEvidence(
        for lift: CompetitionLift,
        before eventDate: Date,
        in evidence: [CompetitionLiftEvidence]
    ) -> CompetitionLiftEvidence? {
        let lowerBound = eventDate.addingTimeInterval(-Double(evidenceLookbackDays) * secondsPerDay)
        return evidence
            .filter {
                $0.lift == lift &&
                $0.date >= lowerBound &&
                $0.date <= eventDate &&
                $0.outcome == .made
            }
            .sorted {
                if $0.date != $1.date { return $0.date > $1.date }
                let lhsLoad = $0.loadKg.flatMap { $0.isFinite ? $0 : nil } ?? -.infinity
                let rhsLoad = $1.loadKg.flatMap { $0.isFinite ? $0 : nil } ?? -.infinity
                if lhsLoad != rhsLoad { return lhsLoad > rhsLoad }
                return $0.sourceSetID.uuidString < $1.sourceSetID.uuidString
            }
            .first
    }

    private static func authoredTestWeek(in program: ProgramDefinitionPayload) -> ProgramWeekDefinition? {
        program.blocks
            .flatMap(\.weeks)
            .sorted { $0.weekIndex < $1.weekIndex }
            .first { week in
                week.workouts.contains { workout in
                    workout.plannedExercises.contains { exercise in
                        let sets = exercise.plannedSets + exercise.waves.flatMap(\.plannedSets) + exercise.stages.flatMap(\.plannedSets)
                        return sets.contains { $0.role == .test }
                    }
                }
            }
    }

    private static func weekWindow(
        _ week: ProgramWeekDefinition,
        planStartDate: Date
    ) -> CompetitionWeekWindow {
        weekWindow(weekIndex: week.weekIndex, name: week.name, planStartDate: planStartDate)
    }

    private static func weekWindow(
        weekIndex: Int,
        name: String?,
        planStartDate: Date
    ) -> CompetitionWeekWindow {
        let start = planStartDate.addingTimeInterval(Double(max(0, weekIndex) * daysPerWeek) * secondsPerDay)
        return CompetitionWeekWindow(
            weekIndex: weekIndex,
            name: name,
            startDate: start,
            endDate: start.addingTimeInterval(Double(daysPerWeek) * secondsPerDay - 1)
        )
    }
}

#endif
