import Foundation

#if !GYMTRACKER_EXTENSION

/// Capability identifiers a mobility program payload may require, mirroring
/// `EngineCapabilities` for the workout side. Deliberately starts empty: no
/// mobility-specific engine capability has shipped yet. Kept as its own set
/// (rather than reusing `EngineCapabilities`) because a workout engine
/// capability describing waves or velocity means nothing to a mobility
/// program, and a future mobility-only capability must not silently gate
/// workout program import or vice versa.
nonisolated enum MobilityEngineCapabilities {
    static let current: Set<String> = []

    static func missing(from requiredCapabilities: [String]) -> Set<String> {
        Set(requiredCapabilities).subtracting(current)
    }
}

/// One authored PNF-style phase inside a movement occurrence's prescription.
/// Mirrors `MobilityPhasePrescription`'s shape exactly; compiling a session
/// materializes fresh `MobilityPhasePrescription` rows from these, never
/// reusing this definition's own `id`.
nonisolated struct MobilityProgramPhaseDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var orderIndex: Int
    var phaseType: PNFPhaseType
    var durationSeconds: Int
    var contractionIntensity: ContractionIntensity?
    var instructions: String?
    var side: MobilitySide

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        phaseType: PNFPhaseType,
        durationSeconds: Int,
        contractionIntensity: ContractionIntensity? = nil,
        instructions: String? = nil,
        side: MobilitySide = .none
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.phaseType = phaseType
        self.durationSeconds = durationSeconds
        self.contractionIntensity = contractionIntensity
        self.instructions = instructions
        self.side = side
    }
}

/// A named container that groups occurrences within one session's recipe one
/// level deep, mirroring `MobilityRoutineBlock`'s shape. There is
/// deliberately no field here that could reference another block, matching
/// `MobilityRoutineBlock`'s own documented nesting guarantee: a block can
/// never contain a block.
nonisolated struct MobilityProgramRoutineBlockDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var blockKey: String
    var orderIndex: Int
    var name: String?
    var kind: MobilityBlockKind
    var targetRounds: Int?
    var restPrescription: MobilityRestPrescription?

    init(
        id: UUID = UUID(),
        blockKey: String,
        orderIndex: Int,
        name: String? = nil,
        kind: MobilityBlockKind,
        targetRounds: Int? = nil,
        restPrescription: MobilityRestPrescription? = nil
    ) {
        self.id = id
        self.blockKey = blockKey
        self.orderIndex = orderIndex
        self.name = name
        self.kind = kind
        self.targetRounds = targetRounds
        self.restPrescription = restPrescription
    }
}

