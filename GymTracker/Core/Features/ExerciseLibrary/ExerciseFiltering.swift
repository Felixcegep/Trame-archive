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
        if !movementPatterns.isEmpty && !movementPatterns.contains(exercise.movementPattern ?? .other) { return false }
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
        + allMuscles.map(\.displayName)
    }

    private func matches(_ focus: ExerciseFocus, exercise: Exercise, allMuscles: [Muscle]) -> Bool {
        switch focus {
        case .push:
            return matchesPattern(exercise, [.horizontalPush, .verticalPush])
                || ExerciseBodyArea.chest.matches(allMuscles)
                || ExerciseBodyArea.shoulders.matches(allMuscles)
                || allMuscles.contains(where: { [.tricepLongHead, .tricepLateralHead, .tricepMedialHead].contains($0) })
        case .pull:
            return matchesPattern(exercise, [.horizontalPull, .verticalPull])
                || ExerciseBodyArea.back.matches(allMuscles)
                || allMuscles.contains(where: { [.rearDeltoid, .bicep, .brachialis, .brachioradialis, .forearms].contains($0) })
        case .legs:
            return matchesPattern(exercise, [.squat, .hinge, .lunge])
                || ExerciseBodyArea.glutes.matches(allMuscles)
                || ExerciseBodyArea.quadriceps.matches(allMuscles)
                || ExerciseBodyArea.hamstrings.matches(allMuscles)
                || ExerciseBodyArea.calves.matches(allMuscles)
                || ExerciseBodyArea.hips.matches(allMuscles)
        case .core:
            return matchesPattern(exercise, [.rotation, .antiRotation]) || ExerciseBodyArea.core.matches(allMuscles)
        case .cardio:
            return exercise.displayCategory == .cardio
        }
    }

    private func matchesPattern(_ exercise: Exercise, _ patterns: Set<MovementPattern>) -> Bool {
        guard let movementPattern = exercise.movementPattern else { return false }
        return patterns.contains(movementPattern)
    }
}

extension Exercise {
    var allMuscles: [Muscle] {
        primaryMuscles + (secondaryMuscles ?? [])
    }
}

struct ExerciseFilterControls: View {
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

            Image(systemName: AppIcon.chevronRight)
                .font(AppFont.captionBold)
                .foregroundStyle(Color.gymPrimary)
                .accessibilityHidden(true)

            Button {
                isShowingFilters = true
            } label: {
                Image(systemName: AppIcon.filters)
                    .font(AppFont.subheadlineSemibold)
                    .frame(width: 42, height: 38)
                    .background(filter.activeFilterCount > 0 ? Color.gymPrimarySurface : Color.gymCard)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if filter.activeFilterCount > 0 {
                            Text("\(filter.activeFilterCount)")
                                .font(AppFont.caption2Bold)
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Color.gymPrimary)
                                .clipShape(Circle())
                                .offset(x: 5, y: -5)
                        }
                    }
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
                .foregroundStyle(isSelected ? .white : Color.gymText)
                .padding(.horizontal, Spacing.m)
                .frame(height: 38)
                .background(isSelected ? Color.gymPrimary : Color.gymCard)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.gymText.opacity(0.08), lineWidth: 1)
                }
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
                    .tint(Color.gymPrimary)
                    .padding(Spacing.l)
                    .background {
                        RoundedRectangle(cornerRadius: Radius.large)
                            .fill(Color.gymCard)
                            .stroke(Color.gymText.opacity(0.08), lineWidth: 1)
                    }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .background(Color.gymBackground)
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
                    .padding(.vertical, Spacing.m)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.gymPrimary)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            .background(.bar)
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
                .foregroundStyle(Color.gymSubduedText)
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
                .foregroundStyle(isSelected ? .white : Color.gymText)
                .padding(.horizontal, Spacing.m)
                .frame(height: 36)
                .background(isSelected ? Color.gymPrimary : Color.gymCard)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.gymText.opacity(0.08), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

