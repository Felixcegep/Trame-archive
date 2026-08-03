import Foundation

nonisolated struct PreferencesDTO: Codable {
    let darkMode: Bool
    let restTimer: Int
    let unitSystem: String
    var bodyWeightPromptCadence: String? = nil
    var birthdateTimestamp: Double? = nil
}

/// The lifter's stated training preferences.
///
/// Every field is optional, including on the way out: a profile that never
/// answered a question exports that fact rather than a default. Enumerated
/// values travel as their raw identifiers and are decoded leniently on restore,
/// so a profile written by a newer build lands in an older one with the
/// unrecognised fields simply absent instead of failing the whole restore.
nonisolated struct TrainingProfileDTO: Codable {
    var schemaVersion: Int? = nil
    var onboardingVersion: Int? = nil
    var preferredTrainingStructure: String? = nil
    var primaryDiscipline: String? = nil
    var secondaryDisciplineIDs: [String]? = nil
    var primaryGoal: String? = nil
    var experienceLevel: String? = nil
    var preferredDaysPerWeek: Int? = nil
    var preferredWeekdays: [Int]? = nil
    var scheduleFlexibility: String? = nil
    var rotationCadence: String? = nil
    var sessionDuration: String? = nil
    var trainingLocation: String? = nil
    var equipmentCapabilityIDs: [String]? = nil
    var specializedEquipmentCapabilityIDs: [String]? = nil
    var focusAreaIDs: [String]? = nil
    var competitionDiscipline: String? = nil
    var competitionEventDateTimestamp: Double? = nil
    var competitionStandards: String? = nil
    var completedCoreOnboardingAtTimestamp: Double? = nil
    var createdAtTimestamp: Double? = nil
    var updatedAtTimestamp: Double? = nil
}

nonisolated struct ExerciseTemplateDTO: Codable {
    var id: String? = nil
    let name: String
    let primaryMuscles: [String]
    let secondaryMuscles: [String]?
    let category: String?
    let trackingType: String
    let equipmentType: String?
    let resistanceType: String?
    let movementPattern: String?
    let difficulty: String?
    let tags: [String]
    let isFavorite: Bool
    let isPlateLoaded: Bool
    let isCustom: Bool
    let isArchived: Bool
    var forceType: String? = nil
    var mechanics: String? = nil
    var laterality: String? = nil
    var repCountingStyle: String? = nil
    var weightEntryStyle: String? = nil
    var loadUnitCount: Int? = nil
    var gripStyle: String? = nil
    var stance: String? = nil
    var rangeOfMotion: String? = nil
    var setupAngleDegrees: Int? = nil
    var variationFamilyID: String? = nil
    var frenchName: String? = nil
    var searchAliases: [String]? = nil
}

nonisolated struct ExerciseRelationshipDTO: Codable {
    let sourceExerciseName: String
    let targetExerciseName: String
    let type: String
    /// Curation provenance and constraints, added in
    /// `BackupDTO.decisionAwareSubstitutionVersion`. All optional so pre-v20
    /// payloads restore unchanged and read as `systemUnreviewed`.
    var provenance: String? = nil
    var rationaleCode: String? = nil
    var appliesToGoals: [String]? = nil
    var appliesToRoles: [String]? = nil
    var reviewVersion: Int? = nil
}

nonisolated struct TemplateExerciseDTO: Codable {
    let exerciseName: String
    let orderIndex: Int
    let targetSets: Int
    let repRangeMinimum: Int
    let repRangeMaximum: Int
    let restSeconds: Int
    let targetRPE: Double?
    let targetRIR: Int?
    let notes: String?
    let progressionRule: String?
    var supersetGroupID: String? = nil
    var progressionKey: String? = nil
    var executionBlockID: String? = nil
    var executionBlockComponentOrder: Int? = nil
    // Explicit author intent only. Older backups omit it and restore as nil;
    // a missing value must never be replaced with an invented default.
    var stimulus: String? = nil
}

nonisolated struct TemplateExerciseBlockDTO: Codable {
    let id: String
    let orderIndex: Int
    let kind: String
    let name: String?
    let targetRounds: Int?
    let isSharedLoad: Bool
    let restSeconds: Int?
    let clockMode: String
    let prescribedDurationSeconds: Int?
    let timeCapSeconds: Int?
    let intervalSeconds: Int?
    let scoreKind: String
    var repetitionScheme: String? = nil
    var repetitionStart: Int? = nil
    var repetitionEnd: Int? = nil
    var repetitionStep: Int? = nil
}

nonisolated struct WorkoutTemplateDTO: Codable {
    let name: String
    let templateExercises: [TemplateExerciseDTO]
    var executionBlocks: [TemplateExerciseBlockDTO]? = nil
    var preWorkoutMobilityRoutineName: String? = nil
    var postWorkoutMobilityRoutineName: String? = nil
}

nonisolated struct WorkoutCollectionDTO: Codable {
    let name: String
    let templateNames: [String]
}

