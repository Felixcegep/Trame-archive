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

    private var trackingType: TrackingType {
        exerciseEntry.exercice.trackingType
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(exerciseSet.done ? WorkoutPalette.secondary : WorkoutPalette.text)
                .frame(width: 45, alignment: .leading)

            if trackingType.usesReps { repsField }
            if trackingType.usesWeight { weightField }
            if trackingType.usesDuration { durationField }
            if trackingType.usesDistance { distanceField }

            doneButton
            rowMenu
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(rowSurface)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var repsField: some View {
        numberField("Reps", text: Binding(
            get: { cleanNumber(exerciseSet.repetition) },
            set: { if let value = Float($0) { exerciseSet.repetition = value } }
        ))
    }

    private var weightField: some View {
        numberField("Weight", text: Binding(
            get: { cleanNumber(exerciseSet.weight) },
            set: { if let value = Float($0) { exerciseSet.weight = value } }
        ))
    }

    private var durationField: some View {
        numberField("Seconds", text: Binding(
            get: { exerciseSet.duration.map { String(Int($0)) } ?? "" },
            set: { exerciseSet.duration = $0.isEmpty ? nil : TimeInterval($0) }
        ))
    }

    private var distanceField: some View {
        numberField("Distance", text: Binding(
            get: { exerciseSet.distance.map(cleanNumber) ?? "" },
            set: { exerciseSet.distance = $0.isEmpty ? nil : Float($0) }
        ))
    }

    private var doneButton: some View {
        Button(action: toggleDone) {
            Image(systemName: exerciseSet.done ? "checkmark" : "circle")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(exerciseSet.done ? .white : WorkoutPalette.primary)
                .frame(width: 28, height: 28)
                .background(exerciseSet.done ? WorkoutPalette.secondary : WorkoutPalette.primary.opacity(0.14))
                .clipShape(Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(exerciseSet.done ? "Mark set incomplete" : "Complete set")
    }

    private var isCurrentSet: Bool {
        exerciseEntry.sets.first(where: { !$0.done })?.persistentModelID == exerciseSet.persistentModelID
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
                Label("Copy previous values", systemImage: "doc.on.doc")
            }
            .disabled(index == 0)

            Button(action: toggleWarmup) {
                Label(exerciseSet.setType == .warmup ? "Mark normal" : "Mark warmup", systemImage: "flame")
            }

            Button(role: .destructive, action: onRemove) {
                Label("Delete set", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption.weight(.bold))
                .foregroundStyle(WorkoutPalette.subduedText)
                .frame(width: 20, height: 28)
        }
        .buttonStyle(.borderless)
    }

    private func numberField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.subheadline.monospacedDigit().weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    private func cleanNumber(_ value: Float) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }
}
