import Foundation

/// One question. The identity is the raw value, and it is persisted in the
/// draft, so cases must not be renamed casually — a renamed step reads as a
/// removed one to a draft written by the previous build.
enum OnboardingStep: String, CaseIterable, Hashable, Sendable {
    case discipline
    case goal
    case experience
    /// Plan path: how many days a week. Rotation path asks `cadence` instead.
    case frequency
    /// Only when the lifter named a fixed number of days *and* said their week
    /// is regular. Someone whose schedule moves is never asked to pin weekdays.
    case weekdays
    case cadence
    case sessionDuration
    case location
    case equipment
    case specializedEquipment
    case units
    case focusAreas
    case competition

    /// The question itself, and the one sentence that explains why it is being
    /// asked. Every screen answers "why do you need this?" without the lifter
    /// having to tap anything.
    var question: String {
        switch self {
        case .discipline: String(localized: "What do you mainly train?")
        case .goal: String(localized: "What matters most right now?")
        case .experience: String(localized: "How experienced are you with structured training?")
        case .frequency: String(localized: "How many days can you usually train?")
        case .weekdays: String(localized: "Which days normally work?")
        case .cadence: String(localized: "How often do you normally train?")
        case .sessionDuration: String(localized: "How long should most workouts take?")
        case .location: String(localized: "Where do you usually train?")
        case .equipment: String(localized: "What equipment can you normally use?")
        case .specializedEquipment: String(localized: "Anything specialised?")
        case .units: String(localized: "Which units do you use?")
        case .focusAreas: String(localized: "Would you like to emphasise anything?")
        case .competition: String(localized: "Tell us about the competition")
        }
    }

    var explanation: String? {
        switch self {
        case .discipline:
            String(localized: "This organises plans, exercises and progress around the way you train.")
        case .goal:
            String(localized: "Plans are ranked against this. It changes what we suggest, never what you have already done.")
        case .experience:
            String(localized: "This ranks plans by how much they assume. Nothing is hidden from you.")
        case .frequency:
            String(localized: "Used to find plans that fit your week, not to hold you to a number.")
        case .weekdays:
            String(localized: "Sessions are scheduled on these days. You can move any of them later.")
        case .cadence:
            String(localized: "A rotation hands you the next workout whenever you train, so this is only used for ranking.")
        case .sessionDuration:
            String(localized: "A preference, not a promise. Some sessions in a plan run longer than others.")
        case .location:
            String(localized: "We’ll use this to pre-fill your equipment on the next screen.")
        case .equipment:
            String(localized: "Plans that need something you don’t have will say so rather than disappear.")
        case .specializedEquipment:
            String(localized: "Only asked because of the training you selected.")
        case .units:
            String(localized: "This changes how weights are displayed. Nothing you have logged is converted or rewritten.")
        case .focusAreas:
            String(localized: "Used to rank plans and suggest accessories. It never adds volume to a plan on its own.")
        case .competition:
            String(localized: "Used to rank competition plans and to show the right standards.")
        }
    }

    /// Whether the step offers a Skip control.
    ///
    /// Nearly everything is skippable: a skipped question stores `nil` and
    /// simply stops contributing to ranking, which is a better outcome than a
    /// guess the lifter did not make. The two that are not skippable are the
    /// ones where a wrong silent default is actively harmful — units, which
    /// changes every number on screen, and equipment, whose "I'm not sure"
    /// option is itself the skip.
    var isSkippable: Bool {
        switch self {
        case .units, .equipment: false
        default: true
        }
    }

    /// Whether choosing an option should carry the lifter forward on its own.
    ///
    /// True only for single-answer questions, where the tap *is* the decision
    /// and a Continue button is a second tap that confirms nothing. Multi-select
    /// and grouped screens always need an explicit commit.
    ///
    /// `units` is the exception among single-answer questions: it opens with
    /// the locale's system already selected, so auto-advancing would carry a
    /// suggestion the lifter never actually made. It gets a Continue button,
    /// which is what turns a preselection into an answer.
    var advancesOnSelection: Bool {
        switch self {
        case .discipline, .goal, .experience, .frequency, .cadence, .sessionDuration, .location:
            true
        case .units, .weekdays, .equipment, .specializedEquipment, .focusAreas, .competition:
            false
        }
    }

    /// The label on the committing action for steps that have one.
    var continueTitle: String {
        switch self {
        case .equipment: String(localized: "Confirm equipment")
        default: String(localized: "Continue")
        }
    }
}

extension OnboardingStep {
    /// The steps this draft actually leads to, in order.
    ///
    /// Recomputed from the draft every time rather than cached, so changing an
    /// earlier answer immediately adds or removes the questions that depend on
    /// it — and so the progress indicator can never promise a step the lifter
    /// will not be shown.
    static func steps(for draft: OnboardingDraft) -> [OnboardingStep] {
        guard let path = draft.selectedPath, path.asksProfileQuestions else {
            // Free Workout gets at most the one question whose wrong default is
            // visible on every screen afterwards.
            return draft.unitSystem == nil && !UnitSystemDefault.hasStoredPreference ? [.units] : []
        }

        var steps: [OnboardingStep] = [.discipline, .goal, .experience]

        switch path {
        case .plan:
            steps.append(.frequency)
            if draft.preferredDaysPerWeek != nil, draft.scheduleFlexibility != .variable {
                steps.append(.weekdays)
            }
        case .rotation:
            steps.append(.cadence)
        case .freeWorkout:
            break
        }

        steps.append(.sessionDuration)
        steps.append(.location)
        steps.append(.equipment)

        if draft.discipline?.specializedEquipmentGroup != nil {
            steps.append(.specializedEquipment)
        }

        steps.append(.units)

        if draft.goal?.asksMuscleEmphasis == true {
            steps.append(.focusAreas)
        }
        if draft.goal == .prepareForCompetition {
            steps.append(.competition)
        }

        return steps
    }
}

/// Where the unit system's starting value comes from before the lifter has said
/// anything. Locale is a suggestion worth making and never a decision worth
/// making silently, so this is only ever used to preselect a control.
enum UnitSystemDefault {
    static var hasStoredPreference: Bool {
        UserDefaults.standard.object(forKey: DefaultsKey.useMetric) != nil
    }

    static var suggested: UnitSystem {
        Locale.current.measurementSystem == .metric ? .metric : .imperial
    }
}
