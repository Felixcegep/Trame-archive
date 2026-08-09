import Foundation

/// What the lifter said, reduced to the facts ranking actually uses.
///
/// A value type with no store access so the ranking can be argued with in
/// isolation: every recommendation the app shows must be reproducible from
/// these fields alone.
struct ProgramMatchCriteria: Equatable, Sendable {
    var discipline: TrainingDisciplinePreference?
    var goal: TrainingGoalPreference?
    var experience: ProfileExperienceLevel?
    var preferredDaysPerWeek: Int?
    var rotationCadence: RotationCadencePreference?
    var scheduleFlexibility: ScheduleFlexibility?
    var sessionDuration: SessionDurationPreference?
    var availableEquipment: Set<EquipmentType> = []
    var availableEquipmentCapabilityIDs: Set<String> = []
    var focusAreas: [FocusArea] = []
    var competitionDiscipline: CompetitionDiscipline?
    var competitionDate: Date?

    init(
        discipline: TrainingDisciplinePreference? = nil,
        goal: TrainingGoalPreference? = nil,
        experience: ProfileExperienceLevel? = nil,
        preferredDaysPerWeek: Int? = nil,
        rotationCadence: RotationCadencePreference? = nil,
        scheduleFlexibility: ScheduleFlexibility? = nil,
        sessionDuration: SessionDurationPreference? = nil,
        availableEquipment: Set<EquipmentType> = [],
        availableEquipmentCapabilityIDs: Set<String> = [],
        focusAreas: [FocusArea] = [],
        competitionDiscipline: CompetitionDiscipline? = nil,
        competitionDate: Date? = nil
    ) {
        self.discipline = discipline
        self.goal = goal
        self.experience = experience
        self.preferredDaysPerWeek = preferredDaysPerWeek
        self.rotationCadence = rotationCadence
        self.scheduleFlexibility = scheduleFlexibility
        self.sessionDuration = sessionDuration
        self.availableEquipment = availableEquipment
        self.availableEquipmentCapabilityIDs = availableEquipmentCapabilityIDs
        self.focusAreas = focusAreas
        self.competitionDiscipline = competitionDiscipline
        self.competitionDate = competitionDate
    }

    init(draft: OnboardingDraft) {
        self.init(
            discipline: draft.discipline,
            goal: draft.goal,
            experience: draft.experience,
            preferredDaysPerWeek: draft.preferredDaysPerWeek,
            rotationCadence: draft.rotationCadence,
            scheduleFlexibility: draft.scheduleFlexibility,
            sessionDuration: draft.sessionDuration,
            availableEquipment: draft.equipment,
            focusAreas: draft.focusAreas,
            competitionDiscipline: draft.competition?.discipline,
            competitionDate: draft.competition?.eventDate
        )
    }

    /// Nothing to rank against. Recommendations degrade to the catalogue's own
    /// order rather than pretending to be personalised.
    var isEmpty: Bool {
        discipline == nil
            && goal == nil
            && experience == nil
            && preferredDaysPerWeek == nil
            && rotationCadence == nil
            && sessionDuration == nil
            && availableEquipment.isEmpty
            && availableEquipmentCapabilityIDs.isEmpty
            && focusAreas.isEmpty
            && competitionDiscipline == nil
    }
}

/// One thing a program does that the lifter asked for. Shown verbatim on the
/// card: a positive factor that cannot be stated is a factor that should not
/// have moved the ranking.
struct ProgramMatchReason: Identifiable, Equatable, Sendable {
    var id: String { text }
    let text: String
}

/// Something worth knowing before starting. Never a reason to hide the program.
struct ProgramMatchWarning: Identifiable, Equatable, Sendable {
    var id: String { text }
    let text: String
}

/// A free-text, author-written condition the intake cannot verify — a known
/// one-rep max, a technique standard, prior training history. Disclosed
/// unconditionally (see the comment at the evaluation call site) but
/// deliberately not a `ProgramMatchWarning`: nothing here compares what the
/// lifter said against what the program declared, so a prerequisite must
/// never downgrade `compatibility` or count against a program in the
/// warnings-count tie-break. It is information, not a finding.
struct ProgramMatchPrerequisite: Identifiable, Equatable, Sendable {
    var id: String { text }
    let text: String
}

