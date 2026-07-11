import SwiftUI
import SwiftData

struct SetRowView: View {
    let index: Int
    @Bindable var exerciseSet: ExerciseSet
    let exerciseEntry: ExerciceEntry
    let viewModel: ActiveWorkoutViewModel
    let onButtonPress: () -> Void
    let onSetCompleted: () -> Void
    let onRemove: () -> Void

    @State private var isShowingPlateCalculator = false

    private var trackingType: TrackingType {
        exerciseEntry.exercice.trackingType
    }

    var body: some View {
        HStack(spacing: Spacing.s) {
            Text("\(index + 1)")
                .font(AppFont.subheadlineSemiboldMonospaced)
                .foregroundStyle(exerciseSet.done ? WorkoutPalette.secondary : WorkoutPalette.text)
                .frame(width: 45, alignment: .leading)

            if trackingType.usesReps { repsField }
            if trackingType.usesWeight { weightField }
            if trackingType.usesDuration { durationField }
            if trackingType.usesDistance { distanceField }

            doneButton
            rowMenu
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, 7)
        .background(rowSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }

    private var repsField: some View {
        numberField("Reps", text: Binding(
            get: { Formatters.formatFloat(exerciseSet.repetition) },
            set: { if let value = Float($0) { exerciseSet.repetition = value } }
        ))
    }

    private var weightField: some View {
        HStack(spacing: 0) {
            TextField("Weight", text: Binding(
                get: { Formatters.formatFloat(exerciseSet.weight) },
                set: { if let value = Float($0) { exerciseSet.weight = max(value, 0) } }
            ))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(AppFont.subheadlineMediumMonospaced)

            if exerciseEntry.exercice.supportsPlateCalculator {
                Button {
                    isShowingPlateCalculator = true
                } label: {
                    Image(systemName: AppIcon.plateCalculator)
                        .font(AppFont.captionBold)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(WorkoutPalette.primary)
                .accessibilityLabel("Open plate calculator")
                .accessibilityIdentifier("plate-calculator-\(exerciseEntry.exercice.name)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.leading, Spacing.xs)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .sheet(isPresented: $isShowingPlateCalculator) {
            PlateCalculatorView(
                exerciseSet: exerciseSet,
                usesBarbell: exerciseEntry.exercice.equipmentType == .barbell
            )
                .presentationDetents([.height(560), .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var durationField: some View {
        numberField("Seconds", text: Binding(
            get: { exerciseSet.duration.map { String(Int($0)) } ?? "" },
            set: { exerciseSet.duration = $0.isEmpty ? nil : TimeInterval($0) }
        ))
    }

    private var distanceField: some View {
        numberField("Distance", text: Binding(
            get: {
                guard let distance = exerciseSet.distance else { return "" }
                return Formatters.formatFloat(distance)
            },
            set: { exerciseSet.distance = $0.isEmpty ? nil : Float($0) }
        ))
    }

    private var doneButton: some View {
        Button(action: toggleDone) {
            Image(systemName: exerciseSet.done ? AppIcon.checkmark : AppIcon.circle)
                .font(AppFont.subheadlineBold)
                .foregroundStyle(exerciseSet.done ? .white : WorkoutPalette.primary)
                .frame(width: 28, height: 28)
                .background(exerciseSet.done ? WorkoutPalette.secondary : WorkoutPalette.primary.opacity(0.14))
                .clipShape(Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(exerciseSet.done ? "Mark set incomplete" : "Complete set")
        .accessibilityIdentifier("complete-set-\(exerciseEntry.exercice.name)-\(index)")
    }

    private var isCurrentSet: Bool {
        exerciseEntry.orderedSets.first(where: { !$0.done })?.persistentModelID == exerciseSet.persistentModelID
    }

    private var rowSurface: Color {
        if exerciseSet.done {
            return WorkoutPalette.completedSurface
        }

        return isCurrentSet ? WorkoutPalette.currentSetSurface : WorkoutPalette.rowSurface
    }

    private var rowMenu: some View {
        Menu {
            Button(action: copyPreviousSetValue) {
                Label("Copy previous values", systemImage: AppIcon.copy)
            }
            .disabled(index == 0)

            Button(action: toggleWarmup) {
                Label(exerciseSet.setType == .warmup ? "Mark normal" : "Mark warmup", systemImage: AppIcon.warmup)
            }

            Menu(exerciseSet.rpe.map { "RPE \($0)" } ?? "RPE") {
                Button("No RPE") {
                    exerciseSet.rpe = nil
                }

                ForEach(1...10, id: \.self) { rpe in
                    Button("RPE \(rpe)") {
                        exerciseSet.rpe = rpe
                    }
                }
            }

            Button(role: .destructive, action: onRemove) {
                Label("Delete set", systemImage: AppIcon.trash)
            }
        } label: {
            Image(systemName: AppIcon.ellipsis)
                .font(AppFont.captionBold)
                .foregroundStyle(WorkoutPalette.subduedText)
                .frame(width: 20, height: 28)
        }
        .buttonStyle(.borderless)
    }

    private func numberField(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(AppFont.subheadlineMediumMonospaced)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
    }

    private func toggleDone() {
        let shouldStartRestTimer = !exerciseSet.done
        viewModel.switchStateDoneSet(exerciseEntry, exerciseSet)

        if shouldStartRestTimer {
            onButtonPress()
            onSetCompleted()
        }
    }

    private func copyPreviousSetValue() {
        viewModel.copyPreviousSetValue(exerciseEntry: exerciseEntry, currentSetIndex: index)
    }

    private func toggleWarmup() {
        exerciseSet.setType = exerciseSet.setType == .warmup ? .normal : .warmup
    }
}
