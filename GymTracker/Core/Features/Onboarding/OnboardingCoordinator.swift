import Foundation
import Observation

/// Owns where the lifter is, what they have answered, and nothing else.
///
/// This exists because `RootView` already owns four presentations, six
/// navigation paths and the active-workout lifecycle; adding a branching
/// questionnaire's step state to it would have made the app's most
/// safety-critical view responsible for a progress bar. The root now decides
/// only whether onboarding is on screen and what to do with its outcome.
@MainActor
@Observable
final class OnboardingCoordinator {
    enum Phase: Equatable {
        /// The routing question. Not a numbered step: it decides which steps
        /// exist, so it cannot be one of them.
        case welcome
        case questions
        /// Ranked plans for the answers given.
        case recommendations
        /// A single confirmation that training is set up, after activation.
        case completed(OnboardingActivationSummary)
    }

    /// Which way the last navigation went, so the transition can carry the
    /// spatial direction the lifter's own tap implied.
    enum Direction {
        case forward
        case backward
    }

    private(set) var phase: Phase = .welcome
    private(set) var direction: Direction = .forward
    private(set) var draft: OnboardingDraft
    /// The step currently on screen, or `nil` while the flow is between phases.
    private(set) var currentStep: OnboardingStep?
    /// Raised when a commit is attempted with nothing chosen. Cleared by the
    /// next selection, so the message never outlives the problem.
    private(set) var validationMessage: String?
    /// Counts refusals rather than tracking the message, so a second attempt
    /// against the same unanswered question is felt as its own event. Keying
    /// feedback off the message text alone would go silent exactly when the
    /// lifter is pressing Continue a second time and needs telling most.
    private(set) var validationAttemptCount = 0

    private let store: OnboardingDraftStore
    /// Resolved once at init, matching `FeatureFlags`' own "resolved once at
    /// composition time" rule — a flag that could flip mid-flow would add or
    /// remove questions out from under a lifter answering them.
    private let isMobilityMatchingEnabled: Bool
    private var autoAdvanceTask: Task<Void, Never>?
    /// The last moment a navigation actually committed. A second tap arriving
    /// inside `Self.inputCooldown` is the same tap as far as the lifter is
    /// concerned, and skipping two steps from one intention is the failure this
    /// prevents.
    private var lastNavigationDate: Date = .distantPast
    private static let inputCooldown: TimeInterval = 0.22
    /// How long a chosen card is allowed to look chosen before the flow moves
    /// on. Long enough to register as a state change, short enough that it
    /// never reads as lag.
    static let autoAdvanceDelay: Duration = .milliseconds(260)

    /// `isMobilityMatchingEnabled` stays injectable, but it cannot default to
    /// `FeatureFlags.current` directly: a default argument expression is
    /// evaluated in a nonisolated context, and the flag store is main-actor
    /// isolated. Resolving `nil` inside this already-isolated initializer keeps
    /// both the live default and the explicit override available.
    init(
        store suppliedStore: OnboardingDraftStore? = nil,
        isMobilityMatchingEnabled: Bool? = nil
    ) {
        let store = suppliedStore ?? OnboardingDraftStore()
        self.store = store
        self.isMobilityMatchingEnabled = isMobilityMatchingEnabled
            ?? FeatureFlags.current.isEnabled(.mobilityProgram)
        self.draft = store.load() ?? OnboardingDraft()
        restore()
    }

    // MARK: Step model

    var steps: [OnboardingStep] {
        OnboardingStep.steps(for: draft, mobilityEnabled: isMobilityMatchingEnabled)
    }

    var currentStepIndex: Int? {
        guard let currentStep else { return nil }
        return steps.firstIndex(of: currentStep)
    }

    /// "Step 3 of 7", counted against the branch this lifter is actually on.
    /// A total that includes questions they will never see is not a progress
    /// indicator, it is a threat.
    var progressDescription: String? {
        guard let index = currentStepIndex else { return nil }
        return String(localized: "Step \(index + 1) of \(steps.count)")
    }

