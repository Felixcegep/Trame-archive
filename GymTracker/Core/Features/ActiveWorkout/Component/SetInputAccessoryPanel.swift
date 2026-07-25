import SwiftUI
import SwiftData

/// The set-entry panel that sits between the workout list and the custom
/// keypad while a value is being edited.
///
/// It replaces the old keyboard toolbar, which could only offer previous/next/
/// copy/done. Keeping every value of the set on screen at once — plus the
/// increments and per-set actions that used to hide in the row's `...` menu —
/// means an exercise can be logged without the keypad ever dismissing.
struct SetInputAccessoryPanel: View {
    let viewModel: ActiveWorkoutViewModel
    let coordinator: SetInputCoordinator
    let unitSystem: UnitSystem
    /// Invoked after a set is completed so the owner can start rest and advance
    /// the disclosure, exactly as the row's own completion button does.
    let onSetCompleted: (ExerciseEntry) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isShowingPlateCalculator = false
    @State private var validationMessage: String?

    private var models: (exercise: ExerciseEntry, set: ExerciseSet)? {
        viewModel.models(for: coordinator.focus)
    }

    var body: some View {
        if let models {
            content(exercise: models.exercise, set: models.set)
        }
    }

    private func content(exercise: ExerciseEntry, set: ExerciseSet) -> some View {
        VStack(spacing: Spacing.m) {
            valueRow(exercise: exercise, set: set)

            if let validationMessage {
                Text(validationMessage)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(validationMessage)
            }

            chipRow(exercise: exercise, set: set)

            footer(exercise: exercise, set: set)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.m)
        .padding(.bottom, Spacing.m)
        .background(Color.gymCard)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: Radius.card,
            topTrailingRadius: Radius.card,
            style: .continuous
        ))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.gymBorder)
                .frame(height: 1)
        }
        .shadow(color: Color.gymText.opacity(0.03), radius: 6, y: -2)
        .animation(reduceMotion ? nil : AppMotion.compact, value: coordinator.focus)
        .onChange(of: coordinator.focus) { _, _ in validationMessage = nil }
        .sheet(isPresented: $isShowingPlateCalculator, onDismiss: {
            viewModel.persistChanges()
        }) {
            PlateCalculatorView(
                exerciseSet: set,
                usesBarbell: exercise.exercise.equipmentType == .barbell
            )
            .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(560), .large])
            .presentationDragIndicator(.visible)
        }
        .accessibilityIdentifier("set-input-panel")
    }

    // MARK: - Values

    private func valueRow(exercise: ExerciseEntry, set: ExerciseSet) -> some View {
        let fields = SetInputCoordinator.inputFields(for: exercise.trackingTypeSnapshot)

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.m) {
                ForEach(fields, id: \.self) { field in
                    valuePill(field: field, exercise: exercise, set: set)
                }
            }
            VStack(spacing: Spacing.s) {
                ForEach(fields, id: \.self) { field in
                    valuePill(field: field, exercise: exercise, set: set)
                }
            }
        }
    }

    private func valuePill(
        field: SetInputFocus.Field,
        exercise: ExerciseEntry,
        set: ExerciseSet
    ) -> some View {
        let isActive = coordinator.focus?.field == field

        return HStack(spacing: Spacing.s) {
            Button {
                coordinator.focusField(field)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                    Text(displayValue(field: field, set: set))
                        .font(AppFont.titleSmallSemiboldMonospaced)
                        .foregroundStyle(Color.gymText)
                    Text(unitLabel(field: field, set: set))
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, Spacing.s)
                .background(isActive ? Color.gymPrimarySurface : Color.gymRowSurface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .stroke(
                            isActive ? Color.gymPrimary : Color.gymBorder,
                            lineWidth: isActive ? 1.5 : 1
                        )
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.gymPress)
            .accessibilityLabel("\(fieldName(field)) \(displayValue(field: field, set: set)) \(unitLabel(field: field, set: set))")
            .accessibilityHint(isActive ? "Currently editing" : "Edit \(fieldName(field))")
            .accessibilityAddTraits(isActive ? [.isSelected] : [])
            .accessibilityIdentifier("panel-value-\(fieldName(field))")

            steppers(field: field, exercise: exercise, set: set)
        }
    }

    @ViewBuilder
    private func steppers(
        field: SetInputFocus.Field,
        exercise: ExerciseEntry,
        set: ExerciseSet
    ) -> some View {
        switch field {
        case .weight:
            VStack(spacing: Spacing.xs) {
                stepperRow(step: fineWeightStep(for: set), field: field, exercise: exercise, set: set)
                stepperRow(step: coarseWeightStep(for: exercise, set: set), field: field, exercise: exercise, set: set)
            }
        case .repetitions, .duration, .distance, .calories:
            stepperRow(step: 1, field: field, exercise: exercise, set: set)
        }
    }

    private func stepperRow(
        step: Double,
        field: SetInputFocus.Field,
        exercise: ExerciseEntry,
        set: ExerciseSet
    ) -> some View {
        HStack(spacing: Spacing.xxs) {
            stepperButton(systemImage: AppIcon.minus, step: -step, field: field, set: set)
            Text(Formatters.formatFloat(Float(step)))
                .font(AppFont.caption2Bold)
                .foregroundStyle(Color.gymSubduedText)
                .frame(minWidth: 22)
                .accessibilityHidden(true)
            stepperButton(systemImage: AppIcon.plus, step: step, field: field, set: set)
        }
    }

    private func stepperButton(
        systemImage: String,
        step: Double,
        field: SetInputFocus.Field,
        set: ExerciseSet
    ) -> some View {
        Button {
            adjust(field: field, by: step, set: set)
        } label: {
            Image(systemName: systemImage)
                .font(AppFont.caption2Bold)
                .foregroundStyle(Color.gymPrimary)
                .frame(width: 32, height: 32)
                .background(Color.gymPrimary.opacity(0.12), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.gymPress)
        .accessibilityLabel(step < 0
            ? "Decrease \(fieldName(field)) by \(Formatters.formatFloat(Float(abs(step))))"
            : "Increase \(fieldName(field)) by \(Formatters.formatFloat(Float(step)))")
    }

    // MARK: - Chips

    private func chipRow(exercise: ExerciseEntry, set: ExerciseSet) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.s) {
                setTypeChip(set: set)

                if exercise.exercise.supportsPlateCalculator {
                    chip(title: "Plates", systemImage: AppIcon.plateCalculator) {
                        isShowingPlateCalculator = true
                    }
                }

                if exercise.trackingTypeSnapshot.usesWeight {
                    chip(title: set.weightType == .kg ? "KG" : "LB", systemImage: AppIcon.workout) {
                        toggleWeightType(on: set)
                    }
                }

                if viewModel.canCopyValuesForFocusedSet(coordinator.focus) {
                    chip(title: "Last set", systemImage: AppIcon.copy) {
                        viewModel.copyValuesForFocusedSet(coordinator.focus)
                    }
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollIndicators(.hidden)
    }

    private func setTypeChip(set: ExerciseSet) -> some View {
        Menu {
            Picker("Set type", selection: Binding(
                get: { set.setType },
                set: {
                    set.setType = $0
                    viewModel.persistChanges()
                }
            )) {
                ForEach(SetType.allCases, id: \.self) { type in
                    Label(type.title, systemImage: type.icon).tag(type)
                }
            }
        } label: {
            chipLabel(title: set.setType.title, systemImage: set.setType.icon)
        }
        .buttonStyle(.gymPress)
        .accessibilityLabel("Set type, \(set.setType.title)")
        .accessibilityHint("Change set type")
        .accessibilityIdentifier("panel-set-type")
    }

    private func chip(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            chipLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("panel-chip-\(title.lowercased())")
    }

    private func chipLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(AppFont.footnoteMedium)
            .foregroundStyle(Color.gymText)
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: 36)
            .background(Color.gymRowSurface)
            .clipShape(Capsule())
            .overlay { Capsule().stroke(Color.gymBorder, lineWidth: 1) }
            .contentShape(Capsule())
    }

    // MARK: - Footer

    private func footer(exercise: ExerciseEntry, set: ExerciseSet) -> some View {
        HStack(spacing: Spacing.s) {
            navigationButton(systemImage: AppIcon.chevronLeft, offset: -1)
            navigationButton(systemImage: AppIcon.chevronRight, offset: 1)

            Spacer(minLength: Spacing.s)

            Button {
                confirm(exercise: exercise, set: set)
            } label: {
                Label("Complete set", systemImage: AppIcon.checkmark)
                    .font(AppFont.subheadlineBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(Color.gymSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.gymPress)
            .accessibilityLabel("Complete set")
            .accessibilityHint("Marks this set done, starts rest, and moves to the next set.")
            .accessibilityIdentifier("panel-complete-set")
        }
    }

    private func navigationButton(systemImage: String, offset: Int) -> some View {
        let isEnabled = offset < 0 ? coordinator.previousInput != nil : coordinator.nextInput != nil

        return Button {
            coordinator.moveFocus(by: offset)
        } label: {
            Image(systemName: systemImage)
                .font(AppFont.subheadlineBold)
                .foregroundStyle(isEnabled ? Color.gymPrimary : Color.gymSubtleText)
                .frame(width: 44, height: 44)
                .background(Color.gymRowSurface, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.gymPress)
        .disabled(!isEnabled)
        .accessibilityLabel(offset < 0 ? "Previous field" : "Next field")
    }

    // MARK: - Actions

    private func confirm(exercise: ExerciseEntry, set: ExerciseSet) {
        switch viewModel.completeSet(set, in: exercise) {
        case .blocked(let message, let focus):
            validationMessage = message
            coordinator.focus = focus
        case .completed(let nextFocus):
            validationMessage = nil
            onSetCompleted(exercise)
            coordinator.refreshOrder(in: viewModel.activeWorkout)
            coordinator.focus = nextFocus
        case .reopened, .failed:
            break
        }
    }

    private func adjust(field: SetInputFocus.Field, by step: Double, set: ExerciseSet) {
        switch field {
        case .repetitions:
            set.repetitions = max(0, set.repetitions + Float(step))
        case .weight:
            set.weight = max(0, set.weight + Float(step))
        case .duration:
            set.duration = max(0, (set.duration ?? 0) + step)
        case .distance:
            set.distance = max(0, (set.distance ?? 0) + Float(step))
        case .calories:
            set.calories = max(0, (set.calories ?? 0) + step)
        }
        validationMessage = nil
        viewModel.persistChanges()
    }

    private func toggleWeightType(on set: ExerciseSet) {
        let target: WeightType = set.weightType == .kg ? .lbs : .kg
        set.weight = UnitConversion.weight(set.weight, from: set.weightType, to: target)
        set.weightType = target
        viewModel.persistChanges()
    }

    // MARK: - Steps

    /// The smallest sensible nudge — a microplate in metric, the smallest common
    /// fractional plate in imperial.
    private func fineWeightStep(for set: ExerciseSet) -> Double {
        set.weightType == .kg ? 1 : 2.5
    }

    /// The jump this equipment actually makes: plate pairs for a barbell, rack
    /// steps for dumbbells, pin steps for a stack.
    private func coarseWeightStep(for exercise: ExerciseEntry, set: ExerciseSet) -> Double {
        let template = exercise.exercise
        if let increment = EquipmentLoadRounding.increment(
            equipment: template.equipmentType,
            resistance: template.resistanceType,
            isPlateLoaded: template.isPlateLoaded,
            unit: set.weightType
        ) {
            return increment
        }
        return Double(Constants.Progression.increment(for: set.weightType))
    }

    // MARK: - Formatting

    private func displayValue(field: SetInputFocus.Field, set: ExerciseSet) -> String {
        switch field {
        case .repetitions:
            return set.repetitions == 0 ? "—" : Formatters.formatFloat(set.repetitions)
        case .weight:
            return set.weight == 0 ? "—" : Formatters.formatFloat(set.weight)
        case .duration:
            return (set.duration ?? 0) == 0 ? "—" : String(Int(set.duration ?? 0))
        case .distance:
            return (set.distance ?? 0) == 0 ? "—" : Formatters.formatFloat(set.distance ?? 0)
        case .calories:
            return (set.calories ?? 0) == 0 ? "—" : Formatters.formatFloat(Float(set.calories ?? 0))
        }
    }

    private func unitLabel(field: SetInputFocus.Field, set: ExerciseSet) -> String {
        switch field {
        case .repetitions: return "rep"
        case .weight: return set.weightType.rawValue
        case .duration: return "sec"
        case .distance: return set.distanceType.rawValue
        case .calories: return "cal"
        }
    }

    private func fieldName(_ field: SetInputFocus.Field) -> String {
        switch field {
        case .repetitions: return "reps"
        case .weight: return "weight"
        case .duration: return "duration"
        case .distance: return "distance"
        case .calories: return "calories"
        }
    }
}
