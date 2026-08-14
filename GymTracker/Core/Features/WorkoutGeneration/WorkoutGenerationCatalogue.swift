import Foundation

/// Copies only eligible current exercises into an immutable, bounded catalogue
/// before model generation. The generator therefore cannot see archived
/// exercises or retain SwiftData-managed objects across an `await`.
@MainActor
enum WorkoutGenerationCatalogue {
    static let maximumOptions = 60

    static func build(
        from exercises: [Exercise],
        request: WorkoutGenerationRequest,
        profile: WorkoutGenerationProfileSnapshot
    ) -> [WorkoutGenerationExerciseOption] {
        let selectedEquipment = request.selectedEquipment.isEmpty
            ? profile.availableEquipment
            : request.selectedEquipment
        let excludedIDs = request.excludedExerciseIDs.union(profile.avoidedExerciseIDs)

        let eligible = exercises.lazy.filter { exercise in
                guard !exercise.isArchived, !excludedIDs.contains(exercise.id) else { return false }
                guard !selectedEquipment.isEmpty else { return true }
                return exercise.equipmentType.map(selectedEquipment.contains) ?? true
            }
        return boundedSortedPrefix(eligible, limit: maximumOptions) { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite && !rhs.isFavorite }
                let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
                if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .map { exercise in
                WorkoutGenerationExerciseOption(
                    exerciseID: exercise.id,
                    name: exercise.name,
                    frenchName: exercise.frenchName,
                    trackingType: exercise.trackingType,
                    equipmentType: exercise.equipmentType,
                    primaryMuscles: exercise.primaryMuscles,
                    secondaryMuscles: exercise.secondaryMuscles ?? [],
                    movementPattern: exercise.movementPattern,
                    difficulty: exercise.difficulty,
                    isFavorite: exercise.isFavorite
                )
            }
    }

    private static func boundedSortedPrefix<Values: Sequence>(
        _ values: Values,
        limit: Int,
        by areInIncreasingOrder: (Values.Element, Values.Element) -> Bool
    ) -> [Values.Element] {
        guard limit > 0 else { return [] }
        var result: [Values.Element] = []
        result.reserveCapacity(limit)
        for value in values {
            var lower = 0
            var upper = result.count
            while lower < upper {
                let middle = lower + (upper - lower) / 2
                if areInIncreasingOrder(value, result[middle]) {
                    upper = middle
                } else {
                    lower = middle + 1
                }
            }
            let insertionIndex = lower
            guard insertionIndex < limit else { continue }
            result.insert(value, at: insertionIndex)
            if result.count > limit {
                result.removeLast()
            }
        }
        return result
    }
}