    var progressFraction: Double {
        guard let index = currentStepIndex, !steps.isEmpty else {
            switch phase {
            case .welcome: return 0
            case .questions: return 0
            case .recommendations, .completed: return 1
            }
        }
        return Double(index + 1) / Double(steps.count)
    }

    var canGoBack: Bool {
        switch phase {
        case .welcome: false
        case .questions: true
        case .recommendations: !steps.isEmpty
        case .completed: false
        }
    }

    // MARK: Restoration

    /// Puts the lifter back where they were, without replaying anything.
    ///
    /// A restored screen must not animate a selection it is merely remembering,
    /// must not fire the haptic that originally accompanied it, and must not
    /// auto-advance off the answer it just restored — all three would be the app
    /// narrating its own memory as if it were a fresh event.
    private func restore() {
        guard let path = draft.selectedPath else {
            phase = .welcome
            return
        }
        // Past the questions: resume on the results, not on the last question
        // that happens to be the final entry in the branch.
        if draft.hasReachedRecommendations {
            currentStep = nil
            phase = path.asksProfileQuestions ? .recommendations : .completed(.freeWorkout)
            return
        }
        let available = steps
        guard !available.isEmpty else {
            phase = path.asksProfileQuestions ? .recommendations : .welcome
            return
        }
        if let id = draft.currentStepID,
           let step = OnboardingStep(rawValue: id),
           available.contains(step) {
            currentStep = step
            phase = .questions
            return
        }
        // The remembered step no longer applies — or was written by a build
        // that had a step this one does not. Resume at the first unanswered
        // question rather than restarting or dead-ending.
        currentStep = available.first { !draft.completedStepIDs.contains($0.rawValue) } ?? available.last
        phase = .questions
    }

    // MARK: Navigation

    func choosePath(_ path: TrainingStructureChoice) {
        guard allowNavigation() else { return }
        draft.selectedPath = path
        draft.hasReachedRecommendations = false
        direction = .forward
        let available = steps
        if let first = available.first {
            currentStep = first
            phase = .questions
        } else {
            // Free Workout with units already settled: nothing to ask.
            currentStep = nil
            phase = .completed(.freeWorkout)
        }
        persist()
    }

    func goBack() {
        let hadPendingAutoAdvance = cancelAutoAdvance()
        guard allowNavigation() else { return }
        validationMessage = nil

        // Back inside the auto-advance window means "undo that tap", not "go to
        // the previous question".
        //
        // The lifter meant to tap 4 and hit 5. The card fills, and they reach
        // for Back. Sending them to the question *before* this one — which they
        // had already answered correctly — while quietly keeping the 5 is the
        // worst of both: it moves them away from the mistake and preserves it.
        // So the wrong answer is cleared and the screen stays put.
        if hadPendingAutoAdvance, let step = currentStep {
            clearAnswer(for: step)
            return
        }

        direction = .backward

        switch phase {
        case .welcome:
            return
        case .recommendations:
            currentStep = steps.last
            draft.hasReachedRecommendations = false
            phase = .questions
        case .completed:
            return
        case .questions:
            guard let index = currentStepIndex else {
                phase = .welcome
                currentStep = nil
                return
            }
            if index == 0 {
                // Back off the first question returns to the routing choice.
                // The path itself is cleared so the welcome screen is a live
                // question again rather than a screen with a stale answer.
                draft.selectedPath = nil
                draft.hasReachedRecommendations = false
                currentStep = nil
                phase = .welcome
            } else {
                currentStep = steps[index - 1]
            }
        }
        persist()
    }

    /// Commits the current step and moves on, refusing when the step requires
    /// an answer that has not been given.
    func advance() {
        cancelAutoAdvance()
        guard allowNavigation() else { return }
        guard let step = currentStep else { return }

        if let message = validationFailure(for: step) {
            validationMessage = message
            validationAttemptCount += 1
            return
        }
        commit(step)
    }

