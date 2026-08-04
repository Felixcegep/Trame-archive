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
    /// Whether the lifter wants a mobility plan too, asked once, in plain
    /// language. Independent of `discipline`/`goal` — this never implies the
    /// other, and neither implies this. Only ever asked when the
    /// `mobilityProgram` feature flag is on; see `steps(for:mobilityEnabled:)`.
    case mobilityGoal
    /// Only asked once `mobilityGoal` has an answer — someone who skipped
    /// past mobility entirely is never asked two more questions about it.
    case mobilityExperience
    case mobilityFrequency

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
        case .mobilityGoal: String(localized: "Would a mobility plan help too?")
        case .mobilityExperience: String(localized: "How experienced are you with mobility work?")
        case .mobilityFrequency: String(localized: "How often would you like to do mobility work?")
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
        case .mobilityGoal:
            String(localized: "Mobility plans are recommended separately from your training plan. Skip this if you’d rather not.")
        case .mobilityExperience:
            String(localized: "Ranks mobility plans by how much they assume. Nothing is hidden from you.")
        case .mobilityFrequency:
            String(localized: "Used to find a mobility plan that fits your week, not to hold you to a number.")
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
        case .discipline, .goal, .experience, .frequency, .cadence, .sessionDuration, .location,
             .mobilityGoal, .mobilityExperience, .mobilityFrequency:
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

/// Identity for `sheet(item:)`. The raw value already is the identity — it is
/// what the draft persists — so this states it rather than inventing a second
/// one that could disagree.
extension OnboardingStep: Identifiable {
    var id: String { rawValue }
}

extension OnboardingStep {
    /// The steps this draft actually leads to, in order.
    ///
    /// Recomputed from the draft every time rather than cached, so changing an
    /// earlier answer immediately adds or removes the questions that depend on
    /// it — and so the progress indicator can never promise a step the lifter
    /// will not be shown.
    ///
    /// - Parameter mobilityEnabled: Whether the `mobilityProgram` feature flag
    ///   is on. Resolved once by the caller rather than read here, matching
    ///   `FeatureFlags`' own "resolved once at composition time" rule, and
    ///   keeping this function a pure fold over its arguments — the property
    ///   every existing test in this file relies on. When `false`, mobility
    ///   questions never appear: a build where mobility plans are not
    ///   reachable must ask nothing about them.
    static func steps(for draft: OnboardingDraft, mobilityEnabled: Bool) -> [OnboardingStep] {
        guard let path = draft.selectedPath, path.asksProfileQuestions else {
            // Free Workout gets at most the one question whose wrong default is
            // visible on every screen afterwards. It never reaches the results
            // screen, so this is the only place its units answer can be taken.
            return draft.unitSystem == nil && !UnitSystemDefault.hasStoredPreference ? [.units] : []
        }

        // The three questions that decide which plans are even in the running,
        // and nothing else.
        //
        // This list used to run to fifteen questions, and the cost was paid in
        // the wrong order: a lifter configured an operating system before
        // seeing a single plan, answering "how long should most workouts take?"
        // with no idea whether the app had anything worth scheduling. Everything
        // that merely *refines* an ordering now happens on the results screen,
        // against a list the lifter can watch move — see `refinements(for:)`.
        //
        // These three carry the ranking's three heaviest weights, and only these
        // three can change which plans are plausible rather than which order
        // plausible ones appear in.
        var steps: [OnboardingStep] = [.discipline, .goal]

        switch path {
        case .plan:
            steps.append(.frequency)
        case .rotation:
            steps.append(.cadence)
        case .freeWorkout:
            break
        }

        // `mobilityEnabled` no longer adds questions here. Mobility is a
        // separate plan track, and three questions about it were being charged
        // to every lifter who came for a training plan; it now has its own
        // entry point on the results screen, taken only by someone who says
        // they want it. The parameter stays because the flag still gates
        // whether mobility is offered at all, and because a signature this
        // widely referenced should not churn for a behaviour change.
        _ = mobilityEnabled

        return steps
    }

    /// The questions that no longer gate the results, offered afterwards as
    /// refinements against a visible list.
    ///
    /// Each of these adjusts an ordering rather than deciding what is plausible,
    /// which is exactly the kind of question that should be asked with the
    /// answer's consequences on screen. Asked here, "45 to 60 minutes" is an
    /// abstraction; asked on the results screen, it visibly moves a plan up or
    /// down and can be undone in one tap.
    ///
    /// `location` is deliberately absent: it never reaches the ranking, and its
    /// only job — pre-ticking equipment — is done inside the equipment sheet
    /// where the ticks it produces are visible. `weekdays` and
    /// `specializedEquipment` are absent for the same reason from the other
    /// direction: neither reaches the ranking at all, so both live in the
    /// training profile, where they can be set once the lifter has a plan that
    /// gives them meaning.
    static func refinements(for draft: OnboardingDraft) -> [OnboardingStep] {
        var refinements: [OnboardingStep] = [.experience, .sessionDuration, .equipment]

        if draft.goal?.asksMuscleEmphasis == true {
            refinements.append(.focusAreas)
        }
        if draft.goal == .prepareForCompetition {
            refinements.append(.competition)
        }

        return refinements
    }

    /// The chip label. Shorter than `question`, which is a sentence and does not
    /// fit a row of chips.
    var refinementTitle: String {
        switch self {
        case .experience: String(localized: "Experience")
        case .sessionDuration: String(localized: "Session length")
        case .equipment: String(localized: "Equipment")
        case .focusAreas: String(localized: "Emphasis")
        case .competition: String(localized: "Competition")
        default: question
        }
    }

    /// What the chip reads underneath its label: the answer as it stands, or
    /// nothing when the question has not been answered.
    ///
    /// A chip that shows its current value is the difference between a filter
    /// bar and a row of buttons that might do anything. It also means the
    /// lifter can audit every answer the ranking used without opening a single
    /// sheet.
    func refinementSummary(for draft: OnboardingDraft) -> String? {
        switch self {
        case .experience:
            draft.experience?.title
        case .sessionDuration:
            draft.sessionDuration?.summaryTitle
        case .equipment:
            draft.equipmentIDs.isEmpty ? nil : CountPhrase.items(draft.equipmentIDs.count)
        case .focusAreas:
            draft.focusAreas.isEmpty
                ? nil
                : draft.focusAreas.map(\.title).formatted(.list(type: .and))
        case .competition:
            draft.competition?.discipline?.title
        default:
            nil
        }
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
