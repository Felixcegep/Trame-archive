import SwiftUI
import SwiftData

struct SetRowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    @State private var isTimerRunning = false
    @State private var completedEditSnapshot: CompletedSetEditSnapshot?
    // In-progress decimal text, kept separate from the numeric model value so a
    // partially typed value (".", "0.", ",5") survives instead of being erased.
    // Cleared when focus leaves the field, which re-derives normalized display.
    @State private var weightEditingText: String?
    @State private var distanceEditingText: String?

    private var trackingType: TrackingType {
        exerciseEntry.trackingTypeSnapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            rowInputs

            if !exerciseSet.orderedComplexComponents.isEmpty {
                ComplexComponentResultsView(
                    components: exerciseSet.orderedComplexComponents,
                    onChange: {
                        exerciseSet.liftQuality = exerciseSet.orderedComplexComponents.contains(where: { $0.outcome == .missed }) ? .missed : nil
                        viewModel.persistChanges()
                    }
                )
                .padding(.leading, 45)
            }

            if let notes = exerciseSet.prescriptionNotes,
               notes.hasPrefix("Complex:") {
                Text(notes)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .padding(.leading, 45)
                    .accessibilityLabel(notes)
            }

            if isDailyMaximum, exerciseSet.done {
                Button {
                    viewModel.selectDailyMaximum(exerciseSet, in: exerciseEntry)
                } label: {
                    Label(
                        exerciseSet.isSelectedDailyMaximum ? "Daily maximum selected" : "Use as daily maximum",
                        systemImage: exerciseSet.isSelectedDailyMaximum ? AppIcon.checkmarkCircle : AppIcon.circle
                    )
                    .font(AppFont.caption)
                    .foregroundStyle(exerciseSet.isSelectedDailyMaximum ? Color.gymSecondary : Color.gymPrimary)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.borderless)
                .padding(.leading, 45)
                .accessibilityLabel(exerciseSet.isSelectedDailyMaximum ? "Selected daily maximum" : "Use this attempt as the daily maximum")
                .accessibilityHint("Derived back-off sets use the selected attempt.")
                .accessibilityIdentifier("select-daily-maximum-\(exerciseEntry.exercise.name)-\(index)")
            }

            if let tempo = exerciseSet.prescribedTempo,
               !tempo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Tempo \(tempo)")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .padding(.leading, 45)
                    .accessibilityLabel("Prescribed tempo \(tempo)")
            }

            if trackingType.usesDuration, !exerciseSet.done {
                SetDurationCountdownView(
                    index: index,
                    exerciseSet: exerciseSet,
                    exerciseEntry: exerciseEntry,
                    viewModel: viewModel,
                    focusedInput: focusedInput,
                    completionValidationMessage: $completionValidationMessage,
                    isTimerRunning: $isTimerRunning
                )
            }

            if let completionValidationMessage {
                Text(completionValidationMessage)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymAccent)
                    .padding(.leading, 45)
                    .accessibilityLabel(completionValidationMessage)
            }

            if let previousSet, !exerciseSet.done, isCurrentSet {
                Button {
                    viewModel.applyPreviousPerformance(to: exerciseSet, in: exerciseEntry, index: index)
                    focusedInput.wrappedValue = SetInputFocus(
                        exerciseID: exerciseEntry.persistentModelID,
                        setID: exerciseSet.persistentModelID,
                        field: firstInputField
                    )
                } label: {
                    Label("Use last time · \(previousSetText(previousSet))", systemImage: AppIcon.copy)
                        .font(AppFont.footnoteMedium)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .foregroundStyle(Color.gymPrimary)
                .accessibilityLabel("Use last time values for set \(index + 1)")
                .accessibilityIdentifier("copy-previous-set-\(exerciseEntry.exercise.name)-\(index)")
            }

            if let rpe = exerciseSet.rpe {
                let formattedRPE = Formatters.formatFloat(Float(rpe))
                Button {
                    isShowingSetDetails = true
                } label: {
                    Text("RPE \(formattedRPE) · \(RPEScale.meaning(for: rpe))")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
                .buttonStyle(.borderless)
                .padding(.leading, 45)
                .accessibilityLabel("RPE \(formattedRPE), \(RPEScale.meaning(for: rpe))")
                .accessibilityHint("Edit set details")
                .accessibilityIdentifier("rpe-badge-\(exerciseEntry.exercise.name)-\(index)")
            } else if let rir = exerciseSet.rir {
                Button {
                    isShowingSetDetails = true
                } label: {
                    Text("RIR \(rir) · \(RIRScale.meaning(for: rir))")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
                .buttonStyle(.borderless)
                .padding(.leading, 45)
                .accessibilityLabel("RIR \(rir), \(RIRScale.meaning(for: rir))")
                .accessibilityHint("Edit set details")
                .accessibilityIdentifier("rir-badge-\(exerciseEntry.exercise.name)-\(index)")
            }
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, 7)
        .background(rowSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .stroke(isEditingCompletedSet ? Color.gymPrimary : .clear, lineWidth: 1)
        }
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
        .onAppear {
            synchronizeIncompleteSetUnits()
            prefillPrescribedDurationIfNeeded()
        }
        .sheet(isPresented: $isShowingPlateCalculator, onDismiss: {
            viewModel.persistChanges()
        }) {
            PlateCalculatorView(
                exerciseSet: exerciseSet,
                usesBarbell: exerciseEntry.exercise.equipmentType == .barbell
            )
            .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(560), .large])
            .presentationDragIndicator(.visible)
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
            .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(480), .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var rowInputs: some View {
        if dynamicTypeSize.isAccessibilitySize {
            stackedRowInputs
        } else {
            ViewThatFits(in: .horizontal) {
                horizontalRowInputs
                stackedRowInputs
            }
        }
    }

    private var horizontalRowInputs: some View {
        HStack(spacing: Spacing.s) {
            setTypeChip
                .frame(width: 44, height: 44)

            inputFieldsHorizontal

            if !isEditingCompletedSet {
                doneButton
            }
            rowActions
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isCompletedAndLocked { beginCompletedSetEditing() }
        }
    }

    private var stackedRowInputs: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                setTypeChip
                    .frame(width: 44, height: 44)
                Text("Set \(index + 1) · \(exerciseSet.setType.title)")
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.gymSubduedText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if !isEditingCompletedSet {
                    doneButton
                }
                rowActions
            }

            inputFieldsStacked
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isCompletedAndLocked { beginCompletedSetEditing() }
        }
    }

    @ViewBuilder
    private var inputFieldsHorizontal: some View {
        if trackingType.usesReps { repsField }
        if trackingType.usesWeight { weightField }
        if trackingType.usesDuration { durationField }
        if trackingType.usesDistance { distanceField }
        if trackingType.usesCalories { caloriesField }
    }

    private var inputFieldsStacked: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.s) {
                if trackingType.usesReps { labeledField(label: "REPS", field: repsField) }
                if trackingType.usesWeight { labeledField(label: "WEIGHT", field: weightField) }
                if trackingType.usesDuration { labeledField(label: "SECONDS", field: durationField) }
                if trackingType.usesDistance { labeledField(label: "DISTANCE", field: distanceField) }
                if trackingType.usesCalories { labeledField(label: "CALORIES", field: caloriesField) }
            }
            VStack(spacing: Spacing.s) {
                if trackingType.usesReps { labeledField(label: "REPS", field: repsField) }
                if trackingType.usesWeight { labeledField(label: "WEIGHT", field: weightField) }
                if trackingType.usesDuration { labeledField(label: "SECONDS", field: durationField) }
                if trackingType.usesDistance { labeledField(label: "DISTANCE", field: distanceField) }
                if trackingType.usesCalories { labeledField(label: "CALORIES", field: caloriesField) }
            }
        }
    }

    private func labeledField<Field: View>(label: String, field: Field) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(AppFont.caption2Bold)
                .tracking(0.55)
                .foregroundStyle(Color.gymSubduedText)
            field
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        ), focusID: inputFocus(.repetitions), prompt: previousSet.map { Formatters.formatFloat($0.repetitions) })
        .accessibilityIdentifier("reps-field-\(exerciseEntry.exercise.name)-\(index)")
        .disabled(isCompletedAndLocked)
    }

    private var weightField: some View {
        HStack(spacing: 0) {
            TextField("Weight", text: weightTextBinding, prompt: Text(previousSet.map { Formatters.formatFloat(displayWeight(for: $0)) } ?? prescribedWeightPrompt))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(AppFont.titleSmallSemiboldMonospaced)
            .focused(focusedInput, equals: inputFocus(.weight))
            .onChange(of: focusedInput.wrappedValue) { _, focus in
                if focus != inputFocus(.weight) { weightEditingText = nil }
            }
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
        ), focusID: inputFocus(.duration), prompt: previousSet?.duration.map { String(Int($0)) })
        .accessibilityIdentifier("duration-field-\(exerciseEntry.exercise.name)-\(index)")
        .disabled(isCompletedAndLocked || isTimerRunning)
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
        ), focusID: inputFocus(.calories), prompt: previousSet?.calories.map { Formatters.formatFloat(Float($0)) })
        .accessibilityIdentifier("calories-field-\(exerciseEntry.exercise.name)-\(index)")
        .disabled(isCompletedAndLocked)
    }



    private var distanceField: some View {
        numberField("Distance", text: distanceTextBinding, focusID: inputFocus(.distance), prompt: previousSet.map { Formatters.formatFloat(displayDistance(for: $0)) })
        .onChange(of: focusedInput.wrappedValue) { _, focus in
            if focus != inputFocus(.distance) { distanceEditingText = nil }
        }
        .disabled(isCompletedAndLocked)
    }

    /// Locale-aware decimal binding for the weight field. Keeps in-progress text
    /// so ".", "0.", ",5" survive; commits a parsed value to the model.
    private var weightTextBinding: Binding<String> {
        Binding(
            get: {
                if let weightEditingText { return weightEditingText }
                return exerciseSet.weight == 0 ? "" : Formatters.formatFloat(exerciseSet.weight)
            },
            set: { candidate in
                guard let sanitized = DecimalParser.sanitizedEditingText(candidate) else { return }
                weightEditingText = sanitized
                if sanitized.isEmpty {
                    exerciseSet.weight = 0
                    markUserOverride()
                } else if let parsed = DecimalParser.value(from: sanitized) {
                    exerciseSet.weight = Float(max(parsed, 0))
                    markUserOverride()
                }
                viewModel.persistChanges()
            }
        )
    }

    private var distanceTextBinding: Binding<String> {
        Binding(
            get: {
                if let distanceEditingText { return distanceEditingText }
                guard let distance = exerciseSet.distance, distance > 0 else { return "" }
                return Formatters.formatFloat(distance)
            },
            set: { candidate in
                guard let sanitized = DecimalParser.sanitizedEditingText(candidate) else { return }
                distanceEditingText = sanitized
                if sanitized.isEmpty {
                    exerciseSet.distance = nil
                    markUserOverride()
                } else if let parsed = DecimalParser.value(from: sanitized) {
                    exerciseSet.distance = Float(max(parsed, 0))
                    markUserOverride()
                }
                viewModel.persistChanges()
            }
        )
    }

    private var doneButton: some View {
        Button(action: handleCompletionButton) {
            Image(systemName: exerciseSet.done ? AppIcon.checkmark : AppIcon.circle)
                .font(AppFont.subheadlineBold)
                .foregroundStyle(exerciseSet.done ? .white : Color.gymPrimary)
                .frame(width: 36, height: 36)
                .background(exerciseSet.done ? Color.gymSecondary : Color.gymPrimary.opacity(0.14))
                .clipShape(Circle())
        }
        .buttonStyle(.borderless)
        .frame(width: 44, height: 44)
        .contentTransition(.symbolEffect(.replace))
        .accessibilityLabel(exerciseSet.done ? "Completed set" : "Complete set")
        .accessibilityHint(exerciseSet.done ? "Opens confirmation before marking this set incomplete." : "Marks this set complete.")
        .accessibilityIdentifier("complete-set-\(exerciseEntry.exercise.name)-\(index)")
    }

    private var isCurrentSet: Bool {
        exerciseEntry.orderedSets.first(where: { !$0.done })?.persistentModelID == exerciseSet.persistentModelID
    }

    private var rowSurface: Color {
        if isEditingCompletedSet {
            return Color.gymPrimarySurface
        }
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

    private var isDailyMaximum: Bool {
        exerciseSet.prescribedSetType == .dailyMaximum || exerciseSet.setType == .dailyMaximum
    }

    @ViewBuilder
    private var rowActions: some View {
        if isEditingCompletedSet {
            Button("Finish") {
                finishCompletedSetEditing()
            }
            .buttonStyle(.borderedProminent)
            .font(AppFont.footnoteMedium)
            .frame(minHeight: 44)
            .accessibilityLabel("Finish editing")
            .accessibilityHint("Saves the edited values.")
            .accessibilityIdentifier("finish-editing-set-\(exerciseEntry.exercise.name)-\(index)")
        } else if exerciseSet.done {
            Button {
                beginCompletedSetEditing()
            } label: {
                Image(systemName: AppIcon.edit)
                    .font(AppFont.subheadlineBold)
                    .foregroundStyle(Color.gymPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.gymPrimary.opacity(0.1), in: Circle())
            }
            .buttonStyle(.borderless)
            .frame(width: 44, height: 44)
            .accessibilityLabel("Edit completed set")
            .accessibilityHint("Values become editable; the set stays completed.")
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

                if index > 0, focusedInput.wrappedValue == nil {
                    Button {
                        viewModel.copyPreviousSetValue(exerciseEntry: exerciseEntry, currentSetIndex: index)
                    } label: {
                        Label("Copy last set", systemImage: AppIcon.copy)
                    }
                    .accessibilityIdentifier("copy-last-set-\(exerciseEntry.exercise.name)-\(index)")
                    .accessibilityHint("Copies the values from the preceding set in this workout")
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
                    .frame(width: 36, height: 36)
                    .background(Color.gymText.opacity(0.06), in: Circle())
            }
            .buttonStyle(.borderless)
            .frame(width: 44, height: 44)
            .accessibilityLabel("Set actions")
            .accessibilityIdentifier("set-menu-\(exerciseEntry.exercise.name)-\(index)")
        }

        if isEditingCompletedSet {
            Menu {
                Button("Mark set incomplete", role: .destructive) {
                    isShowingIncompleteConfirmation = true
                }
                Button("Discard changes", role: .destructive) {
                    discardCompletedSetEditing()
                }
            } label: {
                Image(systemName: AppIcon.ellipsis)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymSubduedText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Completed set actions")
        }
    }

    private var isCompletedAndLocked: Bool {
        exerciseSet.done && editingCompletedSetID != exerciseSet.persistentModelID
    }

    private var isEditingCompletedSet: Bool {
        exerciseSet.done && editingCompletedSetID == exerciseSet.persistentModelID
    }

    private func beginCompletedSetEditing() {
        guard isCompletedAndLocked else { return }
        completedEditSnapshot = CompletedSetEditSnapshot(exerciseSet)
        editingCompletedSetID = exerciseSet.persistentModelID
        completionValidationMessage = nil
        UIAccessibility.post(notification: .announcement, argument: "Editing set \(index + 1)")
        focusedInput.wrappedValue = SetInputFocus(
            exerciseID: exerciseEntry.persistentModelID,
            setID: exerciseSet.persistentModelID,
            field: firstInputField
        )
    }

    private func finishCompletedSetEditing() {
        guard viewModel.canComplete(exerciseSet, for: exerciseEntry) else {
            completionValidationMessage = validationMessage
            return
        }
        completionValidationMessage = nil
        completedEditSnapshot = nil
        editingCompletedSetID = nil
        focusedInput.wrappedValue = nil
        viewModel.persistChanges()
    }

    private func discardCompletedSetEditing() {
        completedEditSnapshot?.restore(on: exerciseSet)
        completedEditSnapshot = nil
        editingCompletedSetID = nil
        completionValidationMessage = nil
        focusedInput.wrappedValue = nil
        viewModel.persistChanges()
    }

    private var firstInputField: SetInputFocus.Field {
        if trackingType.usesReps { return .repetitions }
        if trackingType.usesWeight { return .weight }
        if trackingType.usesDuration { return .duration }
        if trackingType.usesDistance { return .distance }
        return .calories
    }

    private func inputFocus(_ field: SetInputFocus.Field) -> SetInputFocus {
        SetInputFocus(
            exerciseID: exerciseEntry.persistentModelID,
            setID: exerciseSet.persistentModelID,
            field: field
        )
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
        completedEditSnapshot = nil
        editingCompletedSetID = nil
        completionValidationMessage = nil
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
            .frame(minWidth: 70, maxWidth: .infinity)
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
        .frame(minWidth: 70, maxWidth: .infinity)
        .frame(minHeight: 44)
        .background(Color.gymCard.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
    }



    private func prefillPrescribedDurationIfNeeded() {
        guard !exerciseSet.done,
              trackingType.usesDuration,
              (exerciseSet.duration ?? 0) <= 0 else { return }
        let prescribedSeconds = exerciseEntry.prescribedRepRangeMaximum
            ?? exerciseEntry.prescribedRepRangeMinimum
            ?? 0
        guard prescribedSeconds > 0 else { return }
        exerciseSet.duration = TimeInterval(prescribedSeconds)
        viewModel.persistChanges()
    }



    private func synchronizeIncompleteSetUnits() {
        let preferredSystem = UserDefaults.standard.unitSystem
        if WorkoutSetInputNormalizer.synchronize(exerciseSet, to: preferredSystem) {
            viewModel.persistChanges()
        }
    }

    private func toggleDone() {
        let shouldStartRestTimer = !exerciseSet.done
        guard !shouldStartRestTimer || viewModel.canComplete(exerciseSet, for: exerciseEntry) else {
            completionValidationMessage = validationMessage
            focusedInput.wrappedValue = inputFocus(firstInputField)
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
                    setID: nextSet.persistentModelID,
                    field: firstInputField
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

    private var prescribedWeightPrompt: String {
        guard let load = exerciseSet.prescribedSuggestedLoad,
              let type = exerciseSet.prescribedSuggestedLoadType else {
            return "0"
        }
        let converted = UnitConversion.weight(Float(load), from: type, to: exerciseSet.weightType)
        return Formatters.formatFloat(converted)
    }

    private func displayDistance(for previousSet: PreviousSetPerformance) -> Float {
        UnitConversion.distance(previousSet.distance ?? 0, from: previousSet.distanceType, to: exerciseSet.distanceType)
    }
}

private struct ComplexComponentResultsView: View {
    let components: [ComplexComponentResult]
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("COMPLEX")
                .font(AppFont.caption2Bold)
                .foregroundStyle(Color.gymSubduedText)

            ForEach(components, id: \.persistentModelID) { component in
                ComplexComponentResultRow(component: component, onChange: onChange)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Complex component results")
    }
}

private struct ComplexComponentResultRow: View {
    @Bindable var component: ComplexComponentResult
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(component.exerciseNameSnapshot)
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.gymText)
                Text("×\(component.prescribedRepetitions)")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }

            Spacer(minLength: Spacing.s)

            Menu {
                Button("Made") { update(.completed) }
                Button("Partial") { update(.partial) }
                Button("Missed") { update(.missed) }
                Button("Skipped") { update(.skipped) }
                Button("Clear", role: .destructive) { update(.notStarted) }
            } label: {
                Label(component.outcome.title, systemImage: icon)
                    .font(AppFont.captionBold)
                    .foregroundStyle(color)
                    .frame(minHeight: 44)
            }
            .accessibilityLabel("\(component.exerciseNameSnapshot), \(component.prescribedRepetitions) prescribed repetitions")
            .accessibilityValue(component.outcome.title)
            .accessibilityHint("Choose the component outcome")
            .accessibilityIdentifier("complex-component-\(component.orderIndex)")
        }
    }

    private var icon: String {
        switch component.outcome {
        case .notStarted: AppIcon.circle
        case .completed: AppIcon.checkmarkCircle
        case .partial: AppIcon.timer
        case .missed: AppIcon.failureCircle
        case .skipped: AppIcon.skip
        }
    }

    private var color: Color {
        switch component.outcome {
        case .completed: Color.gymSecondary
        case .missed: Color.gymDestructive
        case .notStarted, .partial, .skipped: Color.gymPrimary
        }
    }

    private func update(_ outcome: ComplexComponentOutcome) {
        component.outcome = outcome
        switch outcome {
        case .notStarted:
            component.performedRepetitions = 0
            component.liftQuality = nil
        case .completed:
            component.performedRepetitions = component.prescribedRepetitions
            component.liftQuality = .acceptable
        case .partial:
            component.performedRepetitions = max(0, component.prescribedRepetitions - 1)
            component.liftQuality = .technicallyPoor
        case .missed:
            component.performedRepetitions = 0
            component.liftQuality = .missed
        case .skipped:
            component.performedRepetitions = 0
            component.liftQuality = nil
        }
        onChange()
    }
}

private struct CompletedSetEditSnapshot {
    let repetitions: Float
    let weight: Float
    let duration: TimeInterval?
    let distance: Float?
    let calories: Double?

    init(_ set: ExerciseSet) {
        repetitions = set.repetitions
        weight = set.weight
        duration = set.duration
        distance = set.distance
        calories = set.calories
    }

    func restore(on set: ExerciseSet) {
        set.repetitions = repetitions
        set.weight = weight
        set.duration = duration
        set.distance = distance
        set.calories = calories
    }
}