nonisolated struct ExerciseSetDTO: Codable {
    let orderIndex: Int
    let weightType: String
    let distanceType: String
    let repetition: Float
    let weight: Float
    let duration: Double?
    let distance: Float?
    var calories: Double? = nil
    let done: Bool
    var isUserOverridden: Bool = false
    var userOverrideReason: String? = nil
    var userOverrideAffectsFuture: Bool = false
    let rpe: Double?
    var rir: Int? = nil
    var tempo: String? = nil
    var movementQuality: Int? = nil
    var descriptiveROM: String? = nil
    var discomfortScore: Int? = nil
    var liftQuality: String? = nil
    var meanVelocity: Double? = nil
    var peakVelocity: Double? = nil
    var velocityMeasurementSource: String? = nil
    var specializedMetricKind: String? = nil
    var jumpHeightMeters: Double? = nil
    var contactTimeMilliseconds: Double? = nil
    var throwDistanceMeters: Double? = nil
    var kettlebellCadenceRPM: Double? = nil
    var specializedMetricMeasurementSource: String? = nil
    var setMethod: String? = nil
    var segments: [ExerciseSetSegmentDTO]? = nil
    var complexComponents: [ComplexComponentResultDTO]? = nil
    let setType: String
    var isSelectedDailyMaximum: Bool? = nil
    var generatedBackOffDefinitionID: String? = nil
    let usedMetric: String
    var prescribedSetType: String? = nil
    var prescribedRepetitions: Int? = nil
    var prescribedRepRangeMinimum: Int? = nil
    var prescribedRepRangeMaximum: Int? = nil
    var prescribedSuggestedLoad: Double? = nil
    var prescribedSuggestedLoadType: String? = nil
    var prescribedUnroundedLoad: Double? = nil
    var prescribedReferenceValue: Double? = nil
    var prescriptionLoadExplanation: String? = nil
    var prescribedRestSeconds: Int? = nil
    var prescribedRPE: Double? = nil
    var prescribedRIR: Int? = nil
    var prescribedTempo: String? = nil
    var prescribedProgressionEligible: Bool? = nil
    var prescribedCalories: Double? = nil
    var prescribedVelocityMinimum: Double? = nil
    var prescribedVelocityMaximum: Double? = nil
    var prescribedVelocityLossStopPercent: Double? = nil
    var isVelocityProbe: Bool? = nil
    var isPrescribedOptional: Bool? = nil
    var prescriptionNotes: String? = nil
    var prescriptionDefinitionData: Data? = nil
    var id: String? = nil
}

nonisolated struct ExerciseSetSegmentDTO: Codable {
    let id: String
    let orderIndex: Int
    let repetitions: Float
    let weight: Float
    let weightType: String
    let duration: TimeInterval?
    let restAfterSeconds: Int?
    let done: Bool
    let variationNote: String?
    let rpe: Double?
    let rir: Int?
}

nonisolated struct ComplexComponentResultDTO: Codable {
    let id: String
    let orderIndex: Int
    let exerciseID: String
    let exerciseNameSnapshot: String
    let prescribedRepetitions: Int
    let performedRepetitions: Int
    let outcome: String
    let liftQuality: String?
}

nonisolated struct ExerciseEntryDTO: Codable {
    let orderIndex: Int
    let comment: String?
    let exerciseName: String
    let usedMetric: String
    let sets: [ExerciseSetDTO]

    let prescribedSets: Int?
    let prescribedRepRangeMinimum: Int?
    let prescribedRepRangeMaximum: Int?
    let prescribedRestSeconds: Int?
    let prescribedRPE: Double?
    let prescribedRIR: Int?
    let prescriptionNotes: String?
    let sourcePlannedExerciseID: String?
    var progressionKey: String? = nil
    let prescribedRole: String?
    let isPrescribedOptional: Bool?
    let prescribedSuggestedLoad: Double?
    let prescribedSuggestedLoadType: String?
    let prescribedProgressionRule: String?
    let recommendedDecision: String?
    let recommendedLoad: Float?
    let recommendedUnit: String?
    let recommendationPriorLoad: Float?
    let recommendationRequiredSets: Int?
    let recommendationRepCeiling: Int?
    let recommendationCompletedSets: Int?
    let recommendationPriorWorkoutDate: Date?
    let accumulatedActiveDuration: Double?
    let activeDurationStartedAt: Date?
    var stimulusSnapshot: String? = nil
    var supersetGroupID: String? = nil
    var executionBlockID: String? = nil
    var executionBlockComponentOrder: Int? = nil
    var originalExerciseIDSnapshot: String? = nil
    var originalExerciseNameSnapshot: String? = nil
    var selectedSubstituteExerciseIDSnapshot: String? = nil
    var substitutionReason: String? = nil
    var substitutionSharesProgressionState: Bool? = nil
    /// Structured substitution decision evidence, added in
    /// `BackupDTO.decisionAwareSubstitutionVersion`. All optional: a pre-v20
    /// backup restores with every field absent, which reads as "substituted
    /// without recorded decision evidence" and keeps the legacy Boolean
    /// authoritative for progression.
    var substitutionReasonCode: String? = nil
    var substitutionSuitability: String? = nil
    var substitutionComparability: String? = nil
    var substitutionProgressionPolicy: String? = nil
    var substitutionScope: String? = nil
    var substitutionEvidenceConfidence: String? = nil
    var substitutionEvaluationVersion: Int? = nil
    var substitutionEvaluationData: Data? = nil
    var variationSourceExerciseIDSnapshot: String? = nil
    var variationSelectedExerciseIDSnapshot: String? = nil
    var prescriptionDefinitionData: Data? = nil
    var prescriptionRulesData: Data? = nil
    var deferredBackOffDefinitionsData: Data? = nil
    /// The entry's own historical identity, distinct from `exerciseName`
    /// (which stays the live name and is restore's join key). `nil` only for
    /// backups older than `BackupDTO.historicalIdentitySnapshotVersion`; a
    /// restored entry then falls back to today's newly-linked exercise, same
    /// as pre-v15 behavior.
    var nameSnapshot: String? = nil
    var exerciseIDSnapshot: String? = nil
    var trackingTypeSnapshot: String? = nil
    var lateralitySnapshot: String? = nil
    var repCountingStyleSnapshot: String? = nil
    var weightEntryStyleSnapshot: String? = nil
    var loadUnitCountSnapshot: Int? = nil
}

nonisolated struct WorkoutDTO: Codable {
    let id: String?
    let status: String
    let name: String?
    let notes: String?
    let startTime: Date
    let endTime: Date?
    let restEndDate: Date?
    let pausedRemainingTime: Double?
    let sourceTemplateName: String?
    let sourcePlanID: String?
    let sourcePlanRunID: String?
    let sourcePlanBlockID: String?
    let sourcePlanWeekID: String?
    let sourcePlannedWorkoutID: String?
    let sourcePlanName: String?
    var sourceProgramDefinitionID: String? = nil
    var sourceProgramDefinitionVersion: Int? = nil
    var sourceRepeatingPlanID: String? = nil
    var sourceRepeatingPlanRunID: String? = nil
    var sourceRepeatingPlanOccurrenceID: String? = nil
    var sourceRepeatingPlanName: String? = nil
    let exercises: [ExerciseEntryDTO]
    var executionBlocks: [WorkoutExecutionBlockDTO]? = nil
}

