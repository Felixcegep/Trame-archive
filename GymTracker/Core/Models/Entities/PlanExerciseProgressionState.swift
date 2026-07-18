import Foundation
import SwiftData

/// Mutable state for one planned exercise exposure inside one PlanRun.
/// Prescription definitions remain immutable; this record is the only place
/// where future progression state is advanced.
@Model
final class PlanExerciseProgressionState {
    var id = UUID()
    var progressionKey: String
    var currentLoad: Double?
    var currentLoadType: WeightType?
    var repetitionOffset: Int
    var setCountOffset: Int
    var currentStageID: String?
    var currentVariationExerciseID: UUID?
    var trainingMax: Double?
    var estimatedOneRepMax: Double?
    var failureCount: Int
    var successCount: Int
    var currentWaveIndex: Int?
    var currentBlockIndex: Int?
    var previousAMRAPRepetitions: Int?
    var previousActualRPE: Double?
    var previousActualRIR: Double?
    var lastCompletedOccurrence: Date?
    var lastSuccessfulLoad: Double?
    var isDeloading: Bool
    var lastAppliedOutcomeID: UUID?
    var planRun: PlanRun?

    init(
        progressionKey: String,
        currentLoad: Double? = nil,
        currentLoadType: WeightType? = nil,
        repetitionOffset: Int = 0,
        setCountOffset: Int = 0,
        currentStageID: String? = nil,
        currentVariationExerciseID: UUID? = nil,
        trainingMax: Double? = nil,
        estimatedOneRepMax: Double? = nil,
        failureCount: Int = 0,
        successCount: Int = 0,
        currentWaveIndex: Int? = nil,
        currentBlockIndex: Int? = nil,
        previousAMRAPRepetitions: Int? = nil,
        previousActualRPE: Double? = nil,
        previousActualRIR: Double? = nil,
        lastCompletedOccurrence: Date? = nil,
        lastSuccessfulLoad: Double? = nil,
        isDeloading: Bool = false,
        lastAppliedOutcomeID: UUID? = nil
    ) {
        self.progressionKey = progressionKey
        self.currentLoad = currentLoad
        self.currentLoadType = currentLoadType
        self.repetitionOffset = repetitionOffset
        self.setCountOffset = setCountOffset
        self.currentStageID = currentStageID
        self.currentVariationExerciseID = currentVariationExerciseID
        self.trainingMax = trainingMax
        self.estimatedOneRepMax = estimatedOneRepMax
        self.failureCount = max(0, failureCount)
        self.successCount = max(0, successCount)
        self.currentWaveIndex = currentWaveIndex
        self.currentBlockIndex = currentBlockIndex
        self.previousAMRAPRepetitions = previousAMRAPRepetitions
        self.previousActualRPE = previousActualRPE
        self.previousActualRIR = previousActualRIR
        self.lastCompletedOccurrence = lastCompletedOccurrence
        self.lastSuccessfulLoad = lastSuccessfulLoad
        self.isDeloading = isDeloading
        self.lastAppliedOutcomeID = lastAppliedOutcomeID
    }
}
