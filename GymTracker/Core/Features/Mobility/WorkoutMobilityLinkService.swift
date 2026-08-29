import Foundation
import SwiftData

enum WorkoutMobilityPlacement: CaseIterable, Hashable {
    case beforeWorkout
    case afterWorkout
}

enum MobilityRoutineDurationEstimateCompleteness: Equatable {
    /// Every prescribed item has a time-based target.
    case complete
    /// At least one time-based target is known, but another item is repetition-based or missing a target.
    case partial
    /// No item has a time-based target.
    case unknown
}

struct MobilityRoutineDurationEstimate: Equatable {
    let knownDurationSeconds: Int
    let completeness: MobilityRoutineDurationEstimateCompleteness

    static func estimate(for routine: MobilityRoutine) -> Self {
        var knownDurationSeconds = 0
        var hasUnknownDuration = false

        for item in routine.orderedItems {
            let sideCount = max(1, item.side.resultSides.count)

            if item.definition.trackingType == .duration,
               let durationSeconds = item.targetDurationSeconds ?? item.definition.defaultDurationSeconds {
                // Mobility execution currently creates one result per resolved
                // side. It does not yet advance through authored cycles or rest
                // intervals, so including those here would overstate the time
                // this linked routine actually adds to a workout.
                knownDurationSeconds += max(0, durationSeconds) * sideCount
            } else {
                hasUnknownDuration = true
            }
        }

        let completeness: MobilityRoutineDurationEstimateCompleteness
        if hasUnknownDuration == false {
            completeness = .complete
        } else if knownDurationSeconds > 0 {
            completeness = .partial
        } else {
            completeness = .unknown
        }

        return Self(
            knownDurationSeconds: knownDurationSeconds,
            completeness: completeness
        )
    }
}

struct WorkoutMobilityRoutineLink {
    let routine: MobilityRoutine?
    let routineIDSnapshot: UUID?
    let routineNameSnapshot: String?

    var isUnavailable: Bool {
        routine == nil && (routineIDSnapshot != nil || routineNameSnapshot != nil)
    }
}

enum WorkoutMobilityLinkMutationError: Error, Equatable {
    case archivedRoutine
    case emptyRoutine
}

@MainActor
enum WorkoutMobilityLinkService {
    static func link(
        for placement: WorkoutMobilityPlacement,
        on template: WorkoutTemplate
    ) -> WorkoutMobilityRoutineLink {
        let routine = routine(for: placement, on: template)
        return WorkoutMobilityRoutineLink(
            routine: routine,
            routineIDSnapshot: routine?.id,
            routineNameSnapshot: routine?.name
        )
    }

    static func link(
        for placement: WorkoutMobilityPlacement,
        on slot: RepeatingPlanSlot
    ) -> WorkoutMobilityRoutineLink {
        switch placement {
        case .beforeWorkout:
            return WorkoutMobilityRoutineLink(
                routine: slot.preWorkoutMobilityRoutine,
                routineIDSnapshot: slot.preWorkoutMobilityRoutineIDSnapshot,
                routineNameSnapshot: slot.preWorkoutMobilityRoutineNameSnapshot
            )
        case .afterWorkout:
            return WorkoutMobilityRoutineLink(
                routine: slot.postWorkoutMobilityRoutine,
                routineIDSnapshot: slot.postWorkoutMobilityRoutineIDSnapshot,
                routineNameSnapshot: slot.postWorkoutMobilityRoutineNameSnapshot
            )
        }
    }

    static func set(
        _ routine: MobilityRoutine?,
        for placement: WorkoutMobilityPlacement,
        on template: WorkoutTemplate,
        using modelContext: ModelContext
    ) throws {
        try validate(routine)

        switch placement {
        case .beforeWorkout:
            template.preWorkoutMobilityRoutine = routine
        case .afterWorkout:
            template.postWorkoutMobilityRoutine = routine
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    static func set(
        _ routine: MobilityRoutine?,
        for placement: WorkoutMobilityPlacement,
        on slot: RepeatingPlanSlot,
        using modelContext: ModelContext
    ) throws {
        try validate(routine)

        switch placement {
        case .beforeWorkout:
            slot.preWorkoutMobilityRoutine = routine
            slot.preWorkoutMobilityRoutineIDSnapshot = routine?.id
            slot.preWorkoutMobilityRoutineNameSnapshot = routine?.name
        case .afterWorkout:
            slot.postWorkoutMobilityRoutine = routine
            slot.postWorkoutMobilityRoutineIDSnapshot = routine?.id
            slot.postWorkoutMobilityRoutineNameSnapshot = routine?.name
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private static func validate(_ routine: MobilityRoutine?) throws {
        if routine?.isArchived == true {
            throw WorkoutMobilityLinkMutationError.archivedRoutine
        }
        if routine?.orderedItems.isEmpty == true {
            throw WorkoutMobilityLinkMutationError.emptyRoutine
        }
    }

    private static func routine(
        for placement: WorkoutMobilityPlacement,
        on template: WorkoutTemplate
    ) -> MobilityRoutine? {
        switch placement {
        case .beforeWorkout:
            template.preWorkoutMobilityRoutine
        case .afterWorkout:
            template.postWorkoutMobilityRoutine
        }
    }
}