nonisolated struct WorkoutExecutionBlockDTO: Codable {
    let id: String
    let orderIndex: Int
    let kind: String
    let name: String?
    let targetRounds: Int?
    let isSharedLoad: Bool
    let restSeconds: Int?
    let clockMode: String
    let prescribedDurationSeconds: Int?
    let timeCapSeconds: Int?
    let intervalSeconds: Int?
    let scoreKind: String
    var repetitionScheme: String? = nil
    var repetitionStart: Int? = nil
    var repetitionEnd: Int? = nil
    var repetitionStep: Int? = nil
    let status: String
    let completedRounds: Int
    let additionalRepetitions: Int
    let scoreValue: Double?
    let scoreTiebreakValue: Double?
    let accumulatedElapsedDuration: TimeInterval
    let elapsedStartedAt: Date?
    let sourceTemplateBlockID: String?
    let sourcePlannedBlockID: String?
    let sourceDefinitionBlockKey: String?
}

nonisolated struct PlannedExerciseDTO: Codable {
    let id: String
    let exerciseName: String
    let orderIndex: Int
    let role: String
    let isOptional: Bool
    let targetSets: Int
    let repRangeMinimum: Int
    let repRangeMaximum: Int
    let suggestedLoad: Double?
    let suggestedLoadType: String?
    let restSeconds: Int
    let targetRPE: Double?
    let targetRIR: Int?
    let notes: String?
    let progressionRule: String
    var stimulus: String? = nil
    var trackingTypeOverride: String? = nil
    var alternativeExerciseNames: [String]? = nil
    var supersetGroupID: String? = nil
    var executionBlockID: String? = nil
    var executionBlockComponentOrder: Int? = nil
    var plannedSets: [PlannedSetDTO]? = nil
    var progressionKey: String? = nil
    var progressionRulesData: Data? = nil
    var progressionWavesData: Data? = nil
    var progressionStagesData: Data? = nil
    var variationLadderData: Data? = nil
    var initialVariationExerciseID: String? = nil
    var initialVelocityBaseline: Double? = nil
    var initialTrainingMax: Double? = nil
    var initialEstimatedOneRepMax: Double? = nil
    var initialActualOneRepMax: Double? = nil
    var automaticDeloadVolumeReductionPercent: Int? = nil
    var automaticDeloadIntensityReductionPercent: Int? = nil
    var warmupSchemeData: Data? = nil
}

nonisolated struct PlannedSetDTO: Codable {
    let orderIndex: Int
    let setType: String
    let repetitions: Int?
    let repRangeMinimum: Int?
    let repRangeMaximum: Int?
    let suggestedLoad: Double?
    let suggestedLoadType: String?
    let restSeconds: Int?
    let targetRPE: Double?
    let targetRIR: Int?
    var tempo: String? = nil
    var progressionEligible: Bool? = nil
    let isOptional: Bool
    let notes: String?
    var definitionData: Data? = nil
}

nonisolated struct ProgressionStateDTO: Codable {
    let id: String
    let progressionKey: String
    var scope: String? = nil
    var scopeOwnerKey: String? = nil
    let currentLoad: Double?
    let currentLoadType: String?
    var repetitionOffset: Int = 0
    var setCountOffset: Int = 0
    var durationOffset: TimeInterval = 0
    var distanceOffset: Double = 0
    var restDurationOffset: Int = 0
    var caloriesOffset: Double = 0
    var actualOneRepMax: Double? = nil
    let currentStageID: String?
    let currentVariationExerciseID: String?
    let trainingMax: Double?
    let estimatedOneRepMax: Double?
    let failureCount: Int
    let successCount: Int
    let currentWaveIndex: Int?
    let currentBlockIndex: Int?
    let previousAMRAPRepetitions: Int?
    let previousActualRPE: Double?
    let previousActualRIR: Double?
    var velocityBaseline: Double? = nil
    let lastCompletedOccurrence: Date?
    let lastSuccessfulLoad: Double?
    let isDeloading: Bool
    let lastAppliedOutcomeID: String?
    var lastAppliedSetID: String? = nil
    var appliedProgressionEventsData: Data? = nil
    var pendingProgressionData: Data? = nil
}

nonisolated struct ProgressionRecommendationDTO: Codable {
    let id: String
    let planRunID: String
    let workoutID: String
    let progressionKey: String
    let ruleID: String
    let actionData: Data
    let cadence: String
    let scope: String
    var scopeOwnerKey: String? = nil
    let reason: String
    /// Structured receipt reason key. `nil` means a pre-v23 receipt whose
    /// legacy English reason remains provenance only.
    var reasonKey: String? = nil
    let applicationMode: String
    var performanceData: Data? = nil
    let proposedLoad: Double?
    /// Receipt-owned unit for `proposedLoad` / `appliedLoad`, never inferred
    /// from a plan during restore.
    var proposedLoadUnit: String? = nil
    var proposedTrainingMax: Double? = nil
    var proposedEstimatedOneRepMax: Double? = nil
    var proposedActualOneRepMax: Double? = nil
    let proposedStageID: String?
    let proposedVariationExerciseID: String?
    let proposedRepetitionOffset: Int
    let proposedSetCountOffset: Int
    var proposedDurationOffset: TimeInterval = 0
    var proposedDistanceOffset: Double = 0
    var proposedRestDurationOffset: Int = 0
    var proposedCaloriesOffset: Double = 0
    var proposedWaveIndex: Int = 0
    var proposedBlockIndex: Int = 0
    var proposedIsDeloading: Bool = false
    let createdAt: Date
    let isResolved: Bool
    let resolvedAt: Date?
    /// How this recommendation was resolved (`ProgressionDecisionOutcome`
    /// raw value). `nil` for backups older than
    /// `BackupDTO.progressionReceiptVersion` and for rows resolved before the
    /// field existed; this must decode as `nil` rather than be inferred from
    /// `isResolved`, since a legacy row is "resolved without a recorded
    /// outcome," never a fabricated decision.
    var decisionOutcome: String? = nil
    /// The load actually applied, when it differs from `proposedLoad`. `nil`
    /// unless the outcome is `.acceptedWithModifiedValue`.
    var appliedLoad: Double? = nil
    /// The progression rule definition's `version` at the moment this
    /// recommendation was built. `nil` means the version was not captured.
    var ruleVersion: Int? = nil
}

