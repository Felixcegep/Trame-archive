import Foundation

/// The explicit, user-editable constraints for one personalized workout
/// request. This is intentionally a value type: generation must never hold a
/// live SwiftData model or mutate an active workout, template, plan, or run.
struct WorkoutGenerationRequest: Sendable {
    var requestText: String?
    var desiredDurationMinutes: Int?
    var selectedEquipment: Set<EquipmentType>
    var excludedExerciseIDs: Set<UUID>
    var preferredStimulus: TrainingStimulus?

    init(
        requestText: String? = nil,
        desiredDurationMinutes: Int? = nil,
        selectedEquipment: Set<EquipmentType> = [],
        excludedExerciseIDs: Set<UUID> = [],
        preferredStimulus: TrainingStimulus? = nil
    ) {
        self.requestText = requestText?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.desiredDurationMinutes = desiredDurationMinutes
        self.selectedEquipment = selectedEquipment
        self.excludedExerciseIDs = excludedExerciseIDs
        self.preferredStimulus = preferredStimulus
    }

    var isEmpty: Bool {
        requestText == nil
            && desiredDurationMinutes == nil
            && selectedEquipment.isEmpty
            && excludedExerciseIDs.isEmpty
            && preferredStimulus == nil
    }
}

/// Small, optional preferences that only influence future generated drafts.
/// They deliberately live outside `TrainingProfile`: onboarding answers remain
/// portable, while a lifter can remove these local drafting preferences without
/// changing programs, templates, active workouts, or historical evidence.
struct WorkoutGenerationPreferences: Codable, Sendable {
    var defaultDurationMinutes: Int?
    var preferredStimulus: TrainingStimulus?
    var avoidedExerciseIDs: Set<UUID>

    init(
        defaultDurationMinutes: Int? = nil,
        preferredStimulus: TrainingStimulus? = nil,
        avoidedExerciseIDs: Set<UUID> = []
    ) {
        self.defaultDurationMinutes = defaultDurationMinutes
        self.preferredStimulus = preferredStimulus
        self.avoidedExerciseIDs = avoidedExerciseIDs
    }
}

/// Immutable view of preferences the model may use. `nil` means the lifter
/// did not tell the app that fact; it is never converted into a made-up default.
struct WorkoutGenerationProfileSnapshot: Sendable {
    var experienceLevel: ProfileExperienceLevel?
    var primaryGoal: TrainingGoalPreference?
    var preferredDurationMinutes: Int?
    var availableEquipment: Set<EquipmentType>
    var avoidedExerciseIDs: Set<UUID>
    var preferredStimulus: TrainingStimulus?

    static let empty = WorkoutGenerationProfileSnapshot(
        experienceLevel: nil,
        primaryGoal: nil,
        preferredDurationMinutes: nil,
        availableEquipment: [],
        avoidedExerciseIDs: [],
        preferredStimulus: nil
    )
}

/// A compact exercise record the generator is allowed to select. The UUID is
/// the only authoritative identity; names exist solely for model context and
/// review copy.
struct WorkoutGenerationExerciseOption: Sendable, Identifiable {
    var exerciseID: UUID
    var name: String
    var frenchName: String?
    var trackingType: TrackingType
    var equipmentType: EquipmentType?
    var primaryMuscles: [Muscle]
    var secondaryMuscles: [Muscle]
    var movementPattern: MovementPattern?
    var difficulty: Difficulty?
    var isFavorite: Bool

    var id: UUID { exerciseID }
}

/// Derived evidence from completed history. It is deliberately summary-only:
/// generation may avoid obvious repetition, but it cannot reinterpret sets,
/// loads, recovery, or progression from mutable source definitions.
struct WorkoutGenerationRecentTrainingSummary: Sendable {
    struct ExerciseExposure: Sendable {
        var exerciseID: UUID
        var lastPerformedAt: Date
        var completedWorkoutCount: Int
    }

    var since: Date
    var exposures: [ExerciseExposure]

    static func empty(since: Date) -> WorkoutGenerationRecentTrainingSummary {
        WorkoutGenerationRecentTrainingSummary(since: since, exposures: [])
    }
}

/// Prompt-safe snapshot of an existing template. It teaches valid local
/// prescription shape, not a command to duplicate a template or modify it.
struct WorkoutGenerationExample: Sendable {
    struct Exercise: Sendable {
        var exerciseID: UUID
        var name: String
        var sets: Int
        var minimumRepetitions: Int
        var maximumRepetitions: Int
        var restSeconds: Int
        var targetRIR: Int?
        var targetRPE: Double?
        var supersetGroupID: String?
    }

    var name: String
    var exercises: [Exercise]
}

/// Complete immutable payload for one model call. It contains no live model
/// objects, which makes cancellation and validation independent of SwiftData.
struct WorkoutGenerationInput: Sendable {
    var request: WorkoutGenerationRequest
    var profile: WorkoutGenerationProfileSnapshot
    var availableExercises: [WorkoutGenerationExerciseOption]
    var recentTraining: WorkoutGenerationRecentTrainingSummary
    var examples: [WorkoutGenerationExample]
}

/// Raw structured output from a `WorkoutDraftGenerator`. It is not safe to
/// persist or start until `WorkoutDraftValidator` resolves it against the
/// current, non-archived exercise catalogue.
struct GeneratedWorkoutExercise: Sendable, Hashable {
    var exerciseID: UUID
    var sets: Int
    var minimumRepetitions: Int?
    var maximumRepetitions: Int?
    var restSeconds: Int
    var targetRIR: Int?
    var targetRPE: Double?
    var notes: String?
    var groupID: String?
}

struct GeneratedWorkoutDraft: Sendable, Hashable {
    var name: String
    var estimatedDurationMinutes: Int
    var rationale: String
    var exercises: [GeneratedWorkoutExercise]
    var assumptions: [String]
    var warnings: [String]
}

/// A model output resolved to a currently live `Exercise`. The UI can convert
/// these values into its existing template-editor selection without allowing
/// generated content to bypass its ordinary save/start paths.
@MainActor
struct ValidatedWorkoutExercise {
    var exercise: Exercise
    var targetSets: Int
    var repRangeMinimum: Int
    var repRangeMaximum: Int
    var restSeconds: Int
    var targetRIR: Int?
    var targetRPE: Double?
    var notes: String?
    var supersetGroupID: UUID?
}

@MainActor
struct ValidatedWorkoutDraft {
    var name: String
    var estimatedDurationMinutes: Int
    var rationale: String
    var exercises: [ValidatedWorkoutExercise]
    var assumptions: [String]
    var warnings: [String]
    var validationWarnings: [WorkoutDraftValidationWarning]
}

enum WorkoutDraftValidationWarning: Hashable, Sendable {
    case ignoredUnknownOrArchivedExercise(UUID)
    case ignoredDuplicateExercise(UUID)
    case adjustedPrescription(UUID)
    case removedInvalidSuperset(String)
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
