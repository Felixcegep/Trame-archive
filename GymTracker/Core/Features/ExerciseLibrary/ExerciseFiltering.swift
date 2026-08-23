import SwiftUI

enum ExerciseFocus: String, CaseIterable, Identifiable {
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
    case core = "Core"
    case cardio = "Cardio"

    var id: Self { self }
}

enum ExerciseBodyArea: String, CaseIterable, Identifiable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case core = "Core"
    case glutes = "Glutes"
    case quadriceps = "Quadriceps"
    case hamstrings = "Hamstrings"
    case calves = "Calves"
    case hips = "Hips"

    var id: Self { self }

    func matches(_ muscles: [Muscle]) -> Bool {
        muscles.contains { musclesForArea.contains($0) }
    }

    private var musclesForArea: Set<Muscle> {
        switch self {
        case .chest:
            [.upperChest, .middleChest, .lowerChest]
        case .back:
            [.latissimusDorsi, .trapezius, .rhomboids, .teresMajor, .erectorSpinae]
        case .shoulders:
            [.frontDeltoid, .lateralDeltoid, .rearDeltoid]
        case .arms:
            [.bicep, .brachialis, .brachioradialis, .tricepLongHead, .tricepLateralHead, .tricepMedialHead, .forearms]
        case .core:
            [.rectusAbdominis, .obliques, .transverseAbdominis]
        case .glutes:
            [.gluteMaximus, .gluteMedius, .gluteMinimus]
        case .quadriceps:
            [.quadriceps]
        case .hamstrings:
            [.hamstrings]
        case .calves:
            [.calves, .tibialisAnterior]
        case .hips:
            [.adductors, .abductors]
        }
    }
}

struct ExerciseFilterState: Equatable {
    var focus: ExerciseFocus?
    var bodyAreas: Set<ExerciseBodyArea> = []
    var movementPatterns: Set<MovementPattern> = []
    var mechanics: Set<ExerciseMechanics> = []
    var forceTypes: Set<ForceType> = []
    var laterality: Set<Laterality> = []
    var equipment: EquipmentType?
    var category: ExerciseCategory?
    var difficulty: Difficulty?
    var tracking: TrackingType?
    var favoritesOnly = false

    var activeFilterCount: Int {
        [
            focus != nil,
            !bodyAreas.isEmpty,
            !movementPatterns.isEmpty,
            !mechanics.isEmpty,
            !forceTypes.isEmpty,
            !laterality.isEmpty,
            equipment != nil,
            category != nil,
            difficulty != nil,
            tracking != nil,
            favoritesOnly
        ]
        .filter(\.self)
        .count
    }

    mutating func clear() {
        self = ExerciseFilterState()
    }

    func matches(_ exercise: Exercise, searchText: String) -> Bool {
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let equipment, exercise.equipmentType != equipment { return false }
        if let category, exercise.displayCategory != category { return false }
        if let difficulty, exercise.displayDifficulty != difficulty { return false }
        if let tracking, exercise.trackingType != tracking { return false }
        if favoritesOnly && !exercise.isFavorite { return false }

        let needsMuscles = !normalizedSearch.isEmpty || focus != nil || !bodyAreas.isEmpty
        let allMuscles = needsMuscles ? exercise.allMuscles : []

        if !normalizedSearch.isEmpty {
            let terms = searchTerms(for: exercise, allMuscles: allMuscles)
            if !SearchNormalization.matches(
                query: normalizedSearch,
                primaryName: exercise.name,
                alternateName: exercise.frenchName,
                aliases: exercise.searchAliases + terms
            ) {
                return false
            }
        }
        if let focus, !matches(focus, exercise: exercise, allMuscles: allMuscles) { return false }
        if !bodyAreas.isEmpty && !bodyAreas.contains(where: { $0.matches(allMuscles) }) { return false }
        if !movementPatterns.isEmpty && !exercise.displayMovementPatterns.contains(where: { movementPatterns.contains($0) }) { return false }
        if !mechanics.isEmpty, let exerciseMechanics = exercise.mechanics, !mechanics.contains(exerciseMechanics) { return false }
        if !mechanics.isEmpty && exercise.mechanics == nil { return false }
        if !forceTypes.isEmpty, let exerciseForceType = exercise.forceType, !forceTypes.contains(exerciseForceType) { return false }
        if !forceTypes.isEmpty && exercise.forceType == nil { return false }
        if !laterality.isEmpty && !laterality.contains(exercise.laterality) { return false }

        return true
    }

