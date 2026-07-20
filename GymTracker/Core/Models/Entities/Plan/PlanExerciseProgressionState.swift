import Foundation
import SwiftData

/// Mutable progression state inside one PlanRun. Legacy records use the
/// exercise-exposure scope; wider scopes add an explicit owner key so the
/// same lift can retain independent week, block, cycle, and run state.
@Model
final class PlanExerciseProgressionState {
    var id = UUID()
    var progressionKey: String
    /// Raw representation keeps this shared persistence model available to
    /// the extension target, which does not link the program-engine types.
    var scopeRaw: String = "exerciseExposure"
    /// Empty means a legacy exposure record and resolves to `progressionKey`.
    var scopeOwnerKey: String = ""
    var currentLoad: Double?
    var currentLoadType: WeightType?
    var repetitionOffset: Int
    var setCountOffset: Int
    var durationOffset: TimeInterval
    var distanceOffset: Double
    var restDurationOffset: Int
    var caloriesOffset: Double
    var currentStageID: String?
    var currentVariationExerciseID: UUID?
    var trainingMax: Double?
    var estimatedOneRepMax: Double?
    var actualOneRepMax: Double?
    var failureCount: Int
    var successCount: Int
    var currentWaveIndex: Int?
    var currentBlockIndex: Int?
    var previousAMRAPRepetitions: Int?
    var previousActualRPE: Double?
    var previousActualRIR: Double?
    var velocityBaseline: Double?
    var lastCompletedOccurrence: Date?
    var lastSuccessfulLoad: Double?
    var isDeloading: Bool
    var lastAppliedOutcomeID: UUID?
    /// Last active-workout set event applied to this scoped state. It prevents
    /// duplicate view updates from advancing a same-session rule twice while
    /// still allowing the next completed set to evaluate independently.
    var lastAppliedSetID: UUID?
    /// Encoded cadence-aware workout markers. A state can receive more than
    /// one rule cadence from the same completed workout.
    var appliedProgressionEventsData: Data?
    /// Encoded future states waiting for their declared cadence boundary.
    /// Optional keeps legacy stores and backups source-compatible.
    var pendingProgressionData: Data?
    var planRun: PlanRun?

    init(
        progressionKey: String,
        scopeRaw: String = "exerciseExposure",
        scopeOwnerKey: String? = nil,
        currentLoad: Double? = nil,
        currentLoadType: WeightType? = nil,
        repetitionOffset: Int = 0,
        setCountOffset: Int = 0,
        durationOffset: TimeInterval = 0,
        distanceOffset: Double = 0,
        restDurationOffset: Int = 0,
        caloriesOffset: Double = 0,
        currentStageID: String? = nil,
        currentVariationExerciseID: UUID? = nil,
        trainingMax: Double? = nil,
        estimatedOneRepMax: Double? = nil,
        actualOneRepMax: Double? = nil,
        failureCount: Int = 0,
        successCount: Int = 0,
        currentWaveIndex: Int? = nil,
        currentBlockIndex: Int? = nil,
        previousAMRAPRepetitions: Int? = nil,
        previousActualRPE: Double? = nil,
        previousActualRIR: Double? = nil,
        velocityBaseline: Double? = nil,
        lastCompletedOccurrence: Date? = nil,
        lastSuccessfulLoad: Double? = nil,
        isDeloading: Bool = false,
        lastAppliedOutcomeID: UUID? = nil,
        lastAppliedSetID: UUID? = nil,
        appliedProgressionEventsData: Data? = nil,
        pendingProgressionData: Data? = nil
    ) {
        self.progressionKey = progressionKey
        self.scopeRaw = scopeRaw
        self.scopeOwnerKey = scopeOwnerKey ?? (scopeRaw == "exerciseExposure" ? progressionKey : "")
        self.currentLoad = currentLoad
        self.currentLoadType = currentLoadType
        self.repetitionOffset = repetitionOffset
        self.setCountOffset = setCountOffset
        // Offsets are signed: a data-driven reduction action must be able to
        // lower a future prescription below its original value. Snapshot
        // generation clamps the resulting physical target, never the state.
        self.durationOffset = durationOffset
        self.distanceOffset = distanceOffset
        self.restDurationOffset = restDurationOffset
        self.caloriesOffset = caloriesOffset
        self.currentStageID = currentStageID
        self.currentVariationExerciseID = currentVariationExerciseID
        self.trainingMax = trainingMax
        self.estimatedOneRepMax = estimatedOneRepMax
        self.actualOneRepMax = actualOneRepMax
        self.failureCount = max(0, failureCount)
        self.successCount = max(0, successCount)
        self.currentWaveIndex = currentWaveIndex
        self.currentBlockIndex = currentBlockIndex
        self.previousAMRAPRepetitions = previousAMRAPRepetitions
        self.previousActualRPE = previousActualRPE
        self.previousActualRIR = previousActualRIR
        self.velocityBaseline = velocityBaseline
        self.lastCompletedOccurrence = lastCompletedOccurrence
        self.lastSuccessfulLoad = lastSuccessfulLoad
        self.isDeloading = isDeloading
        self.lastAppliedOutcomeID = lastAppliedOutcomeID
        self.lastAppliedSetID = lastAppliedSetID
        self.appliedProgressionEventsData = appliedProgressionEventsData
        self.pendingProgressionData = pendingProgressionData
    }
}