enum ProgramCompatibility: Equatable, Sendable {
    /// Everything the lifter asked for, and nothing missing.
    case recommended
    /// Startable, with something worth reading first.
    case worksWithChanges
    /// This build cannot execute the program at all.
    case unsupported
}

struct ProgramMatchResult: Identifiable, Equatable, Sendable {
    var id: UUID { programID }
    let programID: UUID
    let name: String
    let summary: String?
    let goal: PlanGoal
    let experienceLevel: PlanExperienceLevel
    let supportedDaysPerWeek: [Int]
    let durationWeeks: Int
    let compatibility: ProgramCompatibility
    let score: Double
    let reasons: [ProgramMatchReason]
    let warnings: [ProgramMatchWarning]
    let prerequisites: [ProgramMatchPrerequisite]
    let missingEquipment: [EquipmentType]

    /// Whether this build can execute the program at all. The one thing that
    /// legitimately outranks fit.
    var isRunnable: Bool { compatibility != .unsupported }

    /// The short badge the card wears, so a result stays self-describing once
    /// the section header it arrived under has scrolled away.
    var compatibilityTitle: String? {
        switch compatibility {
        case .recommended: nil
        case .worksWithChanges: String(localized: "Needs changes")
        case .unsupported: String(localized: "Not supported")
        }
    }
}

/// Ranks the catalogue against what the lifter said.
///
/// Pure and synchronous. There is no model to load and no network to wait on,
/// which is exactly why the recommendation screen shows no fake analysis step:
/// inventing a three-second "building your plan" animation over a computation
/// that takes microseconds is a lie told to make the result feel earned.
enum ProgramMatchService {
    /// What each factor is worth. Ordered and weighted here rather than
    /// scattered through the comparison so the ranking can be reviewed as a
    /// single statement of priorities.
    private enum Weight {
        static let discipline = 30.0
        static let goal = 26.0
        static let equipment = 20.0
        static let frequency = 16.0
        static let experience = 12.0
        static let sessionDuration = 8.0
        static let focusArea = 5.0
        static let scheduleStyle = 5.0
        static let competition = 10.0
    }

    static func rank(
        programs: [ProgramMatchCandidate],
        criteria: ProgramMatchCriteria
    ) -> [ProgramMatchResult] {
        programs
            .map { evaluate($0, criteria: criteria) }
            .sorted { lhs, rhs in
                // Runnability first, then fit. Only a program this build cannot
                // execute is allowed to sort below a better-matching one.
                //
                // Compatibility used to be the primary key, which produced the
                // worst possible answer for the person the flow exists to
                // serve: every powerlifting plan in the catalogue is authored
                // `advanced`, so an intermediate lifter preparing for a meet
                // earned one soft note — "assumes advanced experience" — on all
                // of them, and a general-strength cycle scoring thirty points
                // lower took the recommendation. A warning is something to
                // read before starting, not a reason to lose to a worse match.
                if lhs.isRunnable != rhs.isRunnable { return lhs.isRunnable }
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                // Among equal fits, prefer the one with less to explain.
                if lhs.warnings.count != rhs.warnings.count {
                    return lhs.warnings.count < rhs.warnings.count
                }
                return lhs.name < rhs.name
            }
    }

