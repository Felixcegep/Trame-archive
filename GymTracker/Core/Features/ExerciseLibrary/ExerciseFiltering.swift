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
        let matchesSearch = normalizedSearch.isEmpty || searchTerms(for: exercise)
            .contains { $0.localizedCaseInsensitiveContains(normalizedSearch) }
        let matchesFocus = focus.map { matches($0, exercise: exercise) } ?? true
        let matchesBodyArea = bodyAreas.isEmpty || bodyAreas.contains { $0.matches(exercise.allMuscles) }
        let matchesMovement = movementPatterns.isEmpty || movementPatterns.contains(exercise.movementPattern ?? .other)
        let matchesEquipment = equipment == nil || exercise.equipmentType == equipment
        let matchesCategory = category == nil || exercise.displayCategory == category
        let matchesDifficulty = difficulty == nil || exercise.displayDifficulty == difficulty
        let matchesTracking = tracking == nil || exercise.trackingType == tracking
        let matchesFavorites = !favoritesOnly || exercise.isFavorite

        return matchesSearch && matchesFocus && matchesBodyArea && matchesMovement && matchesEquipment && matchesCategory && matchesDifficulty && matchesTracking && matchesFavorites
    }

    private func searchTerms(for exercise: Exercise) -> [String] {
        [
            exercise.name,
            exercise.displayCategory.rawValue,
            exercise.equipmentType?.rawValue ?? "",
            exercise.trackingType.rawValue,
            exercise.movementPattern?.rawValue ?? ""
        ]
        + exercise.tags
        + exercise.allMuscles.map(\.displayName)
    }

    private func matches(_ focus: ExerciseFocus, exercise: Exercise) -> Bool {
        switch focus {
        case .push:
            return matchesPattern(exercise, [.horizontalPush, .verticalPush])
                || ExerciseBodyArea.chest.matches(exercise.allMuscles)
                || ExerciseBodyArea.shoulders.matches(exercise.allMuscles)
                || exercise.allMuscles.contains(where: { [.tricepLongHead, .tricepLateralHead, .tricepMedialHead].contains($0) })
        case .pull:
            return matchesPattern(exercise, [.horizontalPull, .verticalPull])
                || ExerciseBodyArea.back.matches(exercise.allMuscles)
                || exercise.allMuscles.contains(where: { [.rearDeltoid, .bicep, .brachialis, .brachioradialis, .forearms].contains($0) })
        case .legs:
            return matchesPattern(exercise, [.squat, .hinge, .lunge])
                || ExerciseBodyArea.glutes.matches(exercise.allMuscles)
                || ExerciseBodyArea.quadriceps.matches(exercise.allMuscles)
                || ExerciseBodyArea.hamstrings.matches(exercise.allMuscles)
                || ExerciseBodyArea.calves.matches(exercise.allMuscles)
                || ExerciseBodyArea.hips.matches(exercise.allMuscles)
        case .core:
            return matchesPattern(exercise, [.rotation, .antiRotation]) || ExerciseBodyArea.core.matches(exercise.allMuscles)
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
        Form {
            Section("Quick focus") {
                Picker("Focus", selection: $filter.focus) {
                    Text("All").tag(ExerciseFocus?.none)
                    ForEach(ExerciseFocus.allCases) { focus in
                        Text(LocalizedStringKey(focus.rawValue)).tag(Optional(focus))
                    }
                }
            }

            Section("Body area") {
                DisclosureGroup("Choose body areas") {
                    ForEach(ExerciseBodyArea.allCases) { area in
                        Toggle(LocalizedStringKey(area.rawValue), isOn: selectionBinding(for: area, keyPath: \.bodyAreas))
                    }
                }
            }

            Section("Movement") {
                DisclosureGroup("Choose movement patterns") {
                    ForEach(MovementPattern.allCases, id: \.self) { pattern in
                        Toggle(LocalizedStringKey(pattern.rawValue), isOn: selectionBinding(for: pattern, keyPath: \.movementPatterns))
                    }
                }
            }

            Section("Details") {
                Picker("Equipment", selection: $filter.equipment) {
                    Text("All equipment").tag(EquipmentType?.none)
                    ForEach(EquipmentType.allCases, id: \.self) { equipment in
                        Text(LocalizedStringKey(equipment.rawValue)).tag(Optional(equipment))
                    }
                }

                Picker("Category", selection: $filter.category) {
                    Text("All categories").tag(ExerciseCategory?.none)
                    ForEach(ExerciseCategory.allCases, id: \.self) { category in
                        Text(LocalizedStringKey(category.rawValue)).tag(Optional(category))
                    }
                }

                Picker("Difficulty", selection: $filter.difficulty) {
                    Text("All difficulties").tag(Difficulty?.none)
                    ForEach(Difficulty.allCases, id: \.self) { difficulty in
                        Text(LocalizedStringKey(difficulty.rawValue)).tag(Optional(difficulty))
                    }
                }

                Picker("Tracking", selection: $filter.tracking) {
                    Text("All tracking").tag(TrackingType?.none)
                    ForEach(TrackingType.allCases, id: \.self) { tracking in
                        Text(LocalizedStringKey(tracking.rawValue)).tag(Optional(tracking))
                    }
                }

                Toggle("Favorites only", isOn: $filter.favoritesOnly)
            }
        }
        .navigationTitle("Filters")
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

    private func selectionBinding<Value: Hashable>(
        for value: Value,
        keyPath: WritableKeyPath<ExerciseFilterState, Set<Value>>
    ) -> Binding<Bool> {
        Binding(
            get: { filter[keyPath: keyPath].contains(value) },
            set: { isSelected in
                var updatedFilter = filter
                if isSelected {
                    updatedFilter[keyPath: keyPath].insert(value)
                } else {
                    updatedFilter[keyPath: keyPath].remove(value)
                }
                filter = updatedFilter
            }
        )
    }
}