    /// Leaves the step unanswered on purpose. A skipped question stores nothing
    /// — never a default standing in for an answer.
    func skip() {
        cancelAutoAdvance()
        guard allowNavigation() else { return }
        guard let step = currentStep, step.isSkippable else { return }
        clearAnswer(for: step)
        commit(step, markCompleted: false)
    }

    private func commit(_ step: OnboardingStep, markCompleted: Bool = true) {
        // Arms the cooldown on the auto-advance path too. Without this the gate
        // was only ever stamped by `advance()`, so a run of self-advancing
        // questions left it permanently disarmed — and a double tap on a card
        // could be absorbed by the *next* question's card sliding into the same
        // coordinates, answering it by accident and skipping two steps.
        lastNavigationDate = Date()
        validationMessage = nil
        direction = .forward
        if markCompleted, !draft.completedStepIDs.contains(step.rawValue) {
            draft.completedStepIDs.append(step.rawValue)
        }

        // Recomputed *after* the answer landed: this step may have just added
        // or removed the ones behind it.
        let available = steps
        if let index = available.firstIndex(of: step), index + 1 < available.count {
            currentStep = available[index + 1]
        } else {
            currentStep = nil
            draft.hasReachedRecommendations = true
            // Free Workout never reaches recommendations. It answered at most
            // one question, and ranking plans for someone who explicitly chose
            // not to follow one would be the flow ignoring what it was told.
            phase = draft.selectedPath?.asksProfileQuestions == true
                ? .recommendations
                : .completed(.freeWorkout)
        }
        persist()
    }

    /// Called when a single-answer card is tapped. Selection and navigation are
    /// the same gesture on those screens, so the flow moves on by itself — but
    /// only after the card has visibly become the selected one, and only if the
    /// lifter has not gone back in the meantime.
    func scheduleAutoAdvanceIfNeeded(from step: OnboardingStep) {
        guard step.advancesOnSelection else { return }
        cancelAutoAdvance()
        autoAdvanceTask = Task { [weak self] in
            try? await Task.sleep(for: Self.autoAdvanceDelay)
            guard !Task.isCancelled else { return }
            guard let self, self.currentStep == step, self.phase == .questions else { return }
            self.commit(step)
        }
    }

    /// Cancels any pending auto-advance, reporting whether there was one.
    ///
    /// The return value is what lets `goBack()` tell "undo the tap I just made"
    /// apart from "leave this question".
    @discardableResult
    func cancelAutoAdvance() -> Bool {
        let wasPending = autoAdvanceTask != nil
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        return wasPending
    }

    /// Records the outcome of activating a plan or rotation, moving the flow to
    /// its one completion screen.
    func complete(with summary: OnboardingActivationSummary) {
        cancelAutoAdvance()
        direction = .forward
        currentStep = nil
        phase = .completed(summary)
    }

    /// The lifter chose to browse the full catalogue or to start training
    /// instead. The draft is finished with either way.
    func finish() {
        cancelAutoAdvance()
        store.clear()
    }

    // MARK: Answers

    /// Mutates the draft and keeps the persisted copy in step.
    ///
    /// Every answer goes through here so that "the draft survives a relaunch"
    /// is a property of the type rather than a rule each screen has to
    /// remember.
    func update(_ mutate: (inout OnboardingDraft) -> Void) {
        validationMessage = nil
        mutate(&draft)
        persist()
    }

    /// Whether the lifter has already committed this step once and come back
    /// to it.
    ///
    /// This is what decides whether a self-advancing step also offers a
    /// Continue button. It must be "committed before", not "has an answer": on
    /// the first pass, an answer exists for the 260 ms between the tap and the
    /// auto-advance, and a button that appears for a quarter of a second on its
    /// way off screen is a flicker. On a revisit there is no auto-advance
    /// pending, and without a button the only way forward would be re-tapping
    /// the option that is already chosen.
    func isRevisiting(_ step: OnboardingStep) -> Bool {
        draft.completedStepIDs.contains(step.rawValue)
    }

