import Foundation

struct CompletedSetEditSnapshot {
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