    static func evaluate(
        _ candidate: ProgramMatchCandidate,
        criteria: ProgramMatchCriteria
    ) -> ProgramMatchResult {
        var score = 0.0
        var reasons: [ProgramMatchReason] = []
        var warnings: [ProgramMatchWarning] = []

        // MARK: Hard incompatibility
        //
        // Only one thing genuinely blocks activation: a program that needs an
        // engine feature this build does not have cannot be executed, and
        // offering it would produce a plan that silently misprescribes.
        let missingCapabilities = EngineCapabilities.missing(from: candidate.requiredCapabilities)
        let isUnsupported = !missingCapabilities.isEmpty

        // MARK: Discipline
        if let discipline = criteria.discipline, discipline != .unspecified {
            if candidate.matchesDiscipline(discipline) {
                score += Weight.discipline
                reasons.append(.init(text: String(localized: "Built for \(discipline.title.lowercased())")))
            }
        }

        // MARK: Goal
        if let goal = criteria.goal {
            if goal.preferredPlanGoals.contains(candidate.goal) {
                score += Weight.goal
                reasons.append(.init(text: String(localized: "Matches your goal: \(goal.title.lowercased())")))
            } else if goal.acceptablePlanGoals.contains(candidate.goal) {
                score += Weight.goal / 2
            }
        }

        // MARK: Equipment
        let equipmentRequirement = candidate.equipmentRequirement
        let missingEquipment = equipmentRequirement.allOf
            .filter { !criteria.availableEquipment.contains($0) }
            .sorted { $0.rawValue < $1.rawValue }
        let unsatisfiedAlternatives = equipmentRequirement.anyOf.filter { alternatives in
            alternatives.allSatisfy { !criteria.availableEquipment.contains($0) }
        }
        let missingEquipmentCapabilityIDs = equipmentRequirement.requiredCapabilityIDs
            .filter { !criteria.availableEquipmentCapabilityIDs.contains($0) }
            .sorted()

        // Equipment is the one question onboarding refuses to let the lifter
        // skip, so it cannot be the one factor a program wins by omission.
        // 24 of the 30 bundled programs declare `requiredEquipment: []`, and
        // an empty requirement set can never produce a `missingEquipment`
        // entry — so scoring on `missingEquipment.isEmpty` alone handed all
        // 24 of them the full weight for declaring nothing, with no reason
        // text either, since the reason line was already suppressed for an
        // empty requirement list. The 6 programs that honestly named their
        // equipment could then only tie or lose against plans that had never
        // been checked against the lifter's rack at all. A program earns
        // this weight only by declaring equipment the lifter actually has;
        // declaring nothing earns neither the points nor a warning, and the
        // program is scored on everything else instead.
        if !criteria.availableEquipment.isEmpty || !criteria.availableEquipmentCapabilityIDs.isEmpty {
            if equipmentRequirement.hasRequirements
                && missingEquipment.isEmpty
                && unsatisfiedAlternatives.isEmpty
                && missingEquipmentCapabilityIDs.isEmpty {
                score += Weight.equipment
                reasons.append(.init(text: String(localized: "Uses only equipment you selected")))
            } else if !missingEquipment.isEmpty || !unsatisfiedAlternatives.isEmpty || !missingEquipmentCapabilityIDs.isEmpty {
                var missingNames = missingEquipment.map(\.onboardingTitle)
                missingNames += unsatisfiedAlternatives.map {
                    $0.map(\.onboardingTitle).formatted(.list(type: .or))
                }
                missingNames += missingEquipmentCapabilityIDs
                    .map(SpecializedEquipmentCapability.title(for:))
                let names = missingNames.formatted(.list(type: .and))
                warnings.append(.init(text: String(localized: "Needs equipment you didn’t select: \(names)")))
            }
        }

        // MARK: Frequency
        if let desired = desiredDays(from: criteria) {
            if candidate.supportedDaysPerWeek.contains(where: desired.contains) {
                score += Weight.frequency
                reasons.append(.init(text: frequencyReason(candidate: candidate, desired: desired)))
            } else if let nearest = candidate.supportedDaysPerWeek.min(by: {
                abs($0 - desired.lowerBound) < abs($1 - desired.lowerBound)
            }) {
                warnings.append(.init(
                    text: String(localized: "Written for \(CountPhrase.days(nearest)) a week")
                ))
            }
        }

        // MARK: Experience
        //
        // A mismatch is a warning, never a filter. An advanced program stays
        // visible to a beginner with its demands stated, because "this is not
        // for you" is a judgement the app is not entitled to make silently.
        if let experience = criteria.experience, let level = experience.planExperienceLevel {
            if level == candidate.experienceLevel {
                score += Weight.experience
                reasons.append(.init(text: String(localized: "Written for your experience level")))
            } else if candidate.experienceLevel.ordinal > level.ordinal {
                warnings.append(.init(
                    text: String(localized: "Assumes \(candidate.experienceLevel.onboardingTitle.lowercased()) experience")
                ))
            }
        }

        // MARK: Session duration
        //
        // Absent duration metadata is not a mismatch. A program that has never
        // declared how long its sessions run simply earns no bonus — excluding
        // it would punish the catalogue for the schema being newer than it is.
        if let desiredMinutes = criteria.sessionDuration?.minutesRange,
           let programMinutes = candidate.estimatedSessionMinutes {
            if programMinutes.overlaps(desiredMinutes) {
                score += Weight.sessionDuration
                reasons.append(.init(text: String(localized: "Sessions fit the length you want")))
            } else {
                warnings.append(.init(
                    text: String(localized: "Sessions usually run \(programMinutes.lowerBound)–\(programMinutes.upperBound) minutes")
                ))
            }
        }

        // MARK: Focus areas
        if !criteria.focusAreas.isEmpty,
           candidate.focusAreaApplicability == .applicable,
           !candidate.focusAreaIDs.isEmpty {
            let overlap = criteria.focusAreas.filter { candidate.focusAreaIDs.contains($0.rawValue) }
            if !overlap.isEmpty {
                score += Weight.focusArea
                let names = overlap.map(\.title).formatted(.list(type: .and))
                reasons.append(.init(text: String(localized: "Emphasises \(names.lowercased())")))
            }
        }

        // MARK: Schedule style
        if let flexibility = criteria.scheduleFlexibility {
            let suitsFlexibleWeek = candidate.scheduleMode != .fixedWeekdays
            if (flexibility == .variable) == suitsFlexibleWeek {
                score += Weight.scheduleStyle
                if flexibility == .variable {
                    reasons.append(.init(text: String(localized: "Places sessions in order, not on fixed days")))
                }
            }
        }

        // MARK: Competition
        if let competitionDiscipline = criteria.competitionDiscipline,
           candidate.competitionDisciplineID == competitionDiscipline.rawValue {
            score += Weight.competition
            reasons.append(.init(text: String(localized: "Written as competition preparation")))

            if criteria.competitionDate == nil {
                warnings.append(.init(text: String(localized: "No event date entered yet")))
            } else if let date = criteria.competitionDate {
                let weeksAvailable = weeksBetween(.now, date)
                if weeksAvailable < candidate.durationWeeks {
                    warnings.append(.init(
                        text: String(localized: "Runs \(candidate.durationWeeks) weeks — longer than the time before your event")
                    ))
                }
            }
        }

        // MARK: Prerequisites
        //
        // Free text and unverifiable from the intake — there is no question
        // that asks whether a lifter already knows their one-rep maxes or has
        // the prescribed technique. Disclosing every prerequisite
        // unconditionally is the honest alternative to guessing: a program
        // that lists one is never handed out as a clean, caveat-free result
        // that hides what its author expects walking in.
        //
        // They are kept out of `warnings` on purpose. 28 of the 30 bundled
        // programs declare at least one prerequisite, and folding every one
        // of them into `warnings` used to mean 28 of 30 result cards forced
        // `compatibility` to `.worksWithChanges` and wore a red "Needs
        // changes" hazard chip for author-written conditions like "can
        // perform the five basic barbell lifts with an empty bar" — text
        // that is not a mismatch the app found, because nothing here compares
        // it against anything the lifter said. Only `warnings` — the app
        // comparing what the lifter answered against what the program
        // declared — may downgrade compatibility or cost a program the
        // warnings-count tie-break; a prerequisite is disclosed, never scored.
        let prerequisites = candidate.prerequisites.map { ProgramMatchPrerequisite(text: $0) }

        // MARK: Author warnings
        for warning in candidate.authorWarnings {
            warnings.append(.init(text: warning))
        }
        if candidate.isExperimental {
            warnings.append(.init(text: String(localized: "Marked experimental by its author")))
        }

        let compatibility: ProgramCompatibility = {
            if isUnsupported { return .unsupported }
            return warnings.isEmpty ? .recommended : .worksWithChanges
        }()

        if isUnsupported {
            warnings.insert(
                .init(text: String(localized: "This version of Trame can’t run this plan yet.")),
                at: 0
            )
        }

        return ProgramMatchResult(
            programID: candidate.id,
            name: candidate.name,
            summary: candidate.summary,
            goal: candidate.goal,
            experienceLevel: candidate.experienceLevel,
            supportedDaysPerWeek: candidate.supportedDaysPerWeek,
            durationWeeks: candidate.durationWeeks,
            compatibility: compatibility,
            score: score,
            reasons: reasons,
            warnings: warnings,
            prerequisites: prerequisites,
            missingEquipment: missingEquipment
        )
    }