nonisolated struct PlannedWorkoutDTO: Codable {
    let id: String
    let name: String
    let orderIndex: Int
    let dayOffset: Int
    var isOptional: Bool = false
    var isTestDay: Bool = false
    let estimatedDurationSeconds: Int?
    let notes: String?
    let sourceTemplateName: String?
    let plannedExercises: [PlannedExerciseDTO]
    var executionBlocks: [PlannedExerciseBlockDTO]? = nil
}

nonisolated struct PlannedExerciseBlockDTO: Codable {
    let id: String
    let orderIndex: Int
    let kind: String
    let name: String?
    let targetRounds: Int?
    let isSharedLoad: Bool
    let restSeconds: Int?
    let clockMode: String
    let prescribedDurationSeconds: Int?
    let timeCapSeconds: Int?
    let intervalSeconds: Int?
    let scoreKind: String
    var repetitionScheme: String? = nil
    var repetitionStart: Int? = nil
    var repetitionEnd: Int? = nil
    var repetitionStep: Int? = nil
    let sourceTemplateBlockID: String?
    let definitionBlockKey: String?
}

nonisolated struct PlanWeekDTO: Codable {
    let id: String
    let weekIndex: Int
    let name: String?
    let notes: String?
    let plannedWorkouts: [PlannedWorkoutDTO]
}

nonisolated struct PlanBlockDTO: Codable {
    let id: String
    let name: String
    let phaseType: String
    let goal: String?
    let notes: String?
    let deloadVolumeReductionPercent: Int?
    let deloadIntensityReductionPercent: Int?
    let orderIndex: Int
    let weeks: [PlanWeekDTO]
}

nonisolated struct WorkoutPlanDTO: Codable {
    let id: String
    let name: String
    let goal: String
    let experienceLevel: String
    let requiredEquipment: [String]
    let daysPerWeek: Int
    let durationWeeks: Int
    var scheduleMode: String? = nil
    var scheduleIntervalDays: Int? = nil
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    let isArchived: Bool
    var sourceProgramDefinitionID: String? = nil
    var sourceProgramDefinitionVersion: Int? = nil
    var completionPolicyData: Data? = nil
    let blocks: [PlanBlockDTO]
}

nonisolated struct PlanWorkoutProgressDTO: Codable {
    let id: String
    let plannedWorkoutID: String
    let plannedWorkoutName: String
    let weekIndex: Int
    var sourceWeekIndex: Int? = nil
    let workoutIndex: Int
    /// v21 schedule-origin evidence. Legacy backups decode both values as
    /// `nil`, which means reschedule provenance is unavailable rather than
    /// inferred from mutable plan definitions.
    var originalScheduledDate: Date? = nil
    let scheduledDate: Date?
    var lastRescheduledAt: Date? = nil
    let status: String
    let startedAt: Date?
    let completedAt: Date?
    let skipReason: String?
    let completedWorkoutID: String?
}

nonisolated struct PlanRunDTO: Codable {
    let id: String
    let sourcePlanID: String
    let sourcePlanName: String
    let planID: String?
    let startDate: Date
    let endDate: Date?
    let status: String
    let currentWeekIndex: Int
    let currentWorkoutIndex: Int
    var endedProgressionKeysData: Data? = nil
    let createdAt: Date
    let updatedAt: Date
    let workoutProgress: [PlanWorkoutProgressDTO]
    var progressionStates: [ProgressionStateDTO] = []
}

nonisolated struct ProgramDefinitionDTO: Codable {
    let id: String
    let schemaVersion: Int
    let templateVersion: Int
    let name: String
    let summary: String?
    let goal: String
    let experienceLevel: String
    let durationWeeks: Int
    let supportedDaysPerWeek: [Int]
    let isBuiltIn: Bool
    let isArchived: Bool
    let createdAt: Date
    let updatedAt: Date
    let definitionData: Data
}

