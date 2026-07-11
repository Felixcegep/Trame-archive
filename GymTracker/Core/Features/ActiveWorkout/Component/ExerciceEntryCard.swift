import SwiftUI
import SwiftData

struct ExerciceEntryCard: View {
    @Bindable var exerciseEntry: ExerciceEntry

    let viewModel: ActiveWorkoutViewModel
    let onButtonPress: () -> Void
    let unitSystem: UnitSystem
    @Binding var expandedExerciseID: PersistentIdentifier?
    let onExerciseCompleted: () -> Void

    @State private var horizontalOffset: CGFloat = 0
    @State private var cardWidth: CGFloat = 0

    private let swipeTriggerDistance: CGFloat = 70

    var body: some View {
        Group {
            if exerciseIsDone {
                completedExerciseSummary
            } else {
                ZStack(alignment: .trailing) {
                    exerciseDoneBackground

                    activeExerciseCard
                        .offset(x: horizontalOffset)
                        .gesture(swipeGesture)
                }
            }
        }
        .animation(.snappy, value: exerciseIsDone)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { cardWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in cardWidth = width }
            }
        }
    }

    private var activeExerciseCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: disclosureBinding) {
                VStack(alignment: .leading, spacing: 10) {
                    setHeader
                    setRows
                    setActions
                }
                .padding(.top, 12)
            } label: {
                exerciseHeader
            }
        }
        .padding(isCurrentExercise ? Spacing.l : Spacing.m)
        .background(isCurrentExercise ? WorkoutPalette.primarySurface : WorkoutPalette.surface)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(
                    expandedExerciseID == exerciseEntry.persistentModelID
                        ? WorkoutPalette.primary.opacity(0.42)
                        : WorkoutPalette.border,
                    lineWidth: 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private var completedExerciseSummary: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: AppIcon.checkmark)
                .font(AppFont.subheadlineBold)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(WorkoutPalette.secondary)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(exerciseEntry.exercice.name)
                    .font(AppFont.subheadlineSemibold)
                    .lineLimit(1)
                Text("All \(completedSetCount) sets completed")
                    .font(AppFont.caption)
                    .foregroundStyle(WorkoutPalette.subduedText)
            }

            Spacer()
        }
        .padding(13)
        .background(WorkoutPalette.completedSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                if isCurrentExercise {
                    Label("CURRENT EXERCISE", systemImage: AppIcon.circleFill)
                        .font(AppFont.caption2Bold)
                        .tracking(0.55)
                        .foregroundStyle(WorkoutPalette.primary)
                }

                Text(exerciseEntry.exercice.name)
                    .font(isCurrentExercise ? AppFont.titleSmall : AppFont.headlineSemibold)
                    .foregroundStyle(WorkoutPalette.text)
                    .accessibilityIdentifier("active-exercise-\(exerciseEntry.exercice.name)")

                if let prescription = prescriptionSummary {
                    Text(prescription)
                        .font(AppFont.captionSemiboldMonospaced)
                        .foregroundStyle(WorkoutPalette.primary)
                        .lineLimit(1)
                        .accessibilityIdentifier("prescription-summary-\(exerciseEntry.exercice.name)")
                }

                HStack(spacing: 7) {
                    Text("\(completedSetCount)/\(exerciseEntry.sets.count) sets")
                    Text("•")
                    Text(exerciseSummaryText)
                }
                .font(AppFont.caption)
                .foregroundStyle(WorkoutPalette.subduedText)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            Menu {
                Button(role: .destructive) {
                    viewModel.removeExercise(exerciseEntry)
                } label: {
                    Label("Remove exercise", systemImage: AppIcon.trash)
                }
            } label: {
                Image(systemName: AppIcon.ellipsis)
                    .font(AppFont.subheadlineBold)
                    .foregroundStyle(WorkoutPalette.subduedText)
                    .frame(width: 30, height: 30)
                    .background(WorkoutPalette.text.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
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
        .foregroundStyle(WorkoutPalette.subduedText)
        .padding(.horizontal, 4)
    }

    private var setRows: some View {
        VStack(spacing: 6) {
            ForEach(Array(exerciseEntry.sets.enumerated()), id: \.element.persistentModelID) { index, exerciseSet in
                SetRowView(
                    index: index,
                    exerciseSet: exerciseSet,
                    exerciseEntry: exerciseEntry,
                    viewModel: viewModel,
                    onButtonPress: onButtonPress,
                    onSetCompleted: handleSetCompletion,
                    onRemove: { viewModel.removeSet(exerciseEntry, exerciseSet) }
                )
            }
        }
    }

    private var setActions: some View {
        HStack(spacing: Spacing.md) {
            Button {
                viewModel.addSet(exerciseEntry)
            } label: {
                Label("Add set", systemImage: AppIcon.plus)
            }

            Button {
                viewModel.addSetCopyLastSet(exerciseEntry: exerciseEntry)
            } label: {
                Label("Copy last", systemImage: AppIcon.copy)
            }
        }
        .font(AppFont.subheadlineSemibold)
        .foregroundStyle(WorkoutPalette.primary)
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
        .background(WorkoutPalette.secondary)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard value.translation.width < 0, abs(value.translation.width) > abs(value.translation.height) else { return }
                horizontalOffset = max(value.translation.width, -fullSlideDistance)
            }
            .onEnded { value in
                guard value.translation.width <= -swipeTriggerDistance,
                      let exerciseSet = viewModel.getNextSet(in: exerciseEntry)
                else {
                    withAnimation(.snappy(duration: 0.2)) { horizontalOffset = 0 }
                    return
                }

                viewModel.switchStateDoneSet(exerciseEntry, exerciseSet)
                onButtonPress()
                handleSetCompletion()

                withAnimation(.snappy(duration: 0.22)) { horizontalOffset = -fullSlideDistance }
                Task {
                    try? await Task.sleep(for: .seconds(0.24))
                    await MainActor.run {
                        withAnimation(.snappy(duration: 0.2)) { horizontalOffset = 0 }
                    }
                }
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

    private var fullSlideDistance: CGFloat {
        max(cardWidth, swipeTriggerDistance)
    }

    private var exerciseSummaryText: String {
        exerciseEntry.sets.first?.displayText() ?? "No sets"
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
        exerciseEntry.exercice.trackingType
    }

    private var inputTitles: [String] {
        var titles: [String] = []
        if trackingType.usesReps { titles.append("Reps") }
        if trackingType.usesWeight { titles.append("Weight") }
        if trackingType.usesDuration { titles.append("Time") }
        if trackingType.usesDistance { titles.append("Distance") }
        return titles
    }

    private func handleSetCompletion() {
        guard exerciseIsDone else { return }
        onExerciseCompleted()
    }
}