    private func searchTerms(for exercise: Exercise, allMuscles: [Muscle]) -> [String] {
        [
            exercise.name,
            exercise.displayCategory.rawValue,
            exercise.equipmentType?.rawValue ?? "",
            exercise.trackingType.rawValue,
            exercise.movementPattern?.rawValue ?? "",
            exercise.mechanics?.rawValue ?? "",
            exercise.forceType?.rawValue ?? "",
            exercise.laterality.rawValue
        ]
        + exercise.tags
        + exercise.displayMovementPatterns.map(\.rawValue)
        + allMuscles.map(\.displayName)
    }

    private static let pushPrimaryMuscles: Set<Muscle> = [
        .upperChest, .middleChest, .lowerChest,
        .frontDeltoid, .lateralDeltoid,
        .tricepLongHead, .tricepLateralHead, .tricepMedialHead
    ]

    private static let pullPrimaryMuscles: Set<Muscle> = [
        .latissimusDorsi, .trapezius, .rhomboids, .teresMajor,
        .rearDeltoid,
        .bicep, .brachialis, .brachioradialis, .forearms
    ]

    private static let legPrimaryMuscles: Set<Muscle> = [
        .quadriceps, .hamstrings, .gluteMaximus, .gluteMedius, .gluteMinimus,
        .calves, .tibialisAnterior, .adductors, .abductors
    ]

    private static let corePrimaryMuscles: Set<Muscle> = [
        .rectusAbdominis, .obliques, .transverseAbdominis
    ]

    private func matches(_ focus: ExerciseFocus, exercise: Exercise, allMuscles: [Muscle]) -> Bool {
        switch focus {
        case .cardio:
            if exercise.displayCategory == .cardio { return true }
            if exercise.tags.contains(where: { $0.caseInsensitiveCompare("cardio") == .orderedSame }) { return true }
            if exercise.equipmentType == .cardioMachine { return true }
            if exercise.trackingType == .calories { return true }
            if exercise.movementPattern == .locomotion && exercise.displayCategory != .strength { return true }
            return false

        case .push:
            if matches(.cardio, exercise: exercise, allMuscles: allMuscles) { return false }
            for pattern in exercise.displayMovementPatterns {
                switch pattern {
                case .horizontalPush, .verticalPush, .shoulderAbduction, .shoulderFlexion, .horizontalAdduction, .elbowExtension:
                    return true
                case .horizontalPull, .verticalPull, .squat, .hinge, .lunge,
                     .antiExtension, .antiRotation, .antiLateralFlexion, .rotation, .carry,
                     .spinalFlexion, .spinalExtension, .lateralFlexion, .horizontalAbduction,
                     .shoulderExtension, .elbowFlexion, .hipAbduction, .hipAdduction, .plantarFlexion, .dorsiflexion:
                    return false
                case .locomotion, .jump, .throwMovement, .olympicLift, .isometricSupport, .other:
                    break
                }
            }
            if exercise.forceType == .pull { return false }
            let primary = Set(exercise.primaryMuscles)
            let hasPush = !primary.intersection(Self.pushPrimaryMuscles).isEmpty
            let hasPull = !primary.intersection(Self.pullPrimaryMuscles).isEmpty
            let hasLegs = !primary.intersection(Self.legPrimaryMuscles).isEmpty
            if hasPush && !hasPull && !hasLegs { return true }
            if exercise.forceType == .push && hasPush && !hasLegs { return true }
            return false

        case .pull:
            if matches(.cardio, exercise: exercise, allMuscles: allMuscles) { return false }
            for pattern in exercise.displayMovementPatterns {
                switch pattern {
                case .horizontalPull, .verticalPull, .horizontalAbduction, .shoulderExtension, .elbowFlexion:
                    return true
                case .horizontalPush, .verticalPush, .squat, .lunge,
                     .antiExtension, .antiRotation, .antiLateralFlexion, .rotation, .carry,
                     .spinalFlexion, .spinalExtension, .lateralFlexion, .shoulderAbduction,
                     .shoulderFlexion, .horizontalAdduction, .elbowExtension, .hipAbduction, .hipAdduction:
                    return false
                case .hinge, .locomotion, .jump, .throwMovement, .olympicLift, .isometricSupport, .plantarFlexion, .dorsiflexion, .other:
                    break
                }
            }
            if exercise.forceType == .push { return false }
            let primary = Set(exercise.primaryMuscles)
            let hasPull = !primary.intersection(Self.pullPrimaryMuscles).isEmpty
            let hasPush = !primary.intersection(Self.pushPrimaryMuscles).isEmpty
            let hasLegs = !primary.intersection(Self.legPrimaryMuscles).isEmpty
            if hasPull && !hasPush && !hasLegs { return true }
            if exercise.forceType == .pull && hasPull && !hasLegs { return true }
            return false

        case .legs:
            if matches(.cardio, exercise: exercise, allMuscles: allMuscles) { return false }
            for pattern in exercise.displayMovementPatterns {
                switch pattern {
                case .squat, .hinge, .lunge, .hipAbduction, .hipAdduction, .plantarFlexion, .dorsiflexion, .jump:
                    return true
                case .horizontalPush, .horizontalPull, .verticalPull, .shoulderAbduction, .shoulderFlexion, .shoulderExtension, .horizontalAdduction, .horizontalAbduction, .elbowFlexion, .elbowExtension:
                    return false
                case .verticalPush:
                    let primary = Set(exercise.primaryMuscles)
                    if !primary.intersection(Self.pushPrimaryMuscles).isEmpty && primary.intersection(Self.legPrimaryMuscles).isEmpty {
                        return false
                    }
                case .antiExtension, .antiRotation, .antiLateralFlexion, .rotation, .locomotion, .carry, .spinalFlexion, .spinalExtension, .lateralFlexion, .throwMovement, .olympicLift, .isometricSupport, .other:
                    break
                }
            }
            let primary = Set(exercise.primaryMuscles)
            return !primary.intersection(Self.legPrimaryMuscles).isEmpty

        case .core:
            if matches(.cardio, exercise: exercise, allMuscles: allMuscles) { return false }
            for pattern in exercise.displayMovementPatterns {
                switch pattern {
                case .antiExtension, .antiRotation, .antiLateralFlexion, .rotation, .spinalFlexion, .spinalExtension, .lateralFlexion:
                    return true
                case .horizontalPush, .horizontalPull, .verticalPush, .verticalPull, .squat, .lunge,
                     .shoulderAbduction, .shoulderFlexion, .shoulderExtension, .horizontalAdduction, .horizontalAbduction,
                     .elbowFlexion, .elbowExtension, .hipAbduction, .hipAdduction, .plantarFlexion, .dorsiflexion:
                    return false
                case .hinge, .locomotion, .carry, .jump, .throwMovement, .olympicLift, .isometricSupport, .other:
                    break
                }
            }
            let primary = Set(exercise.primaryMuscles)
            let hasCore = !primary.intersection(Self.corePrimaryMuscles).isEmpty
            let hasPush = !primary.intersection(Self.pushPrimaryMuscles).isEmpty
            let hasPull = !primary.intersection(Self.pullPrimaryMuscles).isEmpty
            let hasLegs = !primary.intersection(Self.legPrimaryMuscles).isEmpty
            return hasCore && !hasPush && !hasPull && !hasLegs
        }
    }
}

