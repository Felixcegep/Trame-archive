import SwiftUI
import SwiftData

struct ExerciceEntryCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var exerciseEntry: ExerciseEntry

    let viewModel: ActiveWorkoutViewModel
    let onButtonPress: () -> Void
    let unitSystem: UnitSystem
    let focusedInput: FocusState<SetInputFocus?>.Binding
    @Binding var expandedExerciseID: PersistentIdentifier?
    @Binding var editingCompletedSetID: PersistentIdentifier?
    let previousPerformance: PreviousExercisePerformance?
    let onExerciseCompleted: () -> Void

    @State private var horizontalOffset: CGFloat = 0

    private let swipeTriggerDistance: CGFloat = 70

    var body: some View {
        ZStack(alignment: .trailing) {
            exerciseDoneBackground

            activeExerciseCard
                .offset(x: horizontalOffset)
                .gesture(swipeGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private var activeExerciseCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: disclosureBinding) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    setHeader
                    setRows
                    setActions
                }
                .padding(.top, Spacing.m)
            } label: {
                exerciseHeader
            }
        }
        .padding(isCurrentExercise ? Spacing.l : Spacing.m)
        .background(
            exerciseIsDone && !isCurrentExercise
                ? Color.gymSecondarySurface
                : (isCurrentExercise ? Color.gymPrimarySurface : Color.gymCard)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(
                    expandedExerciseID == exerciseEntry.persistentModelID
                        ? Color.gymPrimary.opacity(0.42)
                        : Color.gymBorder,
                    lineWidth: 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private var disclosureBinding: Binding<Bool> {
        Binding(
            get: { expandedExerciseID == exerciseEntry.persistentModelID },
            set: { isExpanded in
                expandedExerciseID = isExpanded ? exerciseEntry.persistentModelID : nil
            }
        )
    }

    private var exerciseHeader: some View {
        HStack(spacing: Spacing.m) {
            if exerciseIsDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.gymSecondary)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                if isCurrentExercise && !exerciseIsDone {
                    Label("CURRENT EXERCISE", systemImage: AppIcon.circleFill)
                        .font(AppFont.caption2Bold)
                        .tracking(0.55)
                        .foregroundStyle(Color.gymPrimary)
                }

                Text(exerciseEntry.exercise.name)
                    .font(isCurrentExercise ? AppFont.titleSmall : AppFont.headlineSemibold)
                    .foregroundStyle(Color.gymText)
                    .accessibilityIdentifier("active-exercise-\(exerciseEntry.exercise.name)")

                if let loggingSemanticsCaption {
                    Text(loggingSemanticsCaption)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .lineLimit(1)
                }

                if let prescription = prescriptionSummary {
                    Text(prescription)
                        .font(AppFont.captionSemiboldMonospaced)
                        .foregroundStyle(Color.gymPrimary)
                        .lineLimit(1)
                        .accessibilityIdentifier("prescription-summary-\(exerciseEntry.exercise.name)")
                }

                if let recommendationPresentation, !exerciseIsDone {
                    recommendationRow(recommendationPresentation)
                }

                if let previousPerformance {
                    Text(previousPerformanceSummary(previousPerformance))
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .lineLimit(1)
                        .accessibilityIdentifier("previous-performance-\(exerciseEntry.exercise.name)")
                }

                HStack(spacing: Spacing.s) {
                    Text("\(completedSetCount)/\(exerciseEntry.sets.count) sets")
                    Text("•")
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(exerciseDurationText(at: context.date))
                            .monospacedDigit()
                            .accessibilityLabel("Exercise time \(exerciseDurationText(at: context.date))")
                    }
                }
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            Menu {
                Button(role: .destructive) {
                    viewModel.removeExercise(exerciseEntry)
                } label: {
                    Label("Remove exercise", systemImage: AppIcon.trash)
                }
                .accessibilityIdentifier("remove-exercise-\(exerciseEntry.exercise.name)")
            } label: {
                Image(systemName: AppIcon.ellipsis)
                    .font(AppFont.subheadlineBold)
                    .foregroundStyle(Color.gymSubduedText)
                    .frame(width: 30, height: 30)
                    .background(Color.gymText.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("exercise-menu-\(exerciseEntry.exercise.name)")
        }
        .contentShape(Rectangle())
    }

    private var setHeader: some View {
        HStack(spacing: Spacing.s) {
            Text("SET")
                .frame(width: 45, alignment: .leading)

            ForEach(inputTitles, id: \.self) { title in
                Text(title.uppercased())
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer().frame(width: 58)
        }
        .font(AppFont.caption2Bold)
        .tracking(0.55)
        .foregroundStyle(Color.gymSubduedText)
        .padding(.horizontal, 4)
    }

    private var setRows: some View {
        VStack(spacing: 6) {
            ForEach(Array(exerciseEntry.orderedSets.enumerated()), id: \.element.persistentModelID) { index, exerciseSet in
                SetRowView(
                    index: index,
                    exerciseSet: exerciseSet,
                    exerciseEntry: exerciseEntry,
                    viewModel: viewModel,
                    focusedInput: focusedInput,
                    editingCompletedSetID: $editingCompletedSetID,
                    onButtonPress: onButtonPress,
                    onSetCompleted: handleSetCompletion,
                    previousSet: previousPerformance?.set(at: exerciseSet.orderIndex),
                    onRemove: { viewModel.removeSet(exerciseEntry, exerciseSet) }
                )
            }
        }
    }

    private var setActions: some View {
        Button {
            viewModel.addSet(exerciseEntry)
        } label: {
            Label("Add set", systemImage: AppIcon.plus)
        }
        .accessibilityIdentifier("add-set-\(exerciseEntry.exercise.name)")
        .font(AppFont.subheadlineSemibold)
        .foregroundStyle(Color.gymPrimary)
        .buttonStyle(.borderless)
    }

    private var exerciseDoneBackground: some View {
        HStack {
            Spacer()
            Label("Complete", systemImage: AppIcon.checkmarkCircle)
                .font(AppFont.subheadlineBold)
                .foregroundStyle(.white)
                .padding(.trailing, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gymSecondary)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard value.translation.width < 0, abs(value.translation.width) > abs(value.translation.height) else { return }
                guard !reduceMotion else { return }
                let travel = abs(value.translation.width)
                let resistedTravel = travel <= swipeTriggerDistance
                    ? travel
                    : swipeTriggerDistance + ((travel - swipeTriggerDistance) * 0.2)
                horizontalOffset = -resistedTravel
            }
            .onEnded { value in
                let projectedTravel = min(value.translation.width, value.predictedEndTranslation.width)
                guard projectedTravel <= -swipeTriggerDistance,
                      let exerciseSet = viewModel.getNextSet(in: exerciseEntry),
                      viewModel.canComplete(exerciseSet, for: exerciseEntry)
                else {
                    withAnimation(reduceMotion ? nil : AppMotion.gesture) { horizontalOffset = 0 }
                    return
                }

                viewModel.switchStateDoneSet(exerciseEntry, exerciseSet)
                onButtonPress()
                handleSetCompletion()

                withAnimation(reduceMotion ? nil : AppMotion.gesture) { horizontalOffset = 0 }
            }
    }

    private var completedSetCount: Int {
        exerciseEntry.sets.filter(\.done).count
    }

    private var exerciseIsDone: Bool {
        !exerciseEntry.sets.isEmpty && completedSetCount == exerciseEntry.sets.count
    }

    private var isCurrentExercise: Bool {
        expandedExerciseID == exerciseEntry.persistentModelID
    }

    private var exerciseSummaryText: String {
        exerciseEntry.orderedSets.first?.displayText() ?? "No sets"
    }

    private func exerciseDurationText(at date: Date) -> String {
        let totalSeconds = max(0, Int(exerciseEntry.activeDuration(at: date)))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private var prescriptionSummary: String? {
        guard let setCount = exerciseEntry.prescribedSets,
              let minimum = exerciseEntry.prescribedRepRangeMinimum,
              let maximum = exerciseEntry.prescribedRepRangeMaximum
        else {
            return nil
        }

        var components = ["\(setCount) × \(minimum)-\(maximum)"]
        if let rpe = exerciseEntry.prescribedRPE {
            components.append("RPE \(Formatters.formatFloat(Float(rpe)))")
        }
        if let rir = exerciseEntry.prescribedRIR {
            components.append("RIR \(rir)")
        }
        return components.joined(separator: "  ·  ")
    }

    private var trackingType: TrackingType {
        exerciseEntry.trackingTypeSnapshot
    }

    private var loggingSemantics: LoggingSemantics {
        exerciseEntry.loggingSemanticsSnapshot
    }

    private var loggingSemanticsCaption: String? {
        var parts: [String] = []
        if loggingSemantics.laterality == .unilateral && loggingSemantics.repCountingStyle == .perSide {
            parts.append("Logged per side")
        }
        if loggingSemantics.weightEntryStyle == .perLoadUnit {
            parts.append("Weight per unit (×\(loggingSemantics.loadUnitCount))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var recommendationPresentation: RecommendationPresentation? {
        RecommendationPresentation(entry: exerciseEntry)
    }

    @ViewBuilder
    private func recommendationRow(_ presentation: RecommendationPresentation) -> some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            Text(presentation.explanation)
                .font(AppFont.caption)
                .foregroundStyle(
                    presentation.decision == .increase
                        ? Color.gymPrimary
                        : Color.gymSubduedText
                )
                .lineLimit(2)
                .accessibilityIdentifier("recommendation-\(exerciseEntry.exercise.name)")

            Spacer(minLength: 0)

            if shouldShowApplyRecommendation(presentation) {
                Button {
                    viewModel.applyRecommendation(to: exerciseEntry)
                } label: {
                    Text("Apply \(presentation.appliedLoadText)")
                        .font(AppFont.captionBold)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("apply-recommendation-\(exerciseEntry.exercise.name)")
            }
        }
    }

    private func shouldShowApplyRecommendation(_ presentation: RecommendationPresentation) -> Bool {
        let incompleteSets = exerciseEntry.orderedSets.filter { !$0.done }
        guard !incompleteSets.isEmpty else { return false }
        return incompleteSets.contains { set in
            let convertedLoad = UnitConversion.weight(
                presentation.recommendedLoad,
                from: presentation.unit,
                to: set.weightType
            )
            return abs(set.weight - convertedLoad) > 0.0001
        }
    }

    private var inputTitles: [String] {
        var titles: [String] = []
        if trackingType.usesReps {
            let isPerSide = loggingSemantics.laterality == .unilateral && loggingSemantics.repCountingStyle == .perSide
            titles.append(isPerSide ? "Reps / side" : "Reps")
        }
        if trackingType.usesWeight {
            let unitLabel = unitSystem == .metric ? "kg" : "lbs"
            let isPerUnit = loggingSemantics.weightEntryStyle == .perLoadUnit
            titles.append(isPerUnit ? "Weight (\(unitLabel) each)" : "Weight (\(unitLabel))")
        }
        if trackingType.usesDuration { titles.append("Seconds") }
        if trackingType.usesDistance { titles.append("Distance") }
        return titles
    }

    private func previousPerformanceSummary(_ performance: PreviousExercisePerformance) -> String {
        let date = performance.workoutDate.formatted(.dateTime.month(.abbreviated).day())
        let sets = performance.sets
        guard let first = sets.first else { return "Last time: \(date)" }

        if trackingType.usesWeight {
            let matchingReps = sets.allSatisfy { $0.repetitions == first.repetitions }
            let matchingWeight = sets.allSatisfy { $0.weight == first.weight && $0.weightType == first.weightType }
            if matchingReps && matchingWeight {
                return "Last time: \(sets.count) × \(Formatters.formatFloat(first.repetitions)) @ \(Formatters.formatFloat(first.weight)) \(first.weightType.rawValue) · \(date)"
            }
            return "Last time: \(sets.count) sets · up to \(Formatters.formatFloat(sets.map(\.weight).max() ?? 0)) \(first.weightType.rawValue) · \(date)"
        }

        if trackingType.usesReps {
            let matchingReps = sets.allSatisfy { $0.repetitions == first.repetitions }
            let reps = matchingReps
                ? Formatters.formatFloat(first.repetitions)
                : "\(Formatters.formatFloat(sets.map(\.repetitions).min() ?? 0))–\(Formatters.formatFloat(sets.map(\.repetitions).max() ?? 0))"
            return "Last time: \(sets.count) × \(reps) reps · \(date)"
        }

        return "Last time: \(sets.count) sets · \(date)"
    }

    private func handleSetCompletion() {
        guard exerciseIsDone else { return }
        onExerciseCompleted()
    }
}
