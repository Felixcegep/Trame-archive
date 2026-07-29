import SwiftData
import SwiftUI

/// Post-save receipt list: one card per unresolved
/// `PlanProgressionRecommendationRecord` for the plan run and workout that
/// was just saved.
///
/// `records` is a live SwiftData query scoped to `planRunID` and `workoutID`
/// — there is no second source of recommendation state, and nothing here is
/// cached on a view model. Every resolution goes through the existing
/// `PlanProgressionRecommendationService`, inside its own transaction. This
/// sheet only ever reads and resolves recommendations that already exist; it
/// never applies to a completed `Workout`, `ExerciseEntry`, `ExerciseSet`, or
/// any performed snapshot. Dismissing with receipts left unresolved is a
/// normal outcome, not an error state.
struct ProgressionReceiptSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let planRunID: UUID
    let workoutID: UUID

    @Query private var records: [PlanProgressionRecommendationRecord]
    @State private var actionErrorMessage: String?

    init(planRunID: UUID, workoutID: UUID) {
        self.planRunID = planRunID
        self.workoutID = workoutID
        let predicate = #Predicate<PlanProgressionRecommendationRecord> { record in
            record.planRunID == planRunID && record.workoutID == workoutID && record.isResolved == false
        }
        _records = Query(filter: predicate, sort: [SortDescriptor(\.createdAt)])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    ForEach(records) { record in
                        card(for: record)
                    }
                }
                .padding(Spacing.l)
            }
            .background(Color.gymBackground.ignoresSafeArea())
            .navigationTitle("Progression updates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("progression-receipt-done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .alert(
            "Couldn’t save your decision",
            isPresented: Binding(
                get: { actionErrorMessage != nil },
                set: { if !$0 { actionErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { actionErrorMessage = nil }
        } message: {
            Text(actionErrorMessage ?? "")
        }
    }

    // MARK: - Row lookup

    /// The run the receipts belong to. Fetched by id rather than passed in
    /// so the sheet stays a thin, self-contained reader over persisted
    /// state — the same run reference the resolution service itself needs.
    private var run: PlanRun? {
        (try? modelContext.fetch(FetchDescriptor<PlanRun>()))?.first { $0.id == planRunID }
    }

    /// Exercise identity for each receipt. The record only carries a
    /// `progressionKey` string; the exercise name and its load unit live on
    /// the plan's `PlannedExercise`, looked up here for display only — never
    /// used to recompute the recommendation itself.
    private var plannedExercisesByProgressionKey: [String: PlannedExercise] {
        guard let run else { return [:] }
        var map: [String: PlannedExercise] = [:]
        for planned in (run.plan?.orderedWeeks.flatMap(\.orderedPlannedWorkouts).flatMap(\.orderedPlannedExercises) ?? []) {
            map[planned.progressionKey] = planned
        }
        return map
    }

    @ViewBuilder
    private func card(for record: PlanProgressionRecommendationRecord) -> some View {
        let plannedExercise = plannedExercisesByProgressionKey[record.progressionKey]
        let presentation = ProgressionReceiptPresentation(
            record: record,
            exerciseName: plannedExercise?.exercise.name ?? String(localized: "Exercise")
        )
        ProgressionReceiptCard(
            presentation: presentation,
            onApply: { apply(record) },
            onApplyDifferent: { load in applyDifferent(record, load: load) },
            onDecline: { decline(record) }
        )
    }

    // MARK: - Actions

    private func apply(_ record: PlanProgressionRecommendationRecord) {
        guard let run else {
            actionErrorMessage = String(localized: "This plan run could not be found.")
            return
        }
        do {
            try PlanProgressionRecommendationService.accept(record, in: run, context: modelContext)
        } catch {
            actionErrorMessage = String(localized: "Try again.")
        }
    }

    private func applyDifferent(_ record: PlanProgressionRecommendationRecord, load: Double) {
        guard let run else {
            actionErrorMessage = String(localized: "This plan run could not be found.")
            return
        }
        do {
            try PlanProgressionRecommendationService.accept(record, withLoad: load, in: run, context: modelContext)
        } catch {
            actionErrorMessage = String(localized: "Try again.")
        }
    }

    private func decline(_ record: PlanProgressionRecommendationRecord) {
        do {
            try PlanProgressionRecommendationService.decline(record, context: modelContext)
        } catch {
            actionErrorMessage = String(localized: "Try again.")
        }
    }
}

/// The single receipt card. VoiceOver reads the proposed change and its
/// evidence before any action, matching `ProgressionRecommendationCard`'s
/// house style for the equivalent template-path surface.
private struct ProgressionReceiptCard: View {
    let presentation: ProgressionReceiptPresentation
    let onApply: () -> Void
    let onApplyDifferent: (Double) -> Void
    let onDecline: () -> Void

    @State private var isEditingLoad = false
    @State private var editedLoad: Double = 0
    @State private var isShowingWhy = false

    var body: some View {
        GymCard(variant: .current, radius: Radius.medium) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Label(presentation.exerciseName, systemImage: AppIcon.progression)
                    .font(AppFont.headlineSemibold)
                    .foregroundStyle(Color.gymText)

                Text(presentation.ruleLabel)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymPrimary)

                Text(presentation.proposedChangeText)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)

                whyButton

                // Kept inline: the sheet below is the expanded form, not a
                // replacement, so the fast path stays fast.
                evidence

                actions
            }
        }
        // Keep the card addressable as one VoiceOver element with the
        // proposed change and evidence read before its actions, while still
        // exposing every action button to VoiceOver and UI tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("progression-receipt-card-\(presentation.id.uuidString)")
        .sheet(isPresented: $isShowingWhy) {
            WhyExplanationView(model: presentation.whyModel)
        }
    }

    private var whyButton: some View {
        WhyButton(identifier: "progression-receipt-why-\(presentation.id.uuidString)") {
            isShowingWhy = true
        }
    }

    @ViewBuilder
    private var evidence: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(presentation.evidenceLines, id: \.self) { line in
                Text(line)
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let qualifier = presentation.evidenceQualifier {
                Text(qualifier)
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.gymSubtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        if isEditingLoad {
            editLoadActions
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.s) { primaryActions }
                VStack(spacing: Spacing.s) { primaryActions }
            }
        }
    }

    @ViewBuilder
    private var primaryActions: some View {
        Button {
            onApply()
        } label: {
            Text(presentation.acceptActionTitle)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.gymPrimary)
        .frame(minHeight: 44)
        .accessibilityIdentifier("progression-receipt-apply-\(presentation.id.uuidString)")

        if presentation.canApplyDifferentValue {
            Button {
                editedLoad = presentation.proposedLoad ?? 0
                isEditingLoad = true
            } label: {
                Text(presentation.applyDifferentActionTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
            .accessibilityIdentifier("progression-receipt-apply-different-\(presentation.id.uuidString)")
        }

        Button {
            onDecline()
        } label: {
            Text(presentation.declineActionTitle)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .frame(minHeight: 44)
        .accessibilityIdentifier("progression-receipt-decline-\(presentation.id.uuidString)")
    }

    private var editLoadActions: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TextField(String(localized: "New load"), value: $editedLoad, format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
                .accessibilityIdentifier("progression-receipt-load-field-\(presentation.id.uuidString)")

            HStack(spacing: Spacing.s) {
                Button {
                    isEditingLoad = false
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .accessibilityIdentifier("progression-receipt-cancel-different-\(presentation.id.uuidString)")

                Button {
                    onApplyDifferent(editedLoad)
                    isEditingLoad = false
                } label: {
                    Text("Confirm")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.gymPrimary)
                .frame(minHeight: 44)
                .accessibilityIdentifier("progression-receipt-confirm-different-\(presentation.id.uuidString)")
            }
        }
    }
}