extension Exercise {
    var allMuscles: [Muscle] {
        primaryMuscles + (secondaryMuscles ?? [])
    }
}

struct ExerciseFilterControls: View {
    @Environment(\.dismissSearch) private var dismissSearch

    @Binding var filter: ExerciseFilterState
    let resultCount: Int

    @State private var isShowingFilters = false

    var body: some View {
        HStack(spacing: Spacing.s) {
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.s) {
                    focusButton(title: "All", focus: nil)

                    ForEach(ExerciseFocus.allCases) { focus in
                        focusButton(title: focus.rawValue, focus: focus)
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
            .scrollIndicators(.hidden)

            Button {
                dismissSearch()
                isShowingFilters = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text("REFINE")
                        .font(AppFont.eyebrow)
                        .tracking(0.6)

                    if filter.activeFilterCount > 0 {
                        Text(filter.activeFilterCount.formatted())
                            .font(AppFont.micro)
                            .monospacedDigit()
                    }
                }
                .foregroundStyle(Color.trameText)
                .padding(.horizontal, Spacing.s)
                .frame(minHeight: ComponentSize.minimumTouchTarget)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(filter.activeFilterCount > 0 ? Color.trameStrength : Color.trameSeparator)
                        .frame(height: filter.activeFilterCount > 0 ? 2 : 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("exercise-filters-button")
            .accessibilityLabel("Filters, \(filter.activeFilterCount) active")
        }
        .sheet(isPresented: $isShowingFilters) {
            NavigationStack {
                ExerciseFiltersSheet(filter: $filter, resultCount: resultCount)
            }
            .presentationDetents([.large])
        }
    }

    private func focusButton(title: String, focus: ExerciseFocus?) -> some View {
        let isSelected = filter.focus == focus

        return Button {
            filter.focus = focus
        } label: {
            Text(LocalizedStringKey(title))
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(isSelected ? Color.trameText : Color.trameSubdued)
                .padding(.horizontal, Spacing.s)
                .frame(minHeight: ComponentSize.minimumTouchTarget)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isSelected ? Color.trameStrength : Color.clear)
                        .frame(height: 2)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("exercise-focus-\(focus?.rawValue ?? "All")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ExerciseFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: ExerciseFilterState
    let resultCount: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                singleChipSection(
                    title: "Focus",
                    values: ExerciseFocus.allCases,
                    label: \.rawValue,
                    selection: $filter.focus
                )

                multiChipSection(
                    title: "Body Area",
                    values: ExerciseBodyArea.allCases,
                    label: \.rawValue,
                    selection: $filter.bodyAreas
                )

                singleChipSection(
                    title: "Equipment",
                    values: EquipmentType.allCases,
                    label: \.rawValue,
                    selection: $filter.equipment
                )

                multiChipSection(
                    title: "Movement Pattern",
                    values: MovementPattern.allCases,
                    label: \.rawValue,
                    selection: $filter.movementPatterns
                )

                multiChipSection(
                    title: "Mechanics",
                    values: ExerciseMechanics.allCases,
                    label: \.rawValue,
                    selection: $filter.mechanics
                )

                multiChipSection(
                    title: "Force",
                    values: ForceType.allCases,
                    label: \.rawValue,
                    selection: $filter.forceTypes
                )

                multiChipSection(
                    title: "Laterality",
                    values: Laterality.allCases,
                    label: \.rawValue,
                    selection: $filter.laterality
                )

                singleChipSection(
                    title: "Category",
                    values: ExerciseCategory.allCases,
                    label: \.rawValue,
                    selection: $filter.category
                )

                singleChipSection(
                    title: "Difficulty",
                    values: Difficulty.allCases,
                    label: \.rawValue,
                    selection: $filter.difficulty
                )

                singleChipSection(
                    title: "Tracking",
                    values: TrackingType.allCases,
                    label: \.rawValue,
                    selection: $filter.tracking
                )

                Toggle("Favorites only", isOn: $filter.favoritesOnly)
                    .font(AppFont.bodyMedium)
                    .tint(Color.trameStrength)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.trameSeparator)
                            .frame(height: 1)
                    }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .background(Color.trameCanvas)
        .navigationTitle("Filters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Clear filters") {
                    filter.clear()
                }
                .disabled(filter.activeFilterCount == 0)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                dismiss()
            } label: {
                Text("Show \(resultCount) exercises")
                    .font(AppFont.subheadlineSemibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.tramePrimaryAction)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            .background(Color.trameCanvas)
        }
    }