/// One authored occurrence of a movement within a session's routine recipe.
///
/// The same `MobilityDefinition` may appear more than once in a session —
/// spec fixture "Knee-to-Wall — Preparation 2x8" and "Knee-to-Wall —
/// Development 3x30s" both reference the same movement with different
/// prescriptions and purposes. `occurrenceID` is the stable identity that
/// makes each occurrence distinct; it is never derived from
/// `mobilityDefinitionID`, and compilation must never deduplicate by that
/// reference.
nonisolated struct MobilityMovementOccurrenceDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    /// Stable authored identity for this occurrence, unique within its
    /// session. Distinct from `id` (a structural payload identity) so an
    /// author can reorder/re-author without losing the occurrence's own
    /// identity across catalogue edits.
    var occurrenceID: String
    var occurrenceLabel: String?
    /// Stable key progression state is keyed against, analogous to
    /// `ProgramExerciseDefinition.exposureKey`. Optional: not every mobility
    /// occurrence progresses.
    var progressionKey: String?
    /// Reference to a `MobilityDefinition` by stable identity. Resolved
    /// against the live catalogue at compile time, never at decode time.
    var mobilityDefinitionID: UUID
    var orderIndex: Int
    var purpose: MobilityTrainingPurpose?
    var sideStrategy: MobilitySideStrategy?
    var side: MobilitySide
    var method: MobilityMethod?
    var cycleCount: Int
    var targets: MobilityMetricTargets
    var targetLoadUnit: MobilityLoadUnit?
    var metricProfile: MobilityMetricProfile?
    var phases: [MobilityProgramPhaseDefinition]
    var breathingPrescription: MobilityBreathingPrescription?
    var tempoPrescription: MobilityTempoPrescription?
    var assistancePrescription: MobilityAssistancePrescription?
    var supportLevel: MobilitySupportLevel?
    var restPrescription: MobilityRestPrescription?
    /// Membership key into `MobilityRoutineRecipeDefinition.blocks`, or `nil`
    /// for an unblocked occurrence.
    var blockKey: String?
    var notes: String?
    /// Progression rules that evaluate against performed evidence carrying
    /// this occurrence's `progressionKey`. `nil` (not merely empty) is the
    /// wire shape every payload authored before this slice decodes as —
    /// Swift's synthesized `Decodable` treats an `Optional`-typed stored
    /// property as `decodeIfPresent`, so an older `MobilityProgramLibrary`
    /// payload with no `progressionRules` key at all still decodes without
    /// a custom `init(from:)`. Read through `resolvedProgressionRules`.
    var progressionRules: [MobilityProgressionRuleDefinition]?
    /// `MobilityAssessmentDefinition.catalogueKey` this occurrence's
    /// progress may be corroborated against, or `nil` (the default, and
    /// what every payload authored before this slice decodes as — same
    /// `Optional`-property `decodeIfPresent` synthesis as
    /// `progressionRules`). This is a read-only reference used only by
    /// `MobilityProgressionRecommendationService` to locate the right
    /// assessment history for `.comparableAssessmentReached` — it never
    /// makes an assessment observation into training evidence, and setting
    /// it does not by itself enable a rule; a `.comparableAssessmentReached`
    /// trigger must still be authored on `progressionRules` for this link to
    /// matter.
    var linkedAssessmentCatalogueKey: String?

    init(
        id: UUID = UUID(),
        occurrenceID: String,
        occurrenceLabel: String? = nil,
        progressionKey: String? = nil,
        mobilityDefinitionID: UUID,
        orderIndex: Int,
        purpose: MobilityTrainingPurpose? = nil,
        sideStrategy: MobilitySideStrategy? = nil,
        side: MobilitySide = .none,
        method: MobilityMethod? = nil,
        cycleCount: Int = 1,
        targets: MobilityMetricTargets = MobilityMetricTargets(),
        targetLoadUnit: MobilityLoadUnit? = nil,
        metricProfile: MobilityMetricProfile? = nil,
        phases: [MobilityProgramPhaseDefinition] = [],
        breathingPrescription: MobilityBreathingPrescription? = nil,
        tempoPrescription: MobilityTempoPrescription? = nil,
        assistancePrescription: MobilityAssistancePrescription? = nil,
        supportLevel: MobilitySupportLevel? = nil,
        restPrescription: MobilityRestPrescription? = nil,
        blockKey: String? = nil,
        notes: String? = nil,
        progressionRules: [MobilityProgressionRuleDefinition]? = nil,
        linkedAssessmentCatalogueKey: String? = nil
    ) {
        self.id = id
        self.occurrenceID = occurrenceID
        self.occurrenceLabel = occurrenceLabel
        self.progressionKey = progressionKey
        self.mobilityDefinitionID = mobilityDefinitionID
        self.orderIndex = orderIndex
        self.purpose = purpose
        self.sideStrategy = sideStrategy
        self.side = side
        self.method = method
        self.cycleCount = cycleCount
        self.targets = targets
        self.targetLoadUnit = targetLoadUnit
        self.metricProfile = metricProfile
        self.phases = phases
        self.breathingPrescription = breathingPrescription
        self.tempoPrescription = tempoPrescription
        self.assistancePrescription = assistancePrescription
        self.supportLevel = supportLevel
        self.restPrescription = restPrescription
        self.blockKey = blockKey
        self.notes = notes
        self.progressionRules = progressionRules
        self.linkedAssessmentCatalogueKey = linkedAssessmentCatalogueKey
    }
}

