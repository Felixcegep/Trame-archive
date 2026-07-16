import SwiftUI
import SwiftData

struct SetRowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    @Bindable var exerciseSet: ExerciseSet
    let exerciseEntry: ExerciseEntry
    let viewModel: ActiveWorkoutViewModel
    let focusedInput: FocusState<SetInputFocus?>.Binding
    @Binding var editingCompletedSetID: PersistentIdentifier?
    let onButtonPress: () -> Void
    let onSetCompleted: () -> Void
    let previousSet: PreviousSetPerformance?
    let onRemove: () -> Void

    @State private var isShowingPlateCalculator = false
    @State private var isShowingSetDetails = false
    @State private var completionValidationMessage: String?
    @State private var isShowingIncompleteConfirmation = false

    private var trackingType: TrackingType {
        exerciseEntry.exercise.trackingType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.s) {
                setTypeChip
                    .frame(width: 45, alignment: .leading)

                if trackingType.usesReps { repsField }
                if trackingType.usesWeight { weightField }
                if trackingType.usesDuration { durationField }
                if trackingType.usesDistance { distanceField }

                doneButton
                rowMenu
            }

            if let completionValidationMessage {
                Text(completionValidationMessage)
                    .font(AppFont.caption)
                    .foregroundStyle(WorkoutPalette.accent)
                    .padding(.leading, 45)
                    .accessibilityLabel(completionValidationMessage)
            }

            if let previousSet, !exerciseSet.done {
                Button {
                    viewModel.applyPreviousPerformance(to: exerciseSet, in: exerciseEntry, index: index)
                } label: {
                    Text("Use last time: \(previousSetText(previousSet))")
                        .font(AppFont.caption)
                        .foregroundStyle(WorkoutPalette.primary)
                }
                .buttonStyle(.borderless)
                .padding(.leading, 45)
                .accessibilityLabel("Use last time values for set \(index + 1)")
                .accessibilityIdentifier("use-previous-set-\(exerciseEntry.exercise.name)-\(index)")
            }

            if let rpe = exerciseSet.rpe {
                Button {
                    isShowingSetDetails = true
                } label: {
                    Text("RPE \(rpe) · \(RPEScale.meaning(for: rpe))")
                        .font(AppFont.caption)
                        .foregroundStyle(WorkoutPalette.subduedText)
                }
                .buttonStyle(.borderless)
                .padding(.leading, 45)
                .accessibilityLabel("RPE \(rpe), \(RPEScale.meaning(for: rpe))")
                .accessibilityHint("Edit set details")
                .accessibilityIdentifier("rpe-badge-\(exerciseEntry.exercise.name)-\(index)")
            }
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, 7)
        .background(rowSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .animation(reduceMotion ? nil : AppMotion.compact, value: exerciseSet.done)
        .sensoryFeedback(.success, trigger: exerciseSet.done) { _, newValue in
            newValue
        }
        .confirmationDialog(
            "Mark this set incomplete?",
            isPresented: $isShowingIncompleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Mark set incomplete", role: .destructive, action: markIncomplete)
        } message: {
            Text("Its logged values will stay in place and become editable.")
        }
    }

    private var repsField: some View {
        numberField("Reps", text: Binding(
            get: { exerciseSet.repetitions == 0 ? "" : Formatters.formatFloat(exerciseSet.repetitions) },
            set: {
                if let value = Float($0) {
                    exerciseSet.repetitions = value
                } else if $0.isEmpty {
                    exerciseSet.repetitions = 0
                }
                viewModel.persistChanges()
            }
        ), focusID: setFocus, prompt: previousSet.map { Formatters.formatFloat($0.repetitions) })
        .accessibilityIdentifier("reps-field-\(exerciseEntry.exercise.name)-\(index)")
        .disabled(isCompletedAndLocked)
    }

    private var weightField: some View {
        HStack(spacing: 0) {
            TextField("Weight", text: Binding(
                get: { exerciseSet.weight == 0 ? "" : Formatters.formatFloat(exerciseSet.weight) },
                set: {
                    if let value = Float($0) {
                        exerciseSet.weight = max(value, 0)
                    } else if $0.isEmpty {
                        exerciseSet.weight = 0
                    }
                    viewModel.persistChanges()
                }
            ), prompt: Text(previousSet.map { Formatters.formatFloat(displayWeight(for: $0)) } ?? "—"))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(AppFont.titleSmallSemiboldMonospaced)
            .focused(focusedInput, equals: setFocus)
            .accessibilityIdentifier("weight-field-\(exerciseEntry.exercise.name)-\(index)")
            .disabled(isCompletedAndLocked)

            if exerciseEntry.exercise.supportsPlateCalculator {
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
                .accessibilityIdentifier("plate-calculator-\(exerciseEntry.exercise.name)")
                .disabled(isCompletedAndLocked)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.leading, Spacing.xs)
        .frame(minHeight: 44)
        .background(WorkoutPalette.surface.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .stroke(WorkoutPalette.border, lineWidth: 1)
        }
        .sheet(isPresented: $isShowingPlateCalculator, onDismiss: {
            viewModel.persistChanges()
        }) {
            PlateCalculatorView(
                exerciseSet: exerciseSet,
                usesBarbell: exerciseEntry.exercise.equipmentType == .barbell
            )
                .presentationDetents([.height(560), .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var durationField: some View {
        numberField("Seconds", text: Binding(
                get: {
                    if (exerciseSet.duration ?? 0) == 0 { return "" }
                    return exerciseSet.duration.map { String(Int($0)) } ?? ""
                },
            set: {
                exerciseSet.duration = $0.isEmpty ? nil : TimeInterval($0)
                viewModel.persistChanges()
            }
        ), focusID: setFocus, prompt: previousSet?.duration.map { String(Int($0)) })
        .disabled(isCompletedAndLocked)
    }

    private var distanceField: some View {
        numberField("Distance", text: Binding(
            get: {
                guard let distance = exerciseSet.distance, distance > 0 else { return "" }
                return Formatters.formatFloat(distance)
            },
            set: {
                exerciseSet.distance = $0.isEmpty ? nil : Float($0)
                viewModel.persistChanges()
            }
        ), focusID: setFocus, prompt: previousSet.map { Formatters.formatFloat(displayDistance(for: $0)) })
        .disabled(isCompletedAndLocked)
    }

    private var doneButton: some View {
        Button(action: handleCompletionButton) {
            Image(systemName: exerciseSet.done ? AppIcon.checkmark : AppIcon.circle)
                .font(AppFont.subheadlineBold)
                .foregroundStyle(exerciseSet.done ? .white : WorkoutPalette.primary)
                .frame(width: 28, height: 28)
                .background(exerciseSet.done ? WorkoutPalette.secondary : WorkoutPalette.primary.opacity(0.14))
                .clipShape(Circle())
        }
        .buttonStyle(.borderless)
        .contentTransition(.symbolEffect(.replace))
        .accessibilityLabel(exerciseSet.done ? "Completed set" : "Complete set")
        .accessibilityHint(exerciseSet.done ? "Opens confirmation before marking this set incomplete." : "Marks this set complete.")
        .accessibilityIdentifier("complete-set-\(exerciseEntry.exercise.name)-\(index)")
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

    private var setTypeChip: some View {
        Menu {
            Picker("Set type", selection: Binding(
                get: { exerciseSet.setType },
                set: {
                    exerciseSet.setType = $0
                    viewModel.persistChanges()
                }
            )) {
                ForEach(SetType.allCases, id: \.self) { type in
                    Label(type.title, systemImage: type.icon).tag(type)
                }
            }
        } label: {
            Text(exerciseSet.setType.shortLabel ?? "\(index + 1)")
                .font(AppFont.subheadlineSemiboldMonospaced)
                .foregroundStyle(chipForeground)
                .frame(width: 32, height: 28)
                .background(chipBackground)
                .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Set \(index + 1), \(exerciseSet.setType.title)")
        .accessibilityHint("Change set type")
        .accessibilityIdentifier("set-type-\(exerciseEntry.exercise.name)-\(index)")
        .disabled(isCompletedAndLocked)
    }

    private var chipForeground: Color {
        if let accent = exerciseSet.setType.accentColor { return accent }
        return exerciseSet.done ? WorkoutPalette.secondary : WorkoutPalette.text
    }

    private var chipBackground: Color {
        exerciseSet.setType.accentColor?.opacity(0.14) ?? .clear
    }

    private var rowMenu: some View {
        Menu {
            if exerciseSet.done {
                Button {
                    editingCompletedSetID = isCompletedAndLocked ? exerciseSet.persistentModelID : nil
                } label: {
                    Label(isCompletedAndLocked ? "Edit completed set" : "Lock completed set", systemImage: isCompletedAndLocked ? AppIcon.edit : AppIcon.lock)
                }
                .accessibilityIdentifier("edit-completed-set-\(exerciseEntry.exercise.name)-\(index)")

                Button("Mark set incomplete", role: .destructive) {
                    isShowingIncompleteConfirmation = true
                }
            }

            Button {
                isShowingSetDetails = true
            } label: {
                Label("Set details", systemImage: AppIcon.ellipsis)
            }
        } label: {
            Image(systemName: isCompletedAndLocked ? AppIcon.lock : AppIcon.ellipsis)
                .font(AppFont.captionBold)
                .foregroundStyle(WorkoutPalette.subduedText)
                .frame(width: 20, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(isCompletedAndLocked ? "Completed set actions, locked" : "Set actions")
        .accessibilityIdentifier("set-menu-\(exerciseEntry.exercise.name)-\(index)")
        .sheet(isPresented: $isShowingSetDetails, onDismiss: {
            viewModel.persistChanges()
        }) {
            SetDetailSheet(
                index: index,
                exerciseSet: exerciseSet,
                exerciseName: exerciseEntry.exercise.name,
                onPersist: { viewModel.persistChanges() },
                onDelete: onRemove
            )
            .presentationDetents([.height(480), .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var isCompletedAndLocked: Bool {
        exerciseSet.done && editingCompletedSetID != exerciseSet.persistentModelID
    }

    private func handleCompletionButton() {
        if exerciseSet.done {
            isShowingIncompleteConfirmation = true
        } else {
            toggleDone()
        }
    }

    private func markIncomplete() {
        guard exerciseSet.done, viewModel.switchStateDoneSet(exerciseEntry, exerciseSet) else { return }
        editingCompletedSetID = exerciseSet.persistentModelID
        completionValidationMessage = nil
    }

    private var setFocus: SetInputFocus {
        SetInputFocus(
            exerciseID: exerciseEntry.persistentModelID,
            setID: exerciseSet.persistentModelID
        )
    }

    private func numberField(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        focusID: SetInputFocus,
        prompt: String? = nil
    ) -> some View {
        TextField(title, text: text, prompt: Text(prompt ?? "—"))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(AppFont.titleSmallSemiboldMonospaced)
            .focused(focusedInput, equals: focusID)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(WorkoutPalette.surface.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .stroke(WorkoutPalette.border, lineWidth: 1)
            }
    }

    private func toggleDone() {
        let shouldStartRestTimer = !exerciseSet.done
        guard !shouldStartRestTimer || viewModel.canComplete(exerciseSet, for: exerciseEntry) else {
            completionValidationMessage = validationMessage
            focusedInput.wrappedValue = setFocus
            return
        }

        completionValidationMessage = nil
        guard viewModel.switchStateDoneSet(exerciseEntry, exerciseSet) else { return }

        if shouldStartRestTimer {
            onButtonPress()
            onSetCompleted()

            // Auto-advance focus to the next incomplete set in this exercise
            if let nextSet = exerciseEntry.orderedSets.first(where: { !$0.done }) {
                focusedInput.wrappedValue = SetInputFocus(
                    exerciseID: exerciseEntry.persistentModelID,
                    setID: nextSet.persistentModelID
                )
            } else {
                focusedInput.wrappedValue = nil
            }
        }
    }

    private var validationMessage: String {
        if trackingType.usesReps, exerciseSet.repetitions <= 0 {
            return "Enter reps before completing this set."
        }

        if trackingType.usesDuration, (exerciseSet.duration ?? 0) <= 0 {
            return "Enter a duration before completing this set."
        }

        return "Enter a distance before completing this set."
    }

    private func previousSetText(_ previousSet: PreviousSetPerformance) -> String {
        if trackingType.usesWeight {
            return "\(Formatters.formatFloat(previousSet.repetitions)) × \(Formatters.formatFloat(displayWeight(for: previousSet))) \(exerciseSet.weightType.rawValue)"
        }
        if trackingType.usesDuration {
            return "\(Int(previousSet.duration ?? 0)) sec"
        }
        return "\(Formatters.formatFloat(previousSet.repetitions)) reps"
    }

    private func displayWeight(for previousSet: PreviousSetPerformance) -> Float {
        UnitConversion.weight(previousSet.weight, from: previousSet.weightType, to: exerciseSet.weightType)
    }

    private func displayDistance(for previousSet: PreviousSetPerformance) -> Float {
        UnitConversion.distance(previousSet.distance ?? 0, from: previousSet.distanceType, to: exerciseSet.distanceType)
    }
}
