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
    @State private var countdownEndDate: Date?
    @State private var pausedCountdownRemaining: TimeInterval?
    @State private var countdownFinished = false

    private var trackingType: TrackingType {
        exerciseEntry.trackingTypeSnapshot
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
                if trackingType.usesCalories { caloriesField }

                doneButton
                rowMenu
            }

            if trackingType.usesDuration, !exerciseSet.done {
                durationCountdownControls
            }

            if let completionValidationMessage {
                Text(completionValidationMessage)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymAccent)
                    .padding(.leading, 45)
                    .accessibilityLabel(completionValidationMessage)
            }

            if let previousSet, !exerciseSet.done {
                Button {
                    viewModel.applyPreviousPerformance(to: exerciseSet, in: exerciseEntry, index: index)
                } label: {
                    Text("Use last time: \(previousSetText(previousSet))")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymPrimary)
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
                        .foregroundStyle(Color.gymSubduedText)
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
        .sensoryFeedback(.success, trigger: countdownFinished) { _, newValue in
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
        .onAppear {
            synchronizeIncompleteSetUnits()
            prefillPrescribedDurationIfNeeded()
        }
        .task(id: countdownEndDate) {
            guard let countdownEndDate else { return }
            let delay = max(0, countdownEndDate.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, self.countdownEndDate == countdownEndDate else { return }
            self.countdownEndDate = nil
            pausedCountdownRemaining = 0
            countdownFinished = true
        }
    }

    private var repsField: some View {
        numberField("Reps", text: Binding(
            get: { exerciseSet.repetitions == 0 ? "" : Formatters.formatFloat(exerciseSet.repetitions) },
            set: {
                if let value = Float($0) {
                    exerciseSet.repetitions = value
                    markUserOverride()
                } else if $0.isEmpty {
                    exerciseSet.repetitions = 0
                    markUserOverride()
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
                        markUserOverride()
                    } else if $0.isEmpty {
                        exerciseSet.weight = 0
                        markUserOverride()
                    }
                    viewModel.persistChanges()
                }
            ), prompt: Text(previousSet.map { Formatters.formatFloat(displayWeight(for: $0)) } ?? "0"))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(AppFont.titleSmallSemiboldMonospaced)
            .focused(focusedInput, equals: setFocus)
            .accessibilityIdentifier("weight-field-\(exerciseEntry.exercise.name)-\(index)")
            .disabled(isCompletedAndLocked)

        }
        .frame(maxWidth: .infinity)
        .padding(.leading, Spacing.xs)
        .frame(minHeight: 44)
        .background(Color.gymCard.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .stroke(Color.gymBorder, lineWidth: 1)
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
        numberFieldWithUnit("Seconds", unit: "sec", text: Binding(
                get: {
                    if (exerciseSet.duration ?? 0) == 0 { return "" }
                    return exerciseSet.duration.map { String(Int($0)) } ?? ""
                },
            set: {
                exerciseSet.duration = $0.isEmpty ? nil : TimeInterval($0)
                markUserOverride()
                if (exerciseSet.duration ?? 0) > 0 {
                    completionValidationMessage = nil
                }
                viewModel.persistChanges()
            }
        ), focusID: setFocus, prompt: previousSet?.duration.map { String(Int($0)) })
        .accessibilityIdentifier("duration-field-\(exerciseEntry.exercise.name)-\(index)")
        .disabled(isCompletedAndLocked || countdownEndDate != nil)
    }

    private var caloriesField: some View {
        numberFieldWithUnit("Calories", unit: "cal", text: Binding(
            get: {
                guard let calories = exerciseSet.calories, calories > 0 else { return "" }
                return Formatters.formatFloat(Float(calories))
            },
            set: {
                exerciseSet.calories = $0.isEmpty ? nil : Double($0)
                markUserOverride()
                if (exerciseSet.calories ?? 0) > 0 {
                    completionValidationMessage = nil
                }
                viewModel.persistChanges()
            }
        ), focusID: setFocus, prompt: previousSet?.calories.map { Formatters.formatFloat(Float($0)) })
        .accessibilityIdentifier("calories-field-\(exerciseEntry.exercise.name)-\(index)")
        .disabled(isCompletedAndLocked)
    }

    private var durationCountdownControls: some View {
        Group {
            if countdownFinished {
                countdownStrip(surface: Color.gymMutedSurface) {
                    Image(systemName: AppIcon.checkmarkCircle)
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.gymSecondary)

                    Text("Time complete")
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.gymSecondary)

                    Spacer(minLength: 0)

                    countdownControlButton(
                        AppIcon.reset,
                        label: "Restart timer",
                        tint: Color.gymSecondary,
                        action: startCountdown
                    )
                }
            } else if let countdownEndDate {
                countdownStrip(surface: Color.gymPrimarySurface) {
                    Image(systemName: AppIcon.timer)
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.gymPrimary)

                    Text(timerInterval: Date.now...max(Date.now, countdownEndDate), countsDown: true)
                        .font(AppFont.headlineMonospaced)
                        .foregroundStyle(Color.gymPrimary)

                    Spacer(minLength: 0)

                    countdownControlButton(
                        AppIcon.pause,
                        label: "Pause timer",
                        tint: Color.gymPrimary,
                        action: pauseCountdown
                    )
                    countdownControlButton(
                        AppIcon.reset,
                        label: "Reset timer",
                        tint: Color.gymPrimary,
                        action: resetCountdown
                    )
                }
            } else if let pausedCountdownRemaining, pausedCountdownRemaining > 0 {
                countdownStrip(surface: Color.gymAccentSurface) {
                    Image(systemName: AppIcon.timer)
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.gymAccent)

                    Text(formatCountdown(pausedCountdownRemaining))
                        .font(AppFont.headlineMonospaced)
                        .foregroundStyle(Color.gymAccent)

                    Text("Paused")
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)

                    Spacer(minLength: 0)

                    countdownControlButton(
                        AppIcon.play,
                        label: "Resume timer",
                        tint: Color.gymAccent,
                        action: resumeCountdown
                    )
                    countdownControlButton(
                        AppIcon.reset,
                        label: "Reset timer",
                        tint: Color.gymAccent,
                        action: resetCountdown
                    )
                }
            } else {
                Button(action: startCountdown) {
                    Label(
                        countdownTargetSeconds > 0 ? "Start \(countdownTargetSeconds) sec timer" : "Start timer",
                        systemImage: AppIcon.play
                    )
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymPrimary)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    .background(Color.gymPrimarySurface, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("start-countdown-\(exerciseEntry.exercise.name)-\(index)")
            }
        }
        .padding(.leading, 45)
        .accessibilityElement(children: .contain)
    }

    private func countdownStrip(surface: Color, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: Spacing.s) {
            content()
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs + Spacing.xxs)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
    }

    private func countdownControlButton(
        _ icon: String,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(AppFont.captionBold)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Color.gymCard, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }

    private var distanceField: some View {
        numberField("Distance", text: Binding(
            get: {
                guard let distance = exerciseSet.distance, distance > 0 else { return "" }
                return Formatters.formatFloat(distance)
            },
            set: {
                exerciseSet.distance = $0.isEmpty ? nil : Float($0)
                markUserOverride()
                viewModel.persistChanges()
            }
        ), focusID: setFocus, prompt: previousSet.map { Formatters.formatFloat(displayDistance(for: $0)) })
        .disabled(isCompletedAndLocked)
    }

    private var doneButton: some View {
        Button(action: handleCompletionButton) {
            Image(systemName: exerciseSet.done ? AppIcon.checkmark : AppIcon.circle)
                .font(AppFont.subheadlineBold)
                .foregroundStyle(exerciseSet.done ? .white : Color.gymPrimary)
                .frame(width: 28, height: 28)
                .background(exerciseSet.done ? Color.gymSecondary : Color.gymPrimary.opacity(0.14))
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
            return Color.gymSecondarySurface
        }

        return isCurrentSet ? Color.gymCurrentSetSurface : Color.gymRowSurface
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
        return exerciseSet.done ? Color.gymSecondary : Color.gymText
    }

    private var chipBackground: Color {
        exerciseSet.setType.accentColor?.opacity(0.14) ?? .clear
    }

    private var rowMenu: some View {
        Group {
            if exerciseSet.done {
                Button {
                    editingCompletedSetID = isCompletedAndLocked ? exerciseSet.persistentModelID : nil
                } label: {
                    Image(systemName: isCompletedAndLocked ? AppIcon.edit : AppIcon.checkmark)
                    .font(AppFont.subheadlineBold)
                    .foregroundStyle(isCompletedAndLocked ? Color.gymPrimary : Color.gymSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        (isCompletedAndLocked ? Color.gymPrimary : Color.gymSecondary).opacity(0.1),
                        in: Circle()
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isCompletedAndLocked ? "Edit completed set" : "Finish editing completed set")
                .accessibilityHint("The completion checkmark marks this set incomplete")
                .accessibilityIdentifier("edit-completed-set-\(exerciseEntry.exercise.name)-\(index)")
            } else {
                Menu {
                    if exerciseEntry.exercise.supportsPlateCalculator {
                        Button {
                            isShowingPlateCalculator = true
                        } label: {
                            Label("Plate calculator", systemImage: AppIcon.plateCalculator)
                        }
                        .accessibilityIdentifier("plate-calculator-\(exerciseEntry.exercise.name)")
                    }

                    Button {
                        isShowingSetDetails = true
                    } label: {
                        Label("Set details", systemImage: AppIcon.ellipsis)
                    }
                } label: {
                    Image(systemName: AppIcon.ellipsis)
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)
                        .frame(width: 20, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Set actions")
                .accessibilityIdentifier("set-menu-\(exerciseEntry.exercise.name)-\(index)")
            }
        }
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
            .background(Color.gymCard.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .stroke(Color.gymBorder, lineWidth: 1)
            }
    }

    private func numberFieldWithUnit(
        _ title: LocalizedStringKey,
        unit: LocalizedStringKey,
        text: Binding<String>,
        focusID: SetInputFocus,
        prompt: String? = nil
    ) -> some View {
        HStack(spacing: Spacing.xxs) {
            TextField(title, text: text, prompt: Text(prompt ?? "0"))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(AppFont.titleSmallSemiboldMonospaced)
                .focused(focusedInput, equals: focusID)

            Text(unit)
                .font(AppFont.captionBold)
                .foregroundStyle(Color.gymSubduedText)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.xs)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .background(Color.gymCard.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
    }

    private var countdownTargetSeconds: Int {
        max(0, Int(exerciseSet.duration ?? 0))
    }

    private func prefillPrescribedDurationIfNeeded() {
        guard trackingType.usesDuration, (exerciseSet.duration ?? 0) <= 0 else { return }
        let prescribedSeconds = exerciseEntry.prescribedRepRangeMaximum
            ?? exerciseEntry.prescribedRepRangeMinimum
            ?? 0
        guard prescribedSeconds > 0 else { return }
        exerciseSet.duration = TimeInterval(prescribedSeconds)
        viewModel.persistChanges()
    }

    private func startCountdown() {
        guard countdownTargetSeconds > 0 else {
            completionValidationMessage = "Enter seconds before starting the timer."
            focusedInput.wrappedValue = setFocus
            return
        }
        focusedInput.wrappedValue = nil
        completionValidationMessage = nil
        countdownFinished = false
        pausedCountdownRemaining = nil
        countdownEndDate = Date.now.addingTimeInterval(TimeInterval(countdownTargetSeconds))
    }

    private func pauseCountdown() {
        guard let countdownEndDate else { return }
        pausedCountdownRemaining = max(0, countdownEndDate.timeIntervalSinceNow)
        self.countdownEndDate = nil
    }

    private func resumeCountdown() {
        guard let pausedCountdownRemaining, pausedCountdownRemaining > 0 else { return }
        countdownFinished = false
        countdownEndDate = Date.now.addingTimeInterval(pausedCountdownRemaining)
        self.pausedCountdownRemaining = nil
    }

    private func resetCountdown() {
        countdownEndDate = nil
        pausedCountdownRemaining = nil
        countdownFinished = false
    }

    private func formatCountdown(_ seconds: TimeInterval) -> String {
        let roundedSeconds = Int(ceil(seconds))
        return String(format: "%d:%02d", roundedSeconds / 60, roundedSeconds % 60)
    }

    private func synchronizeIncompleteSetUnits() {
        let preferredSystem = UserDefaults.standard.unitSystem
        let preferredWeightType: WeightType = preferredSystem == .metric ? .kg : .lbs
        let preferredDistanceType: DistanceType = preferredSystem == .metric ? .kilometers : .miles
        var didChange = false

        if exerciseSet.weightType != preferredWeightType {
            exerciseSet.weight = UnitConversion.weight(
                exerciseSet.weight,
                from: exerciseSet.weightType,
                to: preferredWeightType
            )
            exerciseSet.weightType = preferredWeightType
            didChange = true
        }

        if exerciseSet.distanceType != preferredDistanceType {
            if let distance = exerciseSet.distance {
                exerciseSet.distance = UnitConversion.distance(
                    distance,
                    from: exerciseSet.distanceType,
                    to: preferredDistanceType
                )
            }
            exerciseSet.distanceType = preferredDistanceType
            didChange = true
        }

        if exerciseSet.usedMetric != preferredSystem {
            exerciseSet.usedMetric = preferredSystem
            didChange = true
        }

        if didChange {
            viewModel.persistChanges()
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

        if trackingType.usesCalories, (exerciseSet.calories ?? 0) <= 0 {
            return "Enter calories before completing this set."
        }

        if trackingType.usesDistance, (exerciseSet.distance ?? 0) <= 0 {
            return "Enter a distance before completing this set."
        }

        return "Enter a value before completing this set."
    }

    private func previousSetText(_ previousSet: PreviousSetPerformance) -> String {
        if trackingType.usesWeight {
            return "\(Formatters.formatFloat(previousSet.repetitions)) × \(Formatters.formatFloat(displayWeight(for: previousSet))) \(exerciseSet.weightType.rawValue)"
        }
        if trackingType.usesDuration {
            return "\(Int(previousSet.duration ?? 0)) sec"
        }
        if trackingType.usesCalories {
            return "\(Formatters.formatFloat(Float(previousSet.calories ?? 0))) cal"
        }
        return "\(Formatters.formatFloat(previousSet.repetitions)) reps"
    }

    private func markUserOverride() {
        guard exerciseSet.prescribedSetType != nil
            || exerciseSet.prescribedRepetitions != nil
            || exerciseSet.prescribedRepRangeMinimum != nil
            || exerciseSet.prescribedRepRangeMaximum != nil
            || exerciseSet.prescribedSuggestedLoad != nil
            || exerciseSet.prescribedCalories != nil
            || exerciseSet.prescriptionDefinitionData != nil
        else { return }
        exerciseSet.isUserOverridden = true
    }

    private func displayWeight(for previousSet: PreviousSetPerformance) -> Float {
        UnitConversion.weight(previousSet.weight, from: previousSet.weightType, to: exerciseSet.weightType)
    }

    private func displayDistance(for previousSet: PreviousSetPerformance) -> Float {
        UnitConversion.distance(previousSet.distance ?? 0, from: previousSet.distanceType, to: exerciseSet.distanceType)
    }
}