    private func singleChipSection<Value: Hashable>(
        title: String,
        values: [Value],
        label: KeyPath<Value, String>,
        selection: Binding<Value?>
    ) -> some View {
        chipSection(title: title) {
            ForEach(values, id: \.self) { value in
                FilterChip(
                    title: value[keyPath: label],
                    isSelected: selection.wrappedValue == value
                ) {
                    selection.wrappedValue = selection.wrappedValue == value ? nil : value
                }
            }
        }
    }

    private func multiChipSection<Value: Hashable>(
        title: String,
        values: [Value],
        label: KeyPath<Value, String>,
        selection: Binding<Set<Value>>
    ) -> some View {
        chipSection(title: title) {
            ForEach(values, id: \.self) { value in
                FilterChip(
                    title: value[keyPath: label],
                    isSelected: selection.wrappedValue.contains(value)
                ) {
                    if selection.wrappedValue.contains(value) {
                        selection.wrappedValue.remove(value)
                    } else {
                        selection.wrappedValue.insert(value)
                    }
                }
            }
        }
    }

    private func chipSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title.uppercased())
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.trameSubdued)
            ChipFlowLayout(spacing: Spacing.s) {
                content()
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(LocalizedStringKey(title))
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(isSelected ? Color.trameText : Color.trameSubdued)
                .padding(.horizontal, Spacing.s)
                .frame(minHeight: ComponentSize.minimumTouchTarget)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isSelected ? Color.trameStrength : Color.trameSeparator)
                        .frame(height: isSelected ? 2 : 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