    /// The weekly frequency to compare against, from whichever question the
    /// lifter's path actually asked.
    private static func desiredDays(from criteria: ProgramMatchCriteria) -> ClosedRange<Int>? {
        if let days = criteria.preferredDaysPerWeek { return days...days }
        return criteria.rotationCadence?.impliedDaysPerWeek
    }

    private static func frequencyReason(
        candidate: ProgramMatchCandidate,
        desired: ClosedRange<Int>
    ) -> String {
        guard let matched = candidate.supportedDaysPerWeek.first(where: desired.contains) else {
            return String(localized: "Fits your week")
        }
        return String(localized: "Supports \(CountPhrase.sessionsPerWeek(matched))")
    }

    private static func weeksBetween(_ start: Date, _ end: Date) -> Int {
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        return max(0, days / 7)
    }
}

extension PlanExperienceLevel {
    var ordinal: Int {
        switch self {
        case .beginner: 0
        case .intermediate: 1
        case .advanced: 2
        }
    }

    var onboardingTitle: String {
        switch self {
        case .beginner: String(localized: "Beginner")
        case .intermediate: String(localized: "Intermediate")
        case .advanced: String(localized: "Advanced")
        }
    }
}

extension PlanGoal {
    var onboardingTitle: String {
        switch self {
        case .generalStrength: String(localized: "General strength")
        case .hypertrophy: String(localized: "Hypertrophy")
        case .powerlifting: String(localized: "Powerlifting")
        case .generalFitness: String(localized: "General fitness")
        }
    }
}

