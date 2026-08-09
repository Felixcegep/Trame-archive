import SwiftData
import SwiftUI

/// What onboarding is asking the app to do once it is finished with the screen.
///
/// The flow never navigates the app itself. It reports, and `RootView` — which
/// owns the tabs, the paths, and the active-workout lifecycle — decides. That
/// boundary is the whole reason this feature is not another six `@State`
/// properties on the root.
enum OnboardingOutcome: Equatable {
    /// The lifter asked to start training right now, in as many words.
    case startFreeWorkout
    /// A plan or rotation is active. Land on Today, where it now appears.
    case openToday
    /// The lifter would rather choose for themselves.
    case browseAllPlans
    /// Open the plan that was just activated.
    case reviewActivePlan
}

/// The container for the whole first-run experience.
///
/// Presented after the launch experience has resolved, never during it: the
/// brand animation is not a loading spinner and must not be extended to cover
/// this screen's preparation, nor replayed when the lifter navigates backwards
/// inside the flow.
struct OnboardingFlowView: View {
    /// Starts a compiled plan through the root's guarded path. Onboarding does
    /// not decide whether a plan may become the active one any more than the
    /// catalogue does — see `ProgramCatalogDetailView.onStartPlan`.
    let onStartPlan: (WorkoutPlan, Date) -> ProgramActivationOutcome
    let onFinish: (OnboardingOutcome) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var coordinator = OnboardingCoordinator()
    @State private var path: [OnboardingRoute] = []
    /// The profile is written once, when the questions are done — not per
    /// answer, and not only on activation. A lifter who answers everything and
    /// then chooses to browse the catalogue has still told us how they train.
    @State private var hasWrittenProfile = false
    /// Increments only when a plan or rotation actually became active.
    @State private var setupCompletionCount = 0

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationDestination(for: OnboardingRoute.self) { route in
                    switch route {
                    case .program(let programID):
                        programDestination(programID)
                    case .mobilityProgram(let programID):
                        mobilityProgramDestination(programID)
                    }
                }
        }
        .background(Color.gymBackground)
        .accessibilityIdentifier("onboarding")
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch coordinator.phase {
            case .welcome:
                WelcomeView(
                    onChoosePlan: { coordinator.choosePath(.plan) },
                    onChooseRotation: { coordinator.choosePath(.rotation) },
                    onSkip: { coordinator.choosePath(.freeWorkout) }
                )

            case .questions:
                if let step = coordinator.currentStep {
                    OnboardingQuestionView(coordinator: coordinator, step: step)
                }

            case .recommendations:
                OnboardingRecommendationsView(
                    coordinator: coordinator,
                    onOpenProgram: { path.append(.program($0)) },
                    onOpenMobilityProgram: { path.append(.mobilityProgram($0)) },
                    onBrowseAll: { finish(.browseAllPlans) },
                    onStartFreeWorkout: { finish(.startFreeWorkout) },
                    onDraftRefined: persistRefinedDraft
                )

            case .completed(let summary):
                completion(for: summary)
            }
        }
        // Keyed on the phase alone, deliberately *not* on the current step:
        // moving between questions must not replace this container, or the
        // scaffold's directional transition would never run.
        .id(phaseIdentity)
        // Phase changes crossfade; the step-to-step motion inside the question
        // phase is the scaffold's, and is directional. Two different
        // transitions because they mean two different things: moving between
        // questions is travel along a sequence, while moving from questions to
        // results is a change of context.
        .transition(.opacity)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : AppMotion.layout, value: phaseIdentity)
        // Session-level completion, after persistence — which is exactly what
        // `.sessionSaved` is reserved for. It cannot fire on restoration: a
        // restored flow only ever resumes into `.completed(.freeWorkout)`,
        // which activates nothing and is filtered out below.
        .gymFeedback(.sessionSaved, trigger: setupCompletionCount)
        .onChange(of: coordinator.phase) { _, newPhase in
            switch newPhase {
            case .recommendations:
                writeProfileIfNeeded()
            case .completed(.plan), .completed(.rotation):
                setupCompletionCount += 1
            case .welcome, .questions, .completed(.freeWorkout):
                break
            }
        }
    }

    /// A stable token per phase, ignoring the phase's payload. Recomputing it
    /// from the summary would replace the completion screen mid-animation.
    private var phaseIdentity: String {
        switch coordinator.phase {
        case .welcome: "welcome"
        case .questions: "questions"
        case .recommendations: "recommendations"
        case .completed: "completed"
        }
    }

    @ViewBuilder
    private func completion(for summary: OnboardingActivationSummary) -> some View {
        switch summary {
        case .freeWorkout:
            // Nothing to confirm. A "you're all set" screen after a lifter has
            // explicitly asked to skip setup is the flow congratulating itself.
            //
            // Today rather than a started workout: choosing to decide for
            // yourself is a statement about how sessions get picked, not a
            // request to begin one this second — and an active workout that
            // starts itself is a state the lifter then has to discard.
            Color.gymBackground
                .onAppear { finish(.openToday) }
        case .plan, .rotation:
            OnboardingCompletionView(
                summary: summary,
                onOpenToday: { finish(.openToday) },
                onReviewPlan: { finish(.reviewActivePlan) }
            )
        }
    }

    /// The catalogue's own detail screen, unchanged.
    ///
    /// Activation lives there — the setup sheet, the intake inputs, the start
    /// date, the validation. Onboarding deliberately does not reimplement any
    /// of it; it just watches for the result.
    @ViewBuilder
    private func programDestination(_ programID: UUID) -> some View {
        if let record = programRecord(programID) {
            ProgramCatalogDetailView(record: record, onStartPlan: onStartPlan) {
                path.removeAll()
                writeProfileIfNeeded()
                if let summary = OnboardingActivationSummary.current(using: modelContext) {
                    coordinator.complete(with: summary)
                } else {
                    // Activation reported success but nothing is active — a
                    // conflict resolution or a rollback. Sending the lifter to
                    // a completion screen that names no plan would be worse
                    // than sending them to Today, where the truth is visible.
                    finish(.openToday)
                }
            }
        } else {
            ContentUnavailableView(
                "Plan unavailable",
                systemImage: AppIcon.warning,
                description: Text("This plan may have been removed or replaced.")
            )
        }
    }

    private func programRecord(_ id: UUID) -> ProgramDefinitionRecord? {
        try? modelContext.fetch(FetchDescriptor<ProgramDefinitionRecord>()).first { $0.id == id }
    }

    /// Mobility's own detail screen, unchanged, mirroring `programDestination`.
    ///
    /// It has no completion closure — activating a mobility plan calls the
    /// screen's own `dismiss()`, which simply pops back to the recommendations
    /// list here, same as it pops back to `MobilityProgramCatalogView`
    /// everywhere else it is pushed. Onboarding does not reimplement
    /// activation or route the lifter to its own completion screen for a
    /// mobility plan: the flow's one completion screen is reserved for the
    /// training-structure choice this whole flow exists to make (see
    /// `OnboardingActivationSummary`), and a mobility plan can be started
    /// alongside any of its three outcomes, not only as an alternative to them.
    @ViewBuilder
    private func mobilityProgramDestination(_ programID: UUID) -> some View {
        if let record = mobilityProgramRecord(programID) {
            MobilityProgramDetailView(record: record)
        } else {
            ContentUnavailableView(
                "Plan unavailable",
                systemImage: AppIcon.warning,
                description: Text("This plan may have been removed or replaced.")
            )
        }
    }

    private func mobilityProgramRecord(_ id: UUID) -> MobilityProgramDefinitionRecord? {
        try? modelContext.fetch(FetchDescriptor<MobilityProgramDefinitionRecord>()).first { $0.id == id }
    }

    /// Commits the answers to the profile and to the unit preference.
    ///
    /// Preferences only. Nothing here can reach a workout, a plan run, or a
    /// progression receipt, which is what makes "changing an answer never
    /// rewrites training" true by construction rather than by review.
    private func writeProfileIfNeeded() {
        guard !hasWrittenProfile else { return }
        hasWrittenProfile = true
        if let unitSystem = coordinator.draft.unitSystem {
            TrainingProfileService.applyUnitSystem(unitSystem)
        } else if !UnitSystemDefault.hasStoredPreference {
            // Only when nothing has ever been stored. The draft can legitimately
            // reach here empty — a Free Workout lifter whose units were already
            // settled is never asked — and writing the locale's guess over a
            // preference the lifter had already expressed would be this flow
            // silently overruling an answer it did not take.
            TrainingProfileService.applyUnitSystem(UnitSystemDefault.suggested)
        }
        TrainingProfileService.apply(coordinator.draft, using: modelContext)
    }

    /// Persists a refinement made *after* the initial write.
    ///
    /// `writeProfileIfNeeded` above is deliberately one-shot — see its own
    /// comment — so an answer changed afterward, in
    /// `OnboardingRefinementSheet` or the mobility intake sheet, updated the
    /// in-memory draft and the on-screen ranking but never reached
    /// `TrainingProfile` itself. Nothing downstream that trusts the
    /// persisted record instead of this screen's live draft could see the
    /// change.
    ///
    /// Bypasses the one-shot guard on purpose, and does not set it: this is
    /// wired to a deliberate refinement dismissal, not to every render, so
    /// it cannot regress into the per-answer autosave `hasWrittenProfile`
    /// exists to avoid. `TrainingProfileService.apply` already writes only
    /// the fields the draft has touched and is safe to call repeatedly — the
    /// timestamps it updates are read only for nullability, never for their
    /// exact value (see `PersonalizationPromptCard`).
    private func persistRefinedDraft() {
        TrainingProfileService.apply(coordinator.draft, using: modelContext)
    }

    private func finish(_ outcome: OnboardingOutcome) {
        writeProfileIfNeeded()
        coordinator.finish()
        onFinish(outcome)
    }
}

enum OnboardingRoute: Hashable {
    case program(UUID)
    case mobilityProgram(UUID)
}