extension MobilityMovementOccurrenceDefinition {
    /// `progressionRules ?? []` in one place, so every reader (validator,
    /// coordinator, evaluator) treats an absent key and an authored-empty
    /// array identically.
    var resolvedProgressionRules: [MobilityProgressionRuleDefinition] {
        progressionRules ?? []
    }
}

/// The authored prescription for one planned session: an ordered list of
/// movement occurrences plus optional one-level-deep blocks grouping them.
/// This must be able to express everything the routine authoring surface can
/// already express for a standalone `MobilityRoutine`.
nonisolated struct MobilityRoutineRecipeDefinition: Codable, Hashable {
    var occurrences: [MobilityMovementOccurrenceDefinition]
    var blocks: [MobilityProgramRoutineBlockDefinition]

    init(
        occurrences: [MobilityMovementOccurrenceDefinition],
        blocks: [MobilityProgramRoutineBlockDefinition] = []
    ) {
        self.occurrences = occurrences
        self.blocks = blocks
    }
}

nonisolated struct MobilityPlannedSessionDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    /// Stable identity used to locate this session for compilation and
    /// scheduling, unique within its program.
    var sessionKey: String
    /// Mirrors the owning `MobilityProgramWeekDefinition.weekIndex`. Carried
    /// here too so a flattened session list (for scheduling/compilation) does
    /// not need its parent week in hand; the validator enforces the two stay
    /// equal.
    var weekIndex: Int
    var dayIndex: Int
    var sameDayOrder: Int
    var isOptional: Bool
    var name: String
    var purpose: MobilityRoutinePurpose?
    var recipe: MobilityRoutineRecipeDefinition

    init(
        id: UUID = UUID(),
        sessionKey: String,
        weekIndex: Int,
        dayIndex: Int,
        sameDayOrder: Int = 0,
        isOptional: Bool = false,
        name: String,
        purpose: MobilityRoutinePurpose? = nil,
        recipe: MobilityRoutineRecipeDefinition
    ) {
        self.id = id
        self.sessionKey = sessionKey
        self.weekIndex = weekIndex
        self.dayIndex = dayIndex
        self.sameDayOrder = sameDayOrder
        self.isOptional = isOptional
        self.name = name
        self.purpose = purpose
        self.recipe = recipe
    }
}

nonisolated struct MobilityProgramWeekDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var weekIndex: Int
    var name: String?
    var sessions: [MobilityPlannedSessionDefinition]

    init(
        id: UUID = UUID(),
        weekIndex: Int,
        name: String? = nil,
        sessions: [MobilityPlannedSessionDefinition]
    ) {
        self.id = id
        self.weekIndex = weekIndex
        self.name = name
        self.sessions = sessions
    }
}

/// A phase/mesocycle of the program, mirroring `ProgramBlockDefinition`'s
/// role on the workout side.
nonisolated struct MobilityProgramBlockDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var orderIndex: Int
    var name: String
    var weeks: [MobilityProgramWeekDefinition]

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        name: String,
        weeks: [MobilityProgramWeekDefinition]
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.name = name
        self.weeks = weeks
    }
}

