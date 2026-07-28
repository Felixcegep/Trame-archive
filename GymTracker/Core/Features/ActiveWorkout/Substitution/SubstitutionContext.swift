import Foundation

/// Everything the evaluator is allowed to know about *today's* prescription.
///
/// Assembled entirely from data that already exists — the plan's goal, the
/// planned exercise's stimulus and role, the prescribed tracking and logging
/// semantics, the equipment the lifter says is available, and the structured
/// replacement reason they chose. There is deliberately no global lifter
/// profile, no "powerlifter / bodybuilder / normal" identity, and no inferred
/// intent: a hybrid lifter would be misclassified by any single role, and the
/// prescription in front of them is better context than a setting they picked
/// once at first launch.
struct SubstitutionContext: Equatable, Sendable {
    /// The plan's goal, when the workout came from one. `nil` for a free or
    /// template workout, which weakens goal-preservation evidence rather than
    /// substituting a guess.
    let goal: PlanGoal?
    let stimulus: TrainingStimulus?
    let role: ExerciseRole?
    let prescribedTracking: TrackingType
    let prescribedLaterality: Laterality
    let prescribedWeightEntryStyle: WeightEntryStyle
    let prescribedLoadUnitCount: Int
    /// `nil` means "the lifter has not told us what is available" — which is
    /// explicitly not the same as "everything is available". Unknown equipment
    /// can never hard-filter a candidate, and it costs confidence instead.
    let availableEquipment: Set<EquipmentType>?
    /// Positions the lifter has declared uncomfortable, used only when the
    /// reason is `.discomfort`.
    let uncomfortablePositions: Set<MovementPattern>
    let reason: SubstitutionReason

    init(
        goal: PlanGoal? = nil,
        stimulus: TrainingStimulus? = nil,
        role: ExerciseRole? = nil,
        prescribedTracking: TrackingType,
        prescribedLaterality: Laterality = .bilateral,
        prescribedWeightEntryStyle: WeightEntryStyle = .totalLoad,
        prescribedLoadUnitCount: Int = 1,
        availableEquipment: Set<EquipmentType>? = nil,
        uncomfortablePositions: Set<MovementPattern> = [],
        reason: SubstitutionReason
    ) {
        self.goal = goal
        self.stimulus = stimulus
        self.role = role
        self.prescribedTracking = prescribedTracking
        self.prescribedLaterality = prescribedLaterality
        self.prescribedWeightEntryStyle = prescribedWeightEntryStyle
        self.prescribedLoadUnitCount = prescribedLoadUnitCount
        self.availableEquipment = availableEquipment
        self.uncomfortablePositions = uncomfortablePositions
        self.reason = reason
    }

    /// Whether the prescription carries enough intent to judge goal
    /// preservation at all. A free workout with no stimulus and no goal does
    /// not, and the UI asks the lifter rather than inventing one.
    var hasSufficientIntent: Bool {
        goal != nil || stimulus != nil || role != nil
    }

    /// Builds today's context from a live entry. Reads only snapshots and the
    /// prescription already on the entry, so it stays correct even after the
    /// source plan is later edited.
    static func from(
        entry: ExerciseEntry,
        goal: PlanGoal?,
        reason: SubstitutionReason,
        availableEquipment: Set<EquipmentType>? = nil,
        uncomfortablePositions: Set<MovementPattern> = []
    ) -> SubstitutionContext {
        SubstitutionContext(
            goal: goal,
            stimulus: entry.stimulusSnapshot,
            role: entry.prescribedRole,
            prescribedTracking: entry.trackingTypeSnapshot,
            prescribedLaterality: entry.lateralitySnapshot,
            prescribedWeightEntryStyle: entry.weightEntryStyleSnapshot,
            prescribedLoadUnitCount: entry.loadUnitCountSnapshot,
            availableEquipment: availableEquipment,
            uncomfortablePositions: uncomfortablePositions,
            reason: reason
        )
    }
}
