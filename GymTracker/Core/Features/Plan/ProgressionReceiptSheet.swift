import SwiftData
import SwiftUI

/// Post-save receipt list: one open proposal per unresolved
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
    @Query private var runs: [PlanRun]
    @State private var actionErrorMessage: String?

    init(planRunID: UUID, workoutID: UUID) {
        self.planRunID = planRunID
        self.workoutID = workoutID
        let predicate = #Predicate<PlanProgressionRecommendationRecord> { record in
            record.planRunID == planRunID && record.workoutID == workoutID && record.isResolved == false
        }
        _records = Query(filter: predicate, sort: [SortDescriptor(\.createdAt)])
        _runs = Query(filter: #Predicate<PlanRun> { $0.id == planRunID })
    }

    var body: some View {
        let run = runs.first
        let plannedExercises = plannedExercisesByProgressionKey(in: run)

        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    ForEach(records) { record in
                        card(
                            for: record,
                            run: run,
                            plannedExercisesByProgressionKey: plannedExercises
                        )
                    }
                }
                .padding(Spacing.l)
            }
            .background(Color.trameCanvas.ignoresSafeArea())
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

    /// Exercise identity for each receipt. The record only carries a
    /// `progressionKey` string; the exercise name and its load unit live on
    /// the plan's `PlannedExercise`, looked up here for display only — never
    /// used to recompute the recommendation itself.
    private func plannedExercisesByProgressionKey(
        in run: PlanRun?
    ) -> [String: PlannedExercise] {
        guard let run else { return [:] }
        var map: [String: PlannedExercise] = [:]
        for planned in (run.plan?.orderedWeeks.flatMap(\.orderedPlannedWorkouts).flatMap(\.orderedPlannedExercises) ?? []) {
            map[planned.progressionKey] = planned
        }
        return map
    }

    @ViewBuilder
    private func card(
        for record: PlanProgressionRecommendationRecord,
        run: PlanRun?,
        plannedExercisesByProgressionKey: [String: PlannedExercise]
    ) -> some View {
        let plannedExercise = plannedExercisesByProgressionKey[record.progressionKey]
        let preview = run.map { PlanProgressionRecommendationService.preview(record, in: $0) }
        let presentation = ProgressionReceiptPresentation(
            record: record,
            exerciseName: plannedExercise?.exercise.name ?? String(localized: "Exercise"),
            preview: preview
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
        guard let run = runs.first else {
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
        guard let run = runs.first else {
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
        VStack(alignment: .leading, spacing: Spacing.l) {
            header

            // Named sections, because a receipt is not a confirmation prompt.
            receiptSection("WHY THIS CHANGED") {
                evidence

                whyButton
            }

            receiptSection("EFFECT ON YOUR PLAN") {
                Text(presentation.planEffectText)
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let preview = presentation.preview {
                previewDetails(preview)
            }

            actions
        }
        .padding(.leading, Spacing.m)
        .padding(.vertical, Spacing.s)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.trameStrength).frame(width: 4)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(Color.trameSeparator).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.trameSeparator).frame(height: 1)
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

    /// Who the change is for, and what it proposes — in that order, with the
    /// number carrying the weight.
    ///
    /// The rule label moved below the target and lost its primary tint. It is
    /// provenance, not the headline; tinted and placed above the proposal it
    /// competed with the one value the lifter is here to decide about.
    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Label(presentation.exerciseName, systemImage: AppIcon.progression)
                .font(AppFont.headlineSemibold)
                .foregroundStyle(Color.trameText)

            if let target = presentation.proposedLoadText {
                Text("Next target: \(target)")
                    .font(AppFont.metricHero)
                    .foregroundStyle(Color.trameText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(presentation.proposedChangeText)
                    .font(AppFont.titleSmallSemibold)
                    .foregroundStyle(Color.trameText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(presentation.ruleLabel)
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)
        }
    }

    private func receiptSection<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            TrameDomainSectionRule(title: title, color: Color.trameStrength)

            content()
        }
    }

    private var whyButton: some View {
        WhyButton(identifier: "progression-receipt-why-\(presentation.id.uuidString)") {
            isShowingWhy = true
        }
    }

    @ViewBuilder
    private func previewDetails(_ preview: ProgressionRecommendationPreview) -> some View {
        let details = ProgressionReceiptPreviewPresentation.make(
            preview: preview,
            unit: presentation.unit
        )

        receiptSection("WHAT CHANGES") {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(Array(details.changedFields.enumerated()), id: \.offset) { index, line in
                    Label {
                        Text(line)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: AppIcon.progression)
                    }
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.trameText)
                    .accessibilityIdentifier("progression-receipt-preview-change-\(index)-\(presentation.id.uuidString)")
                }
                Text(details.futureScope)
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("progression-receipt-preview-scope-\(presentation.id.uuidString)")
            }
        }

        receiptSection("WHAT STAYS UNCHANGED") {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(Array(details.unchangedGuarantees.enumerated()), id: \.offset) { index, line in
                    Label {
                        Text(line)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: AppIcon.checkmark)
                    }
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityIdentifier("progression-receipt-preview-unchanged-\(index)-\(presentation.id.uuidString)")
                }
                if let availabilityNote = details.availabilityNote {
                    Text(availabilityNote)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.trameSubdued)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("progression-receipt-preview-incomplete-\(presentation.id.uuidString)")
                }
            }
        }
    }

    @ViewBuilder
    private var evidence: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(presentation.evidenceLines, id: \.self) { line in
                Text(line)
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let qualifier = presentation.evidenceQualifier {
                Text(qualifier)
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        if isEditingLoad {
            editLoadActions
        } else {
            // Three tiers, stacked, never packed side by side. The old layout
            // put a filled button and two identical bordered ones in a row,
            // which made "apply", "choose another value" and "keep what I
            // have" look like three equivalent choices — and pushed all three
            // labels into truncation at larger text sizes. Applying is the
            // recommendation, choosing a value is a deliberate override, and
            // keeping the current load is an ordinary decline; the weight of
            // each control now says so.
            VStack(spacing: Spacing.s) {
                Button {
                    onApply()
                } label: {
                    Text(presentation.acceptActionTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.tramePrimaryAction)
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
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .accessibilityIdentifier("progression-receipt-apply-different-\(presentation.id.uuidString)")
                }

                // Text, not a bordered box. Declining stays a first-class,
                // one-tap choice — it is simply not the proposal.
                Button {
                    onDecline()
                } label: {
                    Text(presentation.declineActionTitle)
                        .font(AppFont.subheadlineSemibold)
                        .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.trameActionDeep)
                .accessibilityIdentifier("progression-receipt-decline-\(presentation.id.uuidString)")
            }
        }
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
                .buttonStyle(.tramePrimaryAction)
                .frame(minHeight: 44)
                .accessibilityIdentifier("progression-receipt-confirm-different-\(presentation.id.uuidString)")
            }
        }
    }
}