/// The mobility domain's own program definition graph. This is intentionally
/// independent of `ProgramDefinitionPayload`/`WorkoutPlan`: a mobility
/// program never compiles into a `WorkoutPlan`, and the two graphs share only
/// the provenance/policy vocabulary already defined for the workout engine
/// (`ProgramProvenance`, `CompletionPolicy`, `MissedWorkoutPolicy`), reused
/// here rather than forked.
nonisolated struct MobilityProgramDefinitionPayload: Codable, Hashable, Identifiable {
    var id: UUID
    var schemaVersion: Int
    var templateVersion: Int
    var programKey: String
    var name: String
    var summary: String?
    var durationWeeks: Int
    var supportedDaysPerWeek: [Int]
    var missedSessionPolicy: MissedWorkoutPolicy
    var completionPolicy: CompletionPolicy
    var requiredCapabilities: [String]
    /// `nil` means a legacy or user-authored definition made no provenance
    /// claim. It must not be inferred as official, sourced, or synthetic.
    var provenance: ProgramProvenance?
    var sourceReferences: [ProgramSourceReference]?
    var blocks: [MobilityProgramBlockDefinition]

    init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        templateVersion: Int = 1,
        programKey: String = "",
        name: String,
        summary: String? = nil,
        durationWeeks: Int,
        supportedDaysPerWeek: [Int],
        missedSessionPolicy: MissedWorkoutPolicy = .shiftSequence,
        completionPolicy: CompletionPolicy = .end,
        requiredCapabilities: [String] = [],
        provenance: ProgramProvenance? = nil,
        sourceReferences: [ProgramSourceReference]? = nil,
        blocks: [MobilityProgramBlockDefinition]
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.templateVersion = templateVersion
        self.programKey = programKey
        self.name = name
        self.summary = summary
        self.durationWeeks = durationWeeks
        self.supportedDaysPerWeek = supportedDaysPerWeek
        self.missedSessionPolicy = missedSessionPolicy
        self.completionPolicy = completionPolicy
        self.requiredCapabilities = requiredCapabilities
        self.provenance = provenance
        self.sourceReferences = sourceReferences
        self.blocks = blocks
    }

    private enum CodingKeys: String, CodingKey {
        case id, schemaVersion, templateVersion, programKey, name, summary, durationWeeks,
             supportedDaysPerWeek, missedSessionPolicy, completionPolicy, requiredCapabilities,
             provenance, sourceReferences, blocks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        templateVersion = try container.decode(Int.self, forKey: .templateVersion)
        programKey = try container.decodeIfPresent(String.self, forKey: .programKey) ?? ""
        name = try container.decode(String.self, forKey: .name)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        durationWeeks = try container.decode(Int.self, forKey: .durationWeeks)
        supportedDaysPerWeek = try container.decode([Int].self, forKey: .supportedDaysPerWeek)
        missedSessionPolicy = try container.decodeIfPresent(MissedWorkoutPolicy.self, forKey: .missedSessionPolicy) ?? .shiftSequence
        completionPolicy = try container.decodeIfPresent(CompletionPolicy.self, forKey: .completionPolicy) ?? .end
        requiredCapabilities = try container.decodeIfPresent([String].self, forKey: .requiredCapabilities) ?? []
        provenance = try container.decodeIfPresent(ProgramProvenance.self, forKey: .provenance)
        sourceReferences = try container.decodeIfPresent([ProgramSourceReference].self, forKey: .sourceReferences)
        blocks = try container.decode([MobilityProgramBlockDefinition].self, forKey: .blocks)
    }
}

extension MobilityProgramDefinitionPayload {
    /// Every planned session across every block/week, in authored order. The
    /// compiler and scheduling integration both locate sessions through this
    /// rather than re-implementing the flatten.
    var flattenedSessions: [MobilityPlannedSessionDefinition] {
        blocks
            .sorted { $0.orderIndex < $1.orderIndex }
            .flatMap { block in
                block.weeks.sorted { $0.weekIndex < $1.weekIndex }
            }
            .flatMap { week in
                week.sessions.sorted { lhs, rhs in
                    lhs.dayIndex == rhs.dayIndex ? lhs.sameDayOrder < rhs.sameDayOrder : lhs.dayIndex < rhs.dayIndex
                }
            }
    }
}

#endif
