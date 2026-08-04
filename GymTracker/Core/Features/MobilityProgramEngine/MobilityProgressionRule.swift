import Foundation

#if !GYMTRACKER_EXTENSION

/// What a triggered mobility progression rule proposes. Deliberately a much
/// smaller vocabulary than the workout engine's `ProgressionAction`: mobility
/// has no training max, wave, block, or exercise-catalog variation ladder in
/// this slice, so those concepts have no mobility equivalent to encode.
nonisolated enum MobilityProgressionAction: Codable, Hashable {
    case addDuration(seconds: Int)
    case addRepetitions(Int)
    case addCycle
    case addLoad(value: Double)
    case reduceAssistance
    case reduceSupport
    case advanceVariation
    case repeatPrescription
    case regressVariation
    case maintain
}

/// What performed evidence must show for a rule to fire. Every case reads
/// only immutable performed evidence or an explicit human decision
/// (`.userApproved`); none can be satisfied by tolerating more discomfort —
/// there is deliberately no "sensation above X" trigger.
nonisolated indirect enum MobilityProgressionTrigger: Codable, Hashable {
    case allRequiredWorkCompleted
    case targetCompletedForSessions(Int)
    case qualityAtLeast(MobilityMovementQuality)
    case sensationWithinTarget
    /// Requires a caller-supplied comparison against assessment history
    /// (see `MobilityProgressionPerformance.comparableAssessmentReached`).
    /// The evaluator never reads assessment records itself — assessment
    /// evidence must never silently drive progression — so this trigger can
    /// only fire when the caller has already made and vetted that
    /// comparison and chosen to pass it through.
    case comparableAssessmentReached
    case sideTargetsCompleted
    case userApproved
    case anyOf([MobilityProgressionTrigger])
    case allOf([MobilityProgressionTrigger])
}

/// One authored progression rule, owned by the `MobilityMovementOccurrenceDefinition`
/// it lives on (`progressionRules`). `applicationMode` reuses the workout
/// engine's domain-agnostic `ProgressionApplicationMode` — exactly like this
/// payload already reuses `MissedWorkoutPolicy`/`CompletionPolicy`/
/// `ProgramProvenance` — rather than forking an identical two-case enum.
///
/// The default is always `.recommendation`: mobility progression never
/// applies itself. A rule that sets `.automatic` is still evaluated the same
/// way; nothing in this slice's coordinator ever creates an automatic-mode
/// mobility rule, and no UI offers to author one.
nonisolated struct MobilityProgressionRuleDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var trigger: MobilityProgressionTrigger
    var action: MobilityProgressionAction
    var applicationMode: ProgressionApplicationMode
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        trigger: MobilityProgressionTrigger,
        action: MobilityProgressionAction,
        applicationMode: ProgressionApplicationMode = .recommendation,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.applicationMode = applicationMode
        self.isEnabled = isEnabled
    }
}

#endif