    /// Whether this step already holds an answer.
    func hasAnswer(for step: OnboardingStep) -> Bool {
        switch step {
        case .discipline: draft.discipline != nil
        case .goal: draft.goal != nil
        case .experience: draft.experience != nil
        case .frequency: draft.preferredDaysPerWeek != nil || draft.scheduleFlexibility == .variable
        case .weekdays: !draft.preferredWeekdays.isEmpty
        case .cadence: draft.rotationCadence != nil
        case .sessionDuration: draft.sessionDuration != nil
        case .location: draft.location != nil
        case .equipment: !draft.equipmentIDs.isEmpty
        case .specializedEquipment: !draft.specializedEquipmentIDs.isEmpty
        case .units: draft.unitSystem != nil
        case .focusAreas: !draft.focusAreas.isEmpty
        case .competition: draft.competition?.isEmpty == false
        case .mobilityGoal: draft.mobilityGoal != nil
        case .mobilityExperience: draft.mobilityExperience != nil
        case .mobilityFrequency: draft.mobilityFrequency != nil
        }
    }

    /// Returns a step to unanswered. Not private because the refinement sheets
    /// need it: they replaced the linear flow's Skip button, and without a way
    /// to clear, a refinement would be the only answer in the app that cannot
    /// be taken back to "not said".
    func clearAnswer(for step: OnboardingStep) {
        update { draft in
            switch step {
            case .discipline: draft.discipline = nil
            case .goal: draft.goal = nil
            case .experience: draft.experience = nil
            case .frequency:
                draft.preferredDaysPerWeek = nil
                draft.scheduleFlexibility = nil
            case .weekdays: draft.preferredWeekdays = []
            case .cadence: draft.rotationCadence = nil
            case .sessionDuration: draft.sessionDuration = nil
            case .location: draft.location = nil
            case .equipment: draft.equipmentIDs = []
            case .specializedEquipment: draft.specializedEquipmentIDs = []
            case .units: draft.unitSystem = nil
            case .focusAreas: draft.focusAreas = []
            case .competition: draft.competition = nil
            case .mobilityGoal: draft.mobilityGoal = nil
            case .mobilityExperience: draft.mobilityExperience = nil
            case .mobilityFrequency: draft.mobilityFrequency = nil
            }
        }
    }

    /// The message shown when a required step is committed empty, or `nil` when
    /// the step is satisfied. Only the two unskippable steps can fail.
    private func validationFailure(for step: OnboardingStep) -> String? {
        switch step {
        case .units where draft.unitSystem == nil:
            String(localized: "Choose the units you want weights shown in.")
        case .equipment where draft.equipmentIDs.isEmpty:
            String(localized: "Select at least one, or choose Bodyweight space if that’s all you have.")
        default:
            nil
        }
    }

    private func persist() {
        draft.currentStepID = currentStep?.rawValue
        store.save(draft)
    }

    /// Swallows a second navigation arriving too soon after the first.
    ///
    /// The failure this prevents is real and easy to hit: a double tap on
    /// Continue, or a tap that lands as an auto-advance fires, would otherwise
    /// move two steps and leave a question silently unanswered behind the
    /// lifter's back.
    private func allowNavigation() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastNavigationDate) >= Self.inputCooldown else { return false }
        lastNavigationDate = now
        return true
    }
}

/// What the completion screen has to report. Carried rather than re-derived so
/// the screen cannot disagree with what was actually activated.
enum OnboardingActivationSummary: Equatable, Sendable {
    case plan(name: String, firstSessionDate: Date?, sessionCount: Int)
    case rotation(name: String, nextWorkoutName: String?)
    /// Nothing was activated: the lifter is going straight to training.
    case freeWorkout
}