nonisolated struct DailyLogEntryDTO: Codable {
    let id: String
    let dayKey: String
    let status: String
    let sleepQuality: Int?
    let energy: Int?
    let workoutDifficulty: Int?
    let note: String?
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct BodyWeightEntryDTO: Codable {
    let id: String
    let dayKey: String
    let value: Float
    let unit: String
    let source: String
    let measuredAt: Date
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct SupplementOccurrenceDTO: Codable {
    let id: String
    let occurrenceKey: String
    let dayKey: String
    let kind: String
    let status: String
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct MobilityFamilyDTO: Codable {
    let id: String
    let name: String
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct MobilityDefinitionDTO: Codable {
    let id: String
    let name: String
    let instructions: String?
    let trackingType: String
    let defaultDurationSeconds: Int?
    let defaultRepetitions: Int?
    let isFavorite: Bool
    let isCustom: Bool
    let isArchived: Bool
    let familyID: String?
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct MobilityPhasePrescriptionDTO: Codable {
    let id: String
    let orderIndex: Int
    let phaseType: String
    let durationSeconds: Int
    let contractionIntensity: String?
    let instructions: String?
    let side: String
}

nonisolated struct MobilityBreathingPrescriptionDTO: Codable {
    let targetBreaths: Int?
    let inhaleSeconds: Int?
    let exhaleSeconds: Int?
    let instructionKey: String?
}

nonisolated struct MobilityTempoPrescriptionDTO: Codable {
    let moveIntoRangeSeconds: Int?
    let holdSeconds: Int?
    let returnSeconds: Int?
    let pauseSeconds: Int?
}

nonisolated struct MobilityAssistancePrescriptionDTO: Codable {
    let assistanceType: String
    let level: Int?
    let equipment: String?
}

nonisolated struct MobilityRoutineItemDTO: Codable {
    let id: String
    let definitionID: String
    let orderIndex: Int
    let targetDurationSeconds: Int?
    let targetRepetitions: Int?
    var targetLoadValue: Double? = nil
    var targetLoadUnit: String? = nil
    var cycleCount: Int? = 1
    let side: String
    let restSeconds: Int?
    let notes: String?
    var phases: [MobilityPhasePrescriptionDTO]? = nil
    var method: String? = nil
    var trainingPurpose: String? = nil
    var breathingPrescription: MobilityBreathingPrescriptionDTO? = nil
    var tempoPrescription: MobilityTempoPrescriptionDTO? = nil
    var assistancePrescription: MobilityAssistancePrescriptionDTO? = nil
    var supportLevel: String? = nil
    var metricProfile: MobilityMetricProfile? = nil
    var metricTargets: MobilityMetricTargets? = nil
    var blockKey: String? = nil
    var sideStrategy: String? = nil
    var restPrescription: MobilityRestPrescription? = nil
}

nonisolated struct MobilityRoutineBlockDTO: Codable {
    let blockKey: String
    let orderIndex: Int
    var name: String? = nil
    let kind: String
    var targetRounds: Int? = nil
    var restPrescription: MobilityRestPrescription? = nil
}

nonisolated struct MobilityRoutineDTO: Codable {
    let id: String
    let name: String
    let notes: String?
    let isArchived: Bool
    let createdAt: Date
    let updatedAt: Date
    let items: [MobilityRoutineItemDTO]
    var purpose: String? = nil
    var blocks: [MobilityRoutineBlockDTO]? = nil
}

nonisolated struct MobilityPhaseResultDTO: Codable {
    let id: String
    let orderIndex: Int
    let phaseType: String
    let prescribedDurationSeconds: Int
    let performedDurationSeconds: Int?
    let cycleIndex: Int
    let side: String
    let prescribedIntensity: String?
    let performedIntensity: String?
    let status: String
    let startedAt: Date?
    let completedAt: Date?
}

nonisolated struct MobilityResultDTO: Codable {
    let id: String
    let side: String
    let status: String
    let prescribedDurationSeconds: Int?
    let prescribedRepetitions: Int?
    let performedDurationSeconds: Int?
    let performedRepetitions: Int?
    var performedLoadValue: Double? = nil
    var performedLoadUnit: String? = nil
    let perceivedIntensity: Int?
    let discomfortNote: String?
    let startedAt: Date?
    let completedAt: Date?
    var methodSnapshot: String? = nil
    var trainingPurposeSnapshot: String? = nil
    var sensation: String? = nil
    var movementQuality: String? = nil
    var compensationKeys: [String]? = nil
    var breathingPrescriptionSnapshot: MobilityBreathingPrescriptionDTO? = nil
    var tempoPrescriptionSnapshot: MobilityTempoPrescriptionDTO? = nil
    var assistancePrescriptionSnapshot: MobilityAssistancePrescriptionDTO? = nil
    var supportLevelSnapshot: String? = nil
    var performedBreathingCycles: Int? = nil
    var performedAssistanceLevel: Int? = nil
    var performedSupportLevel: String? = nil
    var metricProfileSnapshot: MobilityMetricProfile? = nil
    var metricTargetsSnapshot: MobilityMetricTargets? = nil
    var restSnapshot: MobilityRestPrescription? = nil
}

nonisolated struct MobilityEntryDTO: Codable {
    let id: String
    let orderIndex: Int
    let definitionIDSnapshot: String
    let definitionNameSnapshot: String
    let instructionsSnapshot: String?
    let trackingType: String
    let targetDurationSeconds: Int?
    let targetRepetitions: Int?
    var prescribedLoadValue: Double? = nil
    var prescribedLoadUnit: String? = nil
    var cycleCount: Int? = 1
    var currentCycleIndex: Int? = 0
    var currentPhaseIndex: Int? = 0
    let side: String
    let restSeconds: Int?
    let notesSnapshot: String?
    let timerStartedAt: Date?
    var pausedElapsedSeconds: Int? = 0
    let results: [MobilityResultDTO]
    var phaseResults: [MobilityPhaseResultDTO]? = nil
    var blockKeySnapshot: String? = nil
    var blockKindSnapshot: String? = nil
    var blockNameSnapshot: String? = nil
    var blockOrderIndexSnapshot: Int? = nil
    var blockTargetRoundsSnapshot: Int? = nil
    var blockRestSnapshot: MobilityRestPrescription? = nil
    var roundIndexSnapshot: Int? = 0
    var sideStrategySnapshot: String? = nil
    var restPrescriptionSnapshot: MobilityRestPrescription? = nil
}

nonisolated struct MobilitySessionDTO: Codable {
    let id: String
    let status: String
    let nameSnapshot: String
    let sourceRoutineID: String?
    let sourceRoutineName: String?
    let workoutID: String?
    let context: String
    let startTime: Date
    let endTime: Date?
    let currentEntryIndex: Int
    let createdAt: Date
    let updatedAt: Date
    let entries: [MobilityEntryDTO]
}

nonisolated struct MobilityAssessmentDefinitionDTO: Codable {
    let id: String
    let catalogueKey: String
    let name: String
    let nameLocalizationKey: String
    let instructionsLocalizationKey: String
    let setupInstructionsLocalizationKey: String
    let measurementDescriptionLocalizationKey: String
    let measurementLimitationsLocalizationKey: String
    let zone: String
    let definitionVersion: Int
    let preferredMode: String
    let manualMode: String
    let unit: String
    let supportedSides: [String]
    let setupKeys: [String]
    let defaultSetupKey: String
    let defaultIsActiveRange: Bool
    let sortOrder: Int
    let isArchived: Bool
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct MobilityAssessmentSampleDTO: Codable {
    let id: String
    let sampleCount: Int
    let median: Double
    let minimum: Double
    let maximum: Double
    let standardDeviation: Double
    let offAxisExcessDegrees: Double
    let captureDuration: TimeInterval
    let createdAt: Date
}

nonisolated struct MobilityAssessmentResultDTO: Codable {
    let id: String
    let orderIndex: Int
    let numericValue: Double?
    let criteria: String?
    let side: String
    let isWarm: Bool
    let setupKey: String
    let method: String
    let unit: String
    let isActiveRange: Bool
    let dayKey: String
    let source: String
    let confidence: String
    let definitionIDSnapshot: String
    let definitionCatalogueKeySnapshot: String
    let definitionNameSnapshot: String
    let definitionVersionSnapshot: Int
    let instructionsLocalizationKeySnapshot: String
    let setupInstructionsLocalizationKeySnapshot: String
    let measurementDescriptionLocalizationKeySnapshot: String
    let measurementLimitationsLocalizationKeySnapshot: String
    let createdAt: Date
    let updatedAt: Date
    let sample: MobilityAssessmentSampleDTO?
}

nonisolated struct MobilityAssessmentSessionDTO: Codable {
    let id: String
    let status: String
    let dayKey: String
    let selectedDefinitionKeys: [String]
    let skippedDefinitionKeys: [String]
    let currentDefinitionIndex: Int
    let startedAt: Date
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let results: [MobilityAssessmentResultDTO]
}

nonisolated struct FoodServingDTO: Codable {
    let id: String
    let name: String
    let amount: Double
    let unit: String
    let equivalentReferenceAmount: Double
}

nonisolated struct FoodItemDTO: Codable {
    let id: String
    let name: String
    let referenceAmount: Double
    let referenceUnit: String
    let calories: Double?
    let proteinGrams: Double?
    let carbohydrateGrams: Double?
    let fatGrams: Double?
    var caffeineMilligrams: Double? = nil
    var npn: String? = nil
    let sourceKind: String
    let confidence: String
    let preparationState: String
    let isFavorite: Bool
    let isArchived: Bool
    let createdAt: Date
    let updatedAt: Date
    var frenchName: String? = nil
    var categoryName: String? = nil
    var searchAliases: [String]? = nil
    let servings: [FoodServingDTO]
}

nonisolated struct MealTemplateItemDTO: Codable {
    let id: String
    let foodID: String
    let orderIndex: Int
    let servingID: String?
    let quantity: Double
}

nonisolated struct MealTemplateDTO: Codable {
    let id: String
    let lineageID: String
    let version: Int
    let name: String
    let preparationState: String
    let finalCookedWeightGrams: Double?
    let isCurrent: Bool
    let isArchived: Bool
    let createdAt: Date
    let updatedAt: Date
    let items: [MealTemplateItemDTO]
    /// Recipe recognition photo (v16+). `photoIdentifier` is the original
    /// per-install filename; `photoData` carries the compressed bytes so the
    /// image survives a restore onto a different device. Both are `nil` for
    /// recipes without a photo and for pre-v16 backups.
    var photoIdentifier: String? = nil
    var photoData: Data? = nil
}

nonisolated struct LoggedMealItemDTO: Codable {
    let id: String
    let orderIndex: Int
    let sourceFoodID: String?
    let foodNameSnapshot: String
    let servingNameSnapshot: String
    let quantity: Double
    let portionAmountSnapshot: Double
    let portionUnit: String
    let caloriesSnapshot: Double?
    let proteinGramsSnapshot: Double?
    let carbohydrateGramsSnapshot: Double?
    let fatGramsSnapshot: Double?
    var caffeineMilligramsSnapshot: Double? = nil
    let sourceKind: String
    let confidence: String
    let preparationState: String
}

nonisolated struct LoggedMealDTO: Codable {
    let id: String
    let dayKey: String
    let slot: String
    let loggedAt: Date
    let nameSnapshot: String
    let sourceMealTemplateID: String?
    let sourceMealTemplateName: String?
    let createdAt: Date
    let updatedAt: Date
    let items: [LoggedMealItemDTO]
}

nonisolated struct NutritionTargetDTO: Codable {
    let id: String
    let phase: String
    let effectiveStartDayKey: String
    let effectiveEndDayKey: String?
    let trainingCalories: Double?
    let trainingProteinGrams: Double?
    let trainingCarbohydrateGrams: Double?
    let trainingFatGrams: Double?
    let restCalories: Double?
    let restProteinGrams: Double?
    let restCarbohydrateGrams: Double?
    let restFatGrams: Double?
    let isArchived: Bool
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct RepeatingPlanSlotDTO: Codable {
    let id: String
    let orderIndex: Int
    let templateIDSnapshot: String
    let templateNameSnapshot: String
    /// The live relationship is deliberately optional: a run/definition can
    /// retain its source evidence after the reusable template was deleted.
    let workoutTemplateName: String?
    var preWorkoutMobilityRoutineName: String? = nil
    var preWorkoutMobilityRoutineIDSnapshot: String? = nil
    var preWorkoutMobilityRoutineNameSnapshot: String? = nil
    var postWorkoutMobilityRoutineName: String? = nil
    var postWorkoutMobilityRoutineIDSnapshot: String? = nil
    var postWorkoutMobilityRoutineNameSnapshot: String? = nil
}

nonisolated struct RepeatingPlanDTO: Codable {
    let id: String
    let name: String
    let goal: String
    let experienceLevel: String
    let requiredEquipment: [String]
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    let isArchived: Bool
    let isBuiltIn: Bool
    let slots: [RepeatingPlanSlotDTO]
}

nonisolated struct RepeatingPlanRunSlotDTO: Codable {
    let id: String
    let sourceSlotID: String
    let orderIndex: Int
    let templateIDSnapshot: String
    let templateNameSnapshot: String
    let workoutTemplateName: String?
    var preWorkoutMobilityRoutineName: String? = nil
    var preWorkoutMobilityRoutineIDSnapshot: String? = nil
    var preWorkoutMobilityRoutineNameSnapshot: String? = nil
    var postWorkoutMobilityRoutineName: String? = nil
    var postWorkoutMobilityRoutineIDSnapshot: String? = nil
    var postWorkoutMobilityRoutineNameSnapshot: String? = nil
}

nonisolated struct RepeatingPlanOccurrenceDTO: Codable {
    let id: String
    let cycleIndex: Int
    let expectedSlotIndex: Int
    let selectedSlotIndex: Int?
    let kind: String
    let continuationMode: String
    let status: String
    let cursorBefore: Int
    let cursorAfter: Int
    let cycleBefore: Int
    let cycleAfter: Int
    let createdAt: Date
    let startedAt: Date?
    let completedAt: Date?
    let undoneAt: Date?
    let completedWorkoutID: String?
}

nonisolated struct RepeatingPlanRunDTO: Codable {
    let id: String
    let sourcePlanID: String
    let sourcePlanName: String
    let status: String
    let currentSlotIndex: Int
    let completedCycleCount: Int
    let startedAt: Date
    let endedAt: Date?
    let updatedAt: Date
    let planID: String?
    let slots: [RepeatingPlanRunSlotDTO]
    let occurrences: [RepeatingPlanOccurrenceDTO]
}

nonisolated struct BackupDTO: Codable {
    let version: Int
    let preferences: PreferencesDTO
    let exercises: [ExerciseTemplateDTO]
    let templates: [WorkoutTemplateDTO]
    let collections: [WorkoutCollectionDTO]
    let workouts: [WorkoutDTO]
    let plans: [WorkoutPlanDTO]
    let planRuns: [PlanRunDTO]
    let repeatingPlans: [RepeatingPlanDTO]
    let repeatingPlanRuns: [RepeatingPlanRunDTO]
    let exerciseRelationships: [ExerciseRelationshipDTO]
    let programDefinitions: [ProgramDefinitionDTO]
    let progressionRecommendations: [ProgressionRecommendationDTO]
    let dailyLogEntries: [DailyLogEntryDTO]
    let bodyWeightEntries: [BodyWeightEntryDTO]
    let supplementOccurrences: [SupplementOccurrenceDTO]
    let mobilityFamilies: [MobilityFamilyDTO]
    let mobilityDefinitions: [MobilityDefinitionDTO]
    let mobilityRoutines: [MobilityRoutineDTO]
    let mobilitySessions: [MobilitySessionDTO]
    let mobilityAssessmentDefinitions: [MobilityAssessmentDefinitionDTO]
    let mobilityAssessmentSessions: [MobilityAssessmentSessionDTO]
    let foods: [FoodItemDTO]
    let mealTemplates: [MealTemplateDTO]
    let loggedMeals: [LoggedMealDTO]
    let nutritionTargets: [NutritionTargetDTO]
    let trainingProfile: TrainingProfileDTO?

    static let legacyVersion = 1
    static let planVersion = 2
    static let supersetVersion = 3
    static let programVersion = 5
    static let dailyContextVersion = 6
    static let mobilityVersion = 7
    static let nutritionVersion = 8
    static let bodyWeightVersion = 9
    static let strengthExpansionVersion = 10
    static let advancedMetricsVersion = 11
    static let formatSchemesVersion = 12
    static let complexComponentResultsVersion = 13
    // Adds the optional explicit template-exercise stimulus to portable
    // template semantics.
    static let templateStimulusVersion = 14
    // Adds each completed exercise entry's own historical identity snapshot
    // (name, exercise ID, tracking/laterality/rep-counting/weight-entry/
    // load-unit) so completed History survives a source rename, archival, or
    // duplicate-name coexistence independently of the live `exercise` link.
    static let historicalIdentitySnapshotVersion = 15
    // Adds an optional recipe recognition photo (identifier + compressed bytes)
    // to portable recipe data. Photos are non-nutrition thumbnails; older
    // backups simply restore with no photo.
    static let recipePhotoVersion = 16
    /// Adds the repeating-plan definition/run/occurrence graph and the
    /// repeating source identity carried by performed workouts.
    static let repeatingPlanVersion = 17
    /// Adds optional pre/post mobility-routine links to reusable workout
    /// templates plus immutable routine ID/name evidence on repeating
    /// definition and run slots.
    static let mobilityLinkageVersion = 18
    /// Adds decision provenance to progression recommendations: the resolved
    /// outcome (accepted / accepted-with-modified-value / declined), the
    /// applied load when it differs from the proposal, and the rule version
    /// snapshotted at recommendation time. v1–v18 restore with all three
    /// fields absent, which reads as "resolved without a recorded outcome."
    static let progressionReceiptVersion = 19
    /// Adds decision-aware substitution evidence: the structured replacement
    /// reason, the separate suitability and comparability verdicts, the
    /// explicit progression-transfer policy, the evaluation rule version, the
    /// confidence/missing-evidence state, the today-only versus future-plan
    /// scope, and the encoded evaluation snapshot — plus curation provenance
    /// and optional goal/role constraints on exercise relationships. v1–v19
    /// restore with every field absent; the legacy
    /// `substitutionSharesProgressionState` Boolean stays authoritative for
    /// progression in that case, so no old backup changes meaning.
    static let decisionAwareSubstitutionVersion = 20
    /// Adds immutable original schedule dates and explicit reschedule
    /// timestamps to plan-run progress. v1–v20 restore with both values
    /// absent, so legacy schedule provenance is never guessed.
    static let planScheduleEvidenceVersion = 21
    /// Adds the reusable mobility routine's intended purpose. Older backups
    /// restore as unclassified and never infer a value from session context.
    static let mobilityRoutinePurposeVersion = 22
    /// Adds localized progression-receipt reason keys and receipt-owned load
    /// units. Older records intentionally restore both as absent.
    static let progressionReceiptEvidenceVersion = 23
    /// Adds the system mobility-assessment catalogue plus manual assessment
    /// sessions, condition-complete result snapshots, and optional bounded raw
    /// samples. v1-v23 restore with this domain absent.
    static let mobilityAssessmentVersion = 24
    /// Adds the onboarding training profile: the lifter's stated discipline,
    /// goal, experience, schedule, equipment and emphasis. Preferences only —
    /// nothing here participates in a prescription — so v1–v24 restore with no
    /// profile and the app simply ranks plans without one.
    static let trainingProfileVersion = 25
    /// Adds advanced mobility method/purpose prescriptions and immutable,
    /// side-specific quality/sensation evidence. Older backups restore with
    /// no advanced evidence and never infer it from free-text notes.
    static let advancedMobilityEvidenceVersion = 26
    static let currentVersion = advancedMobilityEvidenceVersion

    init(
        version: Int,
        preferences: PreferencesDTO,
        exercises: [ExerciseTemplateDTO],
        templates: [WorkoutTemplateDTO],
        collections: [WorkoutCollectionDTO],
        workouts: [WorkoutDTO],
        plans: [WorkoutPlanDTO] = [],
        planRuns: [PlanRunDTO] = [],
        repeatingPlans: [RepeatingPlanDTO] = [],
        repeatingPlanRuns: [RepeatingPlanRunDTO] = [],
        exerciseRelationships: [ExerciseRelationshipDTO] = [],
        programDefinitions: [ProgramDefinitionDTO] = [],
        progressionRecommendations: [ProgressionRecommendationDTO] = [],
        dailyLogEntries: [DailyLogEntryDTO] = [],
        bodyWeightEntries: [BodyWeightEntryDTO] = [],
        supplementOccurrences: [SupplementOccurrenceDTO] = [],
        mobilityFamilies: [MobilityFamilyDTO] = [],
        mobilityDefinitions: [MobilityDefinitionDTO] = [],
        mobilityRoutines: [MobilityRoutineDTO] = [],
        mobilitySessions: [MobilitySessionDTO] = [],
        mobilityAssessmentDefinitions: [MobilityAssessmentDefinitionDTO] = [],
        mobilityAssessmentSessions: [MobilityAssessmentSessionDTO] = [],
        foods: [FoodItemDTO] = [],
        mealTemplates: [MealTemplateDTO] = [],
        loggedMeals: [LoggedMealDTO] = [],
        nutritionTargets: [NutritionTargetDTO] = [],
        trainingProfile: TrainingProfileDTO? = nil
    ) {
        self.version = version
        self.preferences = preferences
        self.exercises = exercises
        self.templates = templates
        self.collections = collections
        self.workouts = workouts
        self.plans = plans
        self.planRuns = planRuns
        self.repeatingPlans = repeatingPlans
        self.repeatingPlanRuns = repeatingPlanRuns
        self.exerciseRelationships = exerciseRelationships
        self.programDefinitions = programDefinitions
        self.progressionRecommendations = progressionRecommendations
        self.dailyLogEntries = dailyLogEntries
        self.bodyWeightEntries = bodyWeightEntries
        self.supplementOccurrences = supplementOccurrences
        self.mobilityFamilies = mobilityFamilies
        self.mobilityDefinitions = mobilityDefinitions
        self.mobilityRoutines = mobilityRoutines
        self.mobilitySessions = mobilitySessions
        self.mobilityAssessmentDefinitions = mobilityAssessmentDefinitions
        self.mobilityAssessmentSessions = mobilityAssessmentSessions
        self.foods = foods
        self.mealTemplates = mealTemplates
        self.loggedMeals = loggedMeals
        self.nutritionTargets = nutritionTargets
        self.trainingProfile = trainingProfile
    }

    private enum CodingKeys: String, CodingKey {
        case version, preferences, exercises, templates, collections, workouts, plans, planRuns, repeatingPlans, repeatingPlanRuns, exerciseRelationships, programDefinitions, progressionRecommendations, dailyLogEntries, bodyWeightEntries, supplementOccurrences, mobilityFamilies, mobilityDefinitions, mobilityRoutines, mobilitySessions, mobilityAssessmentDefinitions, mobilityAssessmentSessions, foods, mealTemplates, loggedMeals, nutritionTargets, trainingProfile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        preferences = try container.decode(PreferencesDTO.self, forKey: .preferences)
        exercises = try container.decode([ExerciseTemplateDTO].self, forKey: .exercises)
        templates = try container.decode([WorkoutTemplateDTO].self, forKey: .templates)
        collections = try container.decode([WorkoutCollectionDTO].self, forKey: .collections)
        workouts = try container.decode([WorkoutDTO].self, forKey: .workouts)
        plans = try container.decodeIfPresent([WorkoutPlanDTO].self, forKey: .plans) ?? []
        planRuns = try container.decodeIfPresent([PlanRunDTO].self, forKey: .planRuns) ?? []
        repeatingPlans = try container.decodeIfPresent([RepeatingPlanDTO].self, forKey: .repeatingPlans) ?? []
        repeatingPlanRuns = try container.decodeIfPresent([RepeatingPlanRunDTO].self, forKey: .repeatingPlanRuns) ?? []
        exerciseRelationships = try container.decodeIfPresent([ExerciseRelationshipDTO].self, forKey: .exerciseRelationships) ?? []
        programDefinitions = try container.decodeIfPresent([ProgramDefinitionDTO].self, forKey: .programDefinitions) ?? []
        progressionRecommendations = try container.decodeIfPresent([ProgressionRecommendationDTO].self, forKey: .progressionRecommendations) ?? []
        dailyLogEntries = try container.decodeIfPresent([DailyLogEntryDTO].self, forKey: .dailyLogEntries) ?? []
        bodyWeightEntries = try container.decodeIfPresent([BodyWeightEntryDTO].self, forKey: .bodyWeightEntries) ?? []
        supplementOccurrences = try container.decodeIfPresent([SupplementOccurrenceDTO].self, forKey: .supplementOccurrences) ?? []
        mobilityFamilies = try container.decodeIfPresent([MobilityFamilyDTO].self, forKey: .mobilityFamilies) ?? []
        mobilityDefinitions = try container.decodeIfPresent([MobilityDefinitionDTO].self, forKey: .mobilityDefinitions) ?? []
        mobilityRoutines = try container.decodeIfPresent([MobilityRoutineDTO].self, forKey: .mobilityRoutines) ?? []
        mobilitySessions = try container.decodeIfPresent([MobilitySessionDTO].self, forKey: .mobilitySessions) ?? []
        mobilityAssessmentDefinitions = try container.decodeIfPresent([MobilityAssessmentDefinitionDTO].self, forKey: .mobilityAssessmentDefinitions) ?? []
        mobilityAssessmentSessions = try container.decodeIfPresent([MobilityAssessmentSessionDTO].self, forKey: .mobilityAssessmentSessions) ?? []
        foods = try container.decodeIfPresent([FoodItemDTO].self, forKey: .foods) ?? []
        mealTemplates = try container.decodeIfPresent([MealTemplateDTO].self, forKey: .mealTemplates) ?? []
        loggedMeals = try container.decodeIfPresent([LoggedMealDTO].self, forKey: .loggedMeals) ?? []
        nutritionTargets = try container.decodeIfPresent([NutritionTargetDTO].self, forKey: .nutritionTargets) ?? []
        trainingProfile = try container.decodeIfPresent(TrainingProfileDTO.self, forKey: .trainingProfile)
    }
}