extension TrainingGoalPreference {
    /// The program goals that are a direct answer to this preference.
    var preferredPlanGoals: [PlanGoal] {
        switch self {
        case .buildMuscle: [.hypertrophy]
        case .getStronger: [.generalStrength, .powerlifting]
        case .techniqueAndPower: [.powerlifting, .generalStrength]
        case .conditioning: [.generalFitness]
        case .prepareForCompetition: [.powerlifting]
        case .mobility: [.generalFitness]
        case .bodyComposition: [.hypertrophy, .generalFitness]
        case .returnToTraining: [.generalStrength, .generalFitness]
        case .maintain: [.generalFitness, .generalStrength]
        case .explore: [.generalStrength, .generalFitness, .hypertrophy, .powerlifting]
        }
    }

    /// Goals that are a reasonable second answer. Scored at half weight, so a
    /// hypertrophy block still surfaces for someone chasing strength without
    /// outranking the plan that was written for it.
    var acceptablePlanGoals: Set<PlanGoal> {
        switch self {
        case .buildMuscle: [.generalStrength, .generalFitness]
        case .getStronger: [.hypertrophy]
        case .techniqueAndPower: [.hypertrophy]
        case .conditioning: [.generalStrength]
        case .prepareForCompetition: [.generalStrength]
        case .mobility: [.generalStrength]
        case .bodyComposition: [.generalStrength]
        case .returnToTraining: [.hypertrophy]
        case .maintain: [.hypertrophy]
        case .explore: []
        }
    }
}

extension TrainingDisciplinePreference {
    /// The program goals that describe this discipline. Deliberately generous:
    /// the discipline vocabulary is richer than `PlanGoal`, and a discipline
    /// with no representation in the catalogue should contribute nothing rather
    /// than force a wrong match.
    var associatedPlanGoals: Set<PlanGoal> {
        switch self {
        case .generalStrength: [.generalStrength]
        case .bodybuilding: [.hypertrophy]
        case .powerlifting: [.powerlifting]
        case .olympicWeightlifting: [.powerlifting, .generalStrength]
        case .strongman: [.generalStrength, .powerlifting]
        case .hybridFitnessRacing: [.generalFitness]
        case .cardioEndurance: [.generalFitness]
        case .mobilityFlexibility: [.generalFitness]
        case .generalFitness: [.generalFitness]
        case .mixed, .unspecified: []
        }
    }
}
