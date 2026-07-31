import Foundation

/// How long to rest when nothing has said otherwise.
///
/// This is a fallback, not a prescription. `WorkoutSetSelector.restSeconds`
/// consults `entry.prescribedRestSeconds` first, so a plan that specifies rest
/// is never affected by anything here. What this governs is free workouts,
/// templates without a rest value, and plan exercises that left it unset —
/// which, for a new lifter, is most of what they do.
///
/// It replaces a single global 20 seconds. That number was shorter than any
/// strength protocol, so the timer reached "Ready" long before the lifter was,
/// which teaches people to ignore it — and a rest timer nobody trusts makes
/// every other improvement to it worthless.
///
/// **The tiers are a product position, not a computation.** They encode a
/// conventional reading of rest requirements: systemic compound work needs the
/// most, bracing and rotational core work the least, and a loaded barbell
/// raises the demand of whatever pattern it is used for. They are meant to be
/// retuned in one place.
enum WorkoutRestPolicy {
    /// Seconds of rest to offer after a set of `entry`, absent a prescription.
    static func defaultSeconds(for entry: ExerciseEntry) -> Int {
        defaultSeconds(for: entry.exercise)
    }

    static func defaultSeconds(for exercise: Exercise) -> Int {
        // Non-strength work is not rate-limited by recovery in the same way, so
        // the pattern tiers below do not apply to it.
        if let category = exercise.category, category != .strength {
            return 60
        }

        let base = baseSeconds(for: exercise.movementPattern)
        return carriesHeavyExternalLoad(exercise) ? heavier(base) : base
    }

    /// The pattern's demand before equipment is considered.
    private static func baseSeconds(for pattern: MovementPattern?) -> Int {
        switch pattern {
        case .squat, .hinge:
            // Highest systemic cost: the whole body is under the bar.
            150
        case .horizontalPush, .verticalPush, .horizontalPull, .verticalPull:
            90
        case .lunge, .carry, .locomotion:
            90
        case .rotation, .antiRotation, .antiExtension, .antiLateralFlexion:
            // Bracing and rotational work is local and recovers quickly.
            60
        case .other, .none:
            // Unknown pattern gets the general-purpose middle value rather than
            // an extreme in either direction.
            90
        }
    }

    /// A barbell or plate-loaded implement raises the demand of whatever
    /// pattern it is used for, so those move up one step.
    private static func carriesHeavyExternalLoad(_ exercise: Exercise) -> Bool {
        if exercise.isPlateLoaded { return true }
        return exercise.equipmentType == .barbell
    }

    private static func heavier(_ base: Int) -> Int {
        switch base {
        case 150: 180
        case 90: 120
        default: base
        }
    }
}
