import Foundation
import SwiftData

/// Represents an in-progress active workout draft on the local device.
///
/// This model belongs exclusively to the local device store (`cloudKitDatabase: .none`).
/// It prevents in-progress workouts from synchronizing across devices or corrupting
/// completed historical workouts on another device.
@Model
final class ActiveWorkoutDraft {
    var id: UUID
    var name: String
    var startTime: Date
    var notes: String?
    var usedMetricRaw: String
    var sourceTemplateID: UUID?
    var sourcePlanID: UUID?
    var sourcePlanRunID: UUID?
    var sourcePlanBlockID: UUID?
    var sourcePlanWeekID: UUID?
    var sourcePlannedWorkoutID: UUID?
    var sourcePlanName: String?
    var sourceProgramDefinitionID: UUID?
    var sourceProgramDefinitionVersion: Int?
    var sourceRepeatingPlanID: UUID?
    var sourceRepeatingPlanRunID: UUID?
    var sourceRepeatingPlanOccurrenceID: UUID?
    var sourceRepeatingPlanName: String?
    var draftVersion: Int
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ActiveExerciseDraft.workoutDraft)
    var exercises: [ActiveExerciseDraft] = []

    @Relationship(deleteRule: .cascade, inverse: \ActiveExecutionBlockDraft.workoutDraft)
    var executionBlocks: [ActiveExecutionBlockDraft] = []

    @Relationship(deleteRule: .cascade, inverse: \ActiveRestStateRecord.workoutDraft)
    var restState: ActiveRestStateRecord?

    var usedMetric: UnitSystem {
        get { UnitSystem(rawValue: usedMetricRaw) ?? .metric }
        set { usedMetricRaw = newValue.rawValue }
    }

    var orderedExercises: [ActiveExerciseDraft] {
        exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    init(
        name: String,
        startTime: Date = .now,
        notes: String? = nil,
        usedMetric: UnitSystem = .metric,
        sourceTemplateID: UUID? = nil,
        sourcePlanID: UUID? = nil,
        sourcePlanRunID: UUID? = nil,
        sourcePlanBlockID: UUID? = nil,
        sourcePlanWeekID: UUID? = nil,
        sourcePlannedWorkoutID: UUID? = nil,
        sourcePlanName: String? = nil,
        sourceProgramDefinitionID: UUID? = nil,
        sourceProgramDefinitionVersion: Int? = nil,
        sourceRepeatingPlanID: UUID? = nil,
        sourceRepeatingPlanRunID: UUID? = nil,
        sourceRepeatingPlanOccurrenceID: UUID? = nil,
        sourceRepeatingPlanName: String? = nil,
        draftVersion: Int = 1,
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.startTime = startTime
        self.notes = notes
        self.usedMetricRaw = usedMetric.rawValue
        self.sourceTemplateID = sourceTemplateID
        self.sourcePlanID = sourcePlanID
        self.sourcePlanRunID = sourcePlanRunID
        self.sourcePlanBlockID = sourcePlanBlockID
        self.sourcePlanWeekID = sourcePlanWeekID
        self.sourcePlannedWorkoutID = sourcePlannedWorkoutID
        self.sourcePlanName = sourcePlanName
        self.sourceProgramDefinitionID = sourceProgramDefinitionID
        self.sourceProgramDefinitionVersion = sourceProgramDefinitionVersion
        self.sourceRepeatingPlanID = sourceRepeatingPlanID
        self.sourceRepeatingPlanRunID = sourceRepeatingPlanRunID
        self.sourceRepeatingPlanOccurrenceID = sourceRepeatingPlanOccurrenceID
        self.sourceRepeatingPlanName = sourceRepeatingPlanName
        self.draftVersion = draftVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Represents an in-progress exercise draft inside an active workout.
@Model
final class ActiveExerciseDraft {
    var id: UUID
    var orderIndex: Int
    var sourceExerciseID: UUID?
    var exerciseNameSnapshot: String
    var trackingTypeSnapshotRaw: String
    var supersetGroupID: UUID?
    var executionBlockID: UUID?
    var executionBlockComponentOrder: Int?
    var comment: String?
    var workoutDraft: ActiveWorkoutDraft?

    @Relationship(deleteRule: .cascade, inverse: \ActiveSetDraft.exerciseDraft)
    var sets: [ActiveSetDraft] = []

    var trackingTypeSnapshot: TrackingType {
        get { TrackingType(rawValue: trackingTypeSnapshotRaw) ?? .weightAndReps }
        set { trackingTypeSnapshotRaw = newValue.rawValue }
    }

    var orderedSets: [ActiveSetDraft] {
        sets.sorted { $0.orderIndex < $1.orderIndex }
    }

    init(
        orderIndex: Int,
        sourceExerciseID: UUID?,
        exerciseNameSnapshot: String,
        trackingTypeSnapshot: TrackingType,
        supersetGroupID: UUID? = nil,
        executionBlockID: UUID? = nil,
        executionBlockComponentOrder: Int? = nil,
        comment: String? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.sourceExerciseID = sourceExerciseID
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.trackingTypeSnapshotRaw = trackingTypeSnapshot.rawValue
        self.supersetGroupID = supersetGroupID
        self.executionBlockID = executionBlockID
        self.executionBlockComponentOrder = executionBlockComponentOrder
        self.comment = comment
    }
}

/// Represents an in-progress set draft inside an active exercise.
@Model
final class ActiveSetDraft {
    var id: UUID
    var orderIndex: Int
    var setTypeRaw: String
    var setMethodRaw: String
    var repetitions: Int?
    var weight: Float?
    var weightTypeRaw: String
    var duration: Int?
    var distance: Double?
    var distanceTypeRaw: String
    var calories: Int?
    var done: Bool
    var rpe: Double?
    var rir: Int?
    var tempo: String?
    var exerciseDraft: ActiveExerciseDraft?

    var setType: SetType {
        get { SetType(rawValue: setTypeRaw) ?? .normal }
        set { setTypeRaw = newValue.rawValue }
    }

    var setMethod: SetMethod {
        get { SetMethod(rawValue: setMethodRaw) ?? .standard }
        set { setMethodRaw = newValue.rawValue }
    }

    var weightType: WeightType {
        get { WeightType(rawValue: weightTypeRaw) ?? .kg }
        set { weightTypeRaw = newValue.rawValue }
    }

    var distanceType: DistanceType {
        get { DistanceType(rawValue: distanceTypeRaw) ?? .meters }
        set { distanceTypeRaw = newValue.rawValue }
    }

    init(
        orderIndex: Int,
        setType: SetType = .normal,
        setMethod: SetMethod = .standard,
        repetitions: Int? = nil,
        weight: Float? = nil,
        weightType: WeightType = .kg,
        duration: Int? = nil,
        distance: Double? = nil,
        distanceType: DistanceType = .meters,
        calories: Int? = nil,
        done: Bool = false,
        rpe: Double? = nil,
        rir: Int? = nil,
        tempo: String? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.setTypeRaw = setType.rawValue
        self.setMethodRaw = setMethod.rawValue
        self.repetitions = repetitions
        self.weight = weight
        self.weightTypeRaw = weightType.rawValue
        self.duration = duration
        self.distance = distance
        self.distanceTypeRaw = distanceType.rawValue
        self.calories = calories
        self.done = done
        self.rpe = rpe
        self.rir = rir
        self.tempo = tempo
    }
}

/// Execution block draft in active workout.
@Model
final class ActiveExecutionBlockDraft {
    var id: UUID
    var blockKindRaw: String
    var workoutDraft: ActiveWorkoutDraft?

    init(id: UUID = UUID(), blockKindRaw: String = "circuit") {
        self.id = id
        self.blockKindRaw = blockKindRaw
    }
}

/// Active rest state record stored in local device configuration.
@Model
final class ActiveRestStateRecord {
    var id: UUID
    var stateKindRaw: String
    var targetEndDate: Date?
    var remainingIntervalSeconds: TimeInterval?
    var workoutDraft: ActiveWorkoutDraft?

    init(
        id: UUID = UUID(),
        stateKindRaw: String = "inactive",
        targetEndDate: Date? = nil,
        remainingIntervalSeconds: TimeInterval? = nil
    ) {
        self.id = id
        self.stateKindRaw = stateKindRaw
        self.targetEndDate = targetEndDate
        self.remainingIntervalSeconds = remainingIntervalSeconds
    }
}
