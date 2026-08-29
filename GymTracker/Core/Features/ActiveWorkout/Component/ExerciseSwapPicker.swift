import SwiftUI
import SwiftData

/// Decision-aware exercise substitution.
///
/// Presents only *known* candidates: explicit `ExerciseRelationship.substitution`
/// links and plan-authored `PlannedExerciseAlternative` rows. Similar exercises
/// in a variation family are still not offered here — metadata ranks and
/// explains known options, it never invents one.
///
/// Three steps: state the reason, choose among explained options, confirm what
/// accepting will do. Each option reports its **suitability for today** and its
/// **historical comparability** separately; the app never merges them into a
/// single equivalence score.
struct ExerciseSwapPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var relationships: [ExerciseRelationship]

    let exerciseEntry: ExerciseEntry
    /// Today's plan goal when the workout came from a plan. `nil` for free and
    /// template workouts, which weakens evidence rather than inventing intent.
    var planGoal: PlanGoal?
    /// Plan-authored alternatives for this exposure, when there are any.
    var plannedAlternatives: [PlannedExerciseAlternative] = []
    let onSelect: (Exercise, SubstitutionDecision) -> Void

    @State private var reason: SubstitutionReason?
    @State private var selected: SubstitutionEvaluation?
    @State private var scope: SubstitutionScope = .todayOnly
    @State private var progressionPolicy: ProgressionTransferPolicy = .separate
    @State private var explaining: SubstitutionEvaluation?

    private var context: SubstitutionContext? {
        guard let reason else { return nil }
        return SubstitutionContext.from(
            entry: exerciseEntry,
            goal: planGoal,
            reason: reason
        )
    }

    private var evaluations: [SubstitutionEvaluation] {
        guard let context else { return [] }
        let candidates = SubstitutionCandidateSource.candidates(
            for: exerciseEntry.exercise,
            relationships: relationships,
            plannedAlternatives: plannedAlternatives,
            goal: planGoal,
            role: exerciseEntry.prescribedRole
        )
        return SubstitutionEvaluationService.rankedEvaluations(
            for: exerciseEntry.exercise,
            candidates: candidates,
            context: context
        )
    }

    var body: some View {
        Group {
            if reason == nil {
                SubstitutionReasonPicker(exerciseName: exerciseEntry.displayName) { chosen in
                    reason = chosen
                }
            } else if let selected {
                SubstitutionConfirmationView(
                    originalName: exerciseEntry.displayName,
                    evaluation: selected,
                    reason: reason ?? .notSure,
                    scope: $scope,
                    progressionPolicy: $progressionPolicy,
                    onExplain: { explaining = selected },
                    onConfirm: { confirm(selected) }
                )
            } else {
                optionsList
            }
        }
        .sheet(item: $explaining) { evaluation in
            WhyExplanationView(
                model: SubstitutionPresentation.whyModel(
                    for: evaluation,
                    replacing: exerciseEntry.displayName,
                    scope: scope,
                    policy: progressionPolicy
                )
            )
        }
    }

    private var optionsList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.m) {
                if evaluations.isEmpty {
                    ContentUnavailableView(
                        "No substitutions configured",
                        systemImage: AppIcon.relationship,
                        description: Text("Add a substitution relationship from this exercise’s details before starting the swap.")
                    )
                } else {
                    ForEach(evaluations, id: \.exercise.persistentModelID) { evaluation in
                        SubstitutionOptionRow(
                            evaluation: evaluation,
                            isSelected: selected?.exercise.id == evaluation.exercise.id,
                            onSelect: { select(evaluation) },
                            onExplain: { explaining = evaluation }
                        )
                    }
                }
            }
            .padding(Spacing.l)
        }
        .background(Color.trameCanvas.ignoresSafeArea())
        .navigationTitle("Swap Exercise")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func select(_ evaluation: SubstitutionEvaluation) {
        selected = evaluation
        scope = .todayOnly
        // Never carried over from a previous selection: each option earns its
        // own progression decision, and the default is always separate.
        progressionPolicy = .separate
    }

    private func confirm(_ evaluation: SubstitutionEvaluation) {
        guard let reason else { return }
        let decision = SubstitutionDecision(
            reason: reason,
            scope: scope,
            progressionPolicy: progressionPolicy,
            evaluation: evaluation.snapshot
        )
        onSelect(evaluation.exercise, decision)
        dismiss()
    }
}

/// `sheet(item:)` needs identity; the evaluated exercise supplies it.
extension SubstitutionEvaluation: Identifiable {
    var id: UUID { exercise.id }
}
