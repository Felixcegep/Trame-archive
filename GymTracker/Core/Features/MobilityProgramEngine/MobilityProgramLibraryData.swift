import Foundation

#if !GYMTRACKER_EXTENSION

/// The seven bundled mobility plans. Release 9 shipped the first three:
/// "General Flexibility Foundation", "Contract-Relax Lower Body", and
/// "Active Range and End-Range Control". Release 11 adds four
/// advanced-specialization plans: "Loaded Flexibility Foundations", "Squat
/// Mobility Integration", "Overhead Mobility Integration", and "Front-Split
/// Assistance Ladder". Every plan is an original GymTracker plan anchored to
/// general, widely-taught guidelines (`.guidelineAnchoredOriginalProgram`) —
/// never presented as any organization's official program, and never a
/// reproduction of paid or branded content.
///
/// Every occurrence's `mobilityDefinitionID` is resolved by movement *name*
/// against the live `MobilityDefinition` catalogue at seed time (see
/// `MobilityProgramLibrarySeedData.seedBundledCatalog`), never authored as a
/// hardcoded UUID literal — `MobilityProgramCompiler` resolves that field
/// with a strict dictionary lookup against whatever `id` a device's own
/// catalogue rows actually carry, and that `id` is only stable *within* one
/// device's install, never as a cross-device constant.
///
/// The Release 11 plans follow this file's existing idiom exactly: movement
/// name resolution, per-week helper functions, week-indexed dosage arrays,
/// and the same `.guidelineAnchoredOriginalProgram` provenance discipline.
/// They deliberately reuse existing catalogue movements via `occurrenceLabel`
/// overrides wherever a spec name describes an already-seeded movement
/// (mirroring Release 9's own precedent); "Loaded Cossack Squat" is the one
/// genuinely new movement Release 11 adds, because the plan's whole premise
/// — externally loaded stretching — needs a catalogue entry distinct from
/// the existing bodyweight "Cossack Squat", the same way "Weighted Pancake
/// Hold" and "Goblet Deep-Squat Hold" already stand apart from their
/// bodyweight relatives.
nonisolated enum MobilityProgramLibraryData {
    static func payloads(movementIDsByName: [String: UUID]) throws -> [MobilityProgramDefinitionPayload] {
        [
            try generalFlexibilityFoundation(movementIDsByName: movementIDsByName),
            try contractRelaxLowerBody(movementIDsByName: movementIDsByName),
            try activeRangeAndEndRangeControl(movementIDsByName: movementIDsByName),
            try loadedFlexibilityFoundations(movementIDsByName: movementIDsByName),
            try squatMobilityIntegration(movementIDsByName: movementIDsByName),
            try overheadMobilityIntegration(movementIDsByName: movementIDsByName),
            try frontSplitAssistanceLadder(movementIDsByName: movementIDsByName)
        ]
    }

    private static func movementID(_ name: String, in movementIDsByName: [String: UUID]) throws -> UUID {
        guard let id = movementIDsByName[name] else {
            throw MobilityProgramLibrarySeedError.missingMovement(name)
        }
        return id
    }

    // MARK: - General Flexibility Foundation

    private static let generalFlexibilityFoundationID = UUID(uuidString: "3C6F1B2A-8E4D-4F2C-9A1B-5D2E6F7A8B90")!

    private struct FlexibilityMovementSpec {
        let occurrenceID: String
        let label: String
        let movementName: String
        let side: MobilitySide
        let sideStrategy: MobilitySideStrategy?
    }

    private static let generalFlexibilityMovements: [FlexibilityMovementSpec] = [
        FlexibilityMovementSpec(
            occurrenceID: "hamstring", label: "Hamstring Strap Stretch", movementName: "Hamstring Strap Stretch",
            side: .alternating, sideStrategy: .completeSideThenSwitch
        ),
        FlexibilityMovementSpec(
            occurrenceID: "hip-flexor", label: "Half-Kneeling Hip-Flexor Stretch",
            movementName: "Half-Kneeling Hip-Flexor Stretch", side: .alternating, sideStrategy: .completeSideThenSwitch
        ),
        FlexibilityMovementSpec(
            occurrenceID: "adductor", label: "Adductor Stretch", movementName: "Butterfly Stretch",
            side: .none, sideStrategy: nil
        ),
        FlexibilityMovementSpec(
            occurrenceID: "calf", label: "Calf Stretch", movementName: "Standing Calf Stretch",
            side: .alternating, sideStrategy: .completeSideThenSwitch
        ),
        FlexibilityMovementSpec(
            occurrenceID: "chest", label: "Doorway Chest Stretch", movementName: "Doorway Chest Stretch",
            side: .alternating, sideStrategy: .completeSideThenSwitch
        ),
        FlexibilityMovementSpec(
            occurrenceID: "lat", label: "Kneeling Lat Stretch", movementName: "Kneeling Lat Stretch",
            side: .none, sideStrategy: nil
        )
    ]

    private static func flexibilityOccurrences(
        movementIDsByName: [String: UUID],
        cycleCount: Int,
        durationSeconds: Int,
        breathing: MobilityBreathingPrescription?,
        firstOccurrenceNote: String?
    ) throws -> [MobilityMovementOccurrenceDefinition] {
        try generalFlexibilityMovements.enumerated().map { index, spec in
            MobilityMovementOccurrenceDefinition(
                occurrenceID: spec.occurrenceID,
                occurrenceLabel: spec.label,
                mobilityDefinitionID: try movementID(spec.movementName, in: movementIDsByName),
                orderIndex: index,
                purpose: .flexibilityDevelopment,
                sideStrategy: spec.sideStrategy,
                side: spec.side,
                method: .staticPassive,
                cycleCount: cycleCount,
                targets: MobilityMetricTargets(durationSeconds: .exact(durationSeconds)),
                breathingPrescription: breathing,
                notes: index == 0 ? firstOccurrenceNote : nil
            )
        }
    }

    private static func flexibilityWeek(
        weekIndex: Int,
        cycleCount: Int,
        durationSeconds: Int,
        breathing: MobilityBreathingPrescription?,
        weekNote: String?,
        movementIDsByName: [String: UUID]
    ) throws -> MobilityProgramWeekDefinition {
        let dayIndices = [0, 2, 4]
        var sessions: [MobilityPlannedSessionDefinition] = []
        for (sessionNumber, day) in dayIndices.enumerated() {
            let occurrences = try flexibilityOccurrences(
                movementIDsByName: movementIDsByName,
                cycleCount: cycleCount,
                durationSeconds: durationSeconds,
                breathing: breathing,
                firstOccurrenceNote: weekNote
            )
            sessions.append(
                MobilityPlannedSessionDefinition(
                    sessionKey: "gff-w\(weekIndex + 1)-s\(sessionNumber + 1)",
                    weekIndex: weekIndex,
                    dayIndex: day,
                    name: "General Flexibility Foundation — Week \(weekIndex + 1), Day \(sessionNumber + 1)",
                    purpose: .development,
                    recipe: MobilityRoutineRecipeDefinition(occurrences: occurrences)
                )
            )
        }
        return MobilityProgramWeekDefinition(weekIndex: weekIndex, name: "Week \(weekIndex + 1)", sessions: sessions)
    }

    private static func generalFlexibilityFoundation(
        movementIDsByName: [String: UUID]
    ) throws -> MobilityProgramDefinitionPayload {
        var weeks: [MobilityProgramWeekDefinition] = []
        weeks.append(try flexibilityWeek(
            weekIndex: 0, cycleCount: 2, durationSeconds: 30, breathing: nil, weekNote: nil,
            movementIDsByName: movementIDsByName
        ))
        weeks.append(try flexibilityWeek(
            weekIndex: 1, cycleCount: 2, durationSeconds: 30, breathing: nil, weekNote: nil,
            movementIDsByName: movementIDsByName
        ))
        weeks.append(try flexibilityWeek(
            weekIndex: 2, cycleCount: 3, durationSeconds: 30, breathing: nil,
            weekNote: "Alternative: 2 rounds of 45 seconds instead of 3 rounds of 30.",
            movementIDsByName: movementIDsByName
        ))
        weeks.append(try flexibilityWeek(
            weekIndex: 3, cycleCount: 3, durationSeconds: 30, breathing: nil,
            weekNote: "Alternative: 2 rounds of 45 seconds instead of 3 rounds of 30.",
            movementIDsByName: movementIDsByName
        ))
        weeks.append(try flexibilityWeek(
            weekIndex: 4, cycleCount: 2, durationSeconds: 45,
            breathing: MobilityBreathingPrescription(targetBreaths: 5),
            weekNote: "Optional: breathe slowly for about five breaths in each hold.",
            movementIDsByName: movementIDsByName
        ))
        weeks.append(try flexibilityWeek(
            weekIndex: 5, cycleCount: 2, durationSeconds: 30, breathing: nil,
            weekNote: "Reduced volume to close the block. Optional: reassess your range before finishing.",
            movementIDsByName: movementIDsByName
        ))

        return MobilityProgramDefinitionPayload(
            id: generalFlexibilityFoundationID,
            programKey: "general-flexibility-foundation",
            name: "General Flexibility Foundation",
            summary: "A six-week flexibility plan pairing static stretches for the hips, hamstrings, calves, chest, and lats — three short sessions a week.",
            durationWeeks: 6,
            supportedDaysPerWeek: [3],
            missedSessionPolicy: .shiftSequence,
            completionPolicy: .offerRestart(carryState: false),
            provenance: ProgramProvenance(
                kind: .guidelineAnchoredOriginalProgram,
                statement: "An original GymTracker plan built from widely taught static-stretching guidelines. It is not affiliated with, endorsed by, or a reproduction of any cited organization's program."
            ),
            sourceReferences: [
                ProgramSourceReference(
                    organizationOrAuthors: "American College of Sports Medicine",
                    title: "ACSM Guidelines for Exercise Testing and Prescription — Flexibility Training",
                    year: 2021,
                    sourceIdentifier: "acsm-guidelines-flexibility-training",
                    supports: [
                        "General static-stretch hold durations and weekly frequency used to shape this plan's progression"
                    ],
                    doesNotProvide: [
                        "This plan's specific movement selection",
                        "This plan's exact weekly schedule or session structure"
                    ]
                )
            ],
            blocks: [
                MobilityProgramBlockDefinition(orderIndex: 0, name: "Foundation", weeks: weeks)
            ]
        )
    }

    // MARK: - Contract-Relax Lower Body

    private static let contractRelaxLowerBodyID = UUID(uuidString: "7A2D4E6F-1B3C-4A5D-8E9F-0C1D2E3F4A5B")!

    private struct ContractRelaxMovementSpec {
        let occurrenceID: String
        let label: String
        let movementName: String
    }

    private static let contractRelaxMovements: [ContractRelaxMovementSpec] = [
        ContractRelaxMovementSpec(
            occurrenceID: "hamstring", label: "Hamstring Contract-Relax", movementName: "Hamstring Strap Stretch"
        ),
        ContractRelaxMovementSpec(
            occurrenceID: "hip-flexor", label: "Hip Flexor Contract-Relax",
            movementName: "Half-Kneeling Hip-Flexor Stretch"
        ),
        ContractRelaxMovementSpec(
            occurrenceID: "adductor", label: "Adductor Contract-Relax", movementName: "Butterfly Stretch"
        ),
        ContractRelaxMovementSpec(
            occurrenceID: "calf", label: "Calf Contract-Relax", movementName: "Standing Calf Stretch"
        )
    ]

    private static let contractRelaxMetricProfile = MobilityMetricProfile(
        supportedMetrics: [.duration, .contractionDuration, .cycles],
        defaultCompletionRule: .phaseSequenceCompleted,
        primaryProgressMetric: .cycles
    )

    /// Exactly the five phases the spec calls for: initial stretch (20s),
    /// contraction (3–5s, here fixed at 4s of moderate effort), relax (5s),
    /// deeper stretch (20–30s), rest (20–30s, fixed at 25s). The runtime
    /// materializes `cycleCount` repetitions of this same list per side (see
    /// `MobilitySessionService.phaseSnapshots`); there is no per-cycle
    /// duration override in the current schema, so week 3's "longer final
    /// hold" is approximated by authoring that week's deeper-stretch phase at
    /// the top of the prescribed range (30s) rather than true per-cycle
    /// asymmetry.
    private static func contractRelaxPhases(deeperStretchSeconds: Int) -> [MobilityProgramPhaseDefinition] {
        [
            MobilityProgramPhaseDefinition(
                orderIndex: 0, phaseType: .initialStretch, durationSeconds: 20,
                instructions: "Ease into a comfortable stretch, well short of your end range."
            ),
            MobilityProgramPhaseDefinition(
                orderIndex: 1, phaseType: .contraction, durationSeconds: 4, contractionIntensity: .moderate,
                instructions: "Gently contract the stretched muscle against light resistance, about 20–30% effort."
            ),
            MobilityProgramPhaseDefinition(
                orderIndex: 2, phaseType: .relax, durationSeconds: 5,
                instructions: "Fully relax the muscle."
            ),
            MobilityProgramPhaseDefinition(
                orderIndex: 3, phaseType: .deeperStretch, durationSeconds: deeperStretchSeconds,
                instructions: "Ease into a slightly deeper stretch using the relaxation."
            ),
            MobilityProgramPhaseDefinition(
                orderIndex: 4, phaseType: .rest, durationSeconds: 25,
                instructions: "Rest before the next cycle or side."
            )
        ]
    }

    private static func contractRelaxOccurrences(
        movementIDsByName: [String: UUID],
        cycleCount: Int,
        deeperStretchSeconds: Int,
        firstOccurrenceNote: String?
    ) throws -> [MobilityMovementOccurrenceDefinition] {
        try contractRelaxMovements.enumerated().map { index, spec in
            MobilityMovementOccurrenceDefinition(
                occurrenceID: spec.occurrenceID,
                occurrenceLabel: spec.label,
                mobilityDefinitionID: try movementID(spec.movementName, in: movementIDsByName),
                orderIndex: index,
                purpose: .flexibilityDevelopment,
                sideStrategy: .completeSideThenSwitch,
                side: .alternating,
                method: .contractRelax,
                cycleCount: cycleCount,
                targets: MobilityMetricTargets(),
                metricProfile: contractRelaxMetricProfile,
                phases: contractRelaxPhases(deeperStretchSeconds: deeperStretchSeconds),
                notes: index == 0 ? firstOccurrenceNote : nil
            )
        }
    }

    private static func contractRelaxWeek(
        weekIndex: Int,
        cycleCount: Int,
        deeperStretchSeconds: Int,
        weekNote: String?,
        movementIDsByName: [String: UUID]
    ) throws -> MobilityProgramWeekDefinition {
        let dayIndices = [0, 3]
        var sessions: [MobilityPlannedSessionDefinition] = []
        for (sessionNumber, day) in dayIndices.enumerated() {
            let occurrences = try contractRelaxOccurrences(
                movementIDsByName: movementIDsByName,
                cycleCount: cycleCount,
                deeperStretchSeconds: deeperStretchSeconds,
                firstOccurrenceNote: weekNote
            )
            sessions.append(
                MobilityPlannedSessionDefinition(
                    sessionKey: "crlb-w\(weekIndex + 1)-s\(sessionNumber + 1)",
                    weekIndex: weekIndex,
                    dayIndex: day,
                    name: "Contract-Relax Lower Body — Week \(weekIndex + 1), Day \(sessionNumber + 1)",
                    purpose: .development,
                    recipe: MobilityRoutineRecipeDefinition(occurrences: occurrences)
                )
            )
        }
        return MobilityProgramWeekDefinition(weekIndex: weekIndex, name: "Week \(weekIndex + 1)", sessions: sessions)
    }

    private static func contractRelaxLowerBody(
        movementIDsByName: [String: UUID]
    ) throws -> MobilityProgramDefinitionPayload {
        var weeks: [MobilityProgramWeekDefinition] = []
        weeks.append(try contractRelaxWeek(
            weekIndex: 0, cycleCount: 1, deeperStretchSeconds: 20, weekNote: "One cycle per side this week.",
            movementIDsByName: movementIDsByName
        ))
        weeks.append(try contractRelaxWeek(
            weekIndex: 1, cycleCount: 2, deeperStretchSeconds: 20, weekNote: "Two cycles per side.",
            movementIDsByName: movementIDsByName
        ))
        weeks.append(try contractRelaxWeek(
            weekIndex: 2, cycleCount: 2, deeperStretchSeconds: 30,
            weekNote: "Two cycles per side, with a longer final deeper-stretch hold.",
            movementIDsByName: movementIDsByName
        ))
        weeks.append(try contractRelaxWeek(
            weekIndex: 3, cycleCount: 1, deeperStretchSeconds: 20, weekNote: "Reduced volume to close the block.",
            movementIDsByName: movementIDsByName
        ))

        return MobilityProgramDefinitionPayload(
            id: contractRelaxLowerBodyID,
            programKey: "contract-relax-lower-body",
            name: "Contract-Relax Lower Body",
            summary: "A four-week PNF contract-relax plan for the hamstrings, hip flexors, adductors, and calves — two sessions a week.",
            durationWeeks: 4,
            supportedDaysPerWeek: [2],
            missedSessionPolicy: .shiftSequence,
            completionPolicy: .offerRestart(carryState: false),
            provenance: ProgramProvenance(
                kind: .guidelineAnchoredOriginalProgram,
                statement: "An original GymTracker plan built from the general contract-relax proprioceptive neuromuscular facilitation (PNF) technique described in the sports-science literature. It is not affiliated with, endorsed by, or a reproduction of any cited author's or organization's program."
            ),
            sourceReferences: [
                ProgramSourceReference(
                    organizationOrAuthors: "Sharman, M. J., Cresswell, A. G., & Riek, S.",
                    title: "Proprioceptive Neuromuscular Facilitation Stretching: Mechanisms and Clinical Implications",
                    year: 2006,
                    sourceIdentifier: "sharman-cresswell-riek-2006-pnf-stretching",
                    supports: [
                        "The general contract-relax phase structure (initial stretch, contraction, relax, deeper stretch, rest) and typical contraction/hold durations this plan's phases are built from"
                    ],
                    doesNotProvide: [
                        "This plan's specific movement selection",
                        "This plan's exact weekly cycle-count progression"
                    ]
                )
            ],
            blocks: [
                MobilityProgramBlockDefinition(orderIndex: 0, name: "Contract-Relax Progression", weeks: weeks)
            ]
        )
    }

    // MARK: - Active Range and End-Range Control

    private static let activeRangeEndRangeControlID = UUID(uuidString: "F1E2D3C4-B5A6-4978-8B6C-5D4E3F2A1B0C")!

    private struct ActiveRangeMovementSpec {
        let occurrenceID: String
        let label: String
        let movementName: String
        let method: MobilityMethod
        let purpose: MobilityTrainingPurpose
        let sideStrategy: MobilitySideStrategy
        let repetitions: MobilityIntTarget
        /// `false` for the one movement whose dosage the spec fixes at a
        /// constant "2×3" rather than the shared week-by-week ramp.
        let usesWeekProgression: Bool
        let needsHold: Bool
    }

    private static let activeRangeMovements: [ActiveRangeMovementSpec] = [
        ActiveRangeMovementSpec(
            occurrenceID: "hip-switch", label: "90/90 Hip Switch", movementName: "90/90 Hip Switch",
            method: .activeRange, purpose: .activeControl, sideStrategy: .alternateEachRepetition,
            repetitions: .range(6, 8), usesWeekProgression: true, needsHold: false
        ),
        ActiveRangeMovementSpec(
            occurrenceID: "hip-liftoff", label: "90/90 Lift-Off", movementName: "90/90 Lift-Off",
            method: .endRangeIsometric, purpose: .jointControl, sideStrategy: .completeSideThenSwitch,
            repetitions: .exact(5), usesWeekProgression: true, needsHold: true
        ),
        ActiveRangeMovementSpec(
            occurrenceID: "aslr", label: "Active Straight-Leg Raise", movementName: "Active Straight Leg Raise",
            method: .activeRange, purpose: .activeControl, sideStrategy: .completeSideThenSwitch,
            repetitions: .exact(6), usesWeekProgression: true, needsHold: false
        ),
        ActiveRangeMovementSpec(
            occurrenceID: "knee-to-wall", label: "Knee-to-Wall Mobilization",
            movementName: "Knee-to-Wall Ankle Mobilization", method: .activeRange, purpose: .jointControl,
            sideStrategy: .completeSideThenSwitch, repetitions: .exact(8), usesWeekProgression: true, needsHold: false
        ),
        ActiveRangeMovementSpec(
            occurrenceID: "wall-shoulder-liftoff", label: "Wall Shoulder Flexion Lift-Off",
            movementName: "Wall Shoulder Flexion Lift-Off", method: .endRangeIsometric, purpose: .jointControl,
            sideStrategy: .completeSideThenSwitch, repetitions: .exact(5), usesWeekProgression: true, needsHold: true
        ),
        ActiveRangeMovementSpec(
            occurrenceID: "hip-rotation", label: "Controlled Hip Rotation", movementName: "Controlled Hip Rotation",
            method: .controlledRotation, purpose: .jointControl, sideStrategy: .completeSideThenSwitch,
            repetitions: .exact(3), usesWeekProgression: false, needsHold: false
        )
    ]

    /// Week-indexed (0…5) shared cycle-count ramp: W1–2 two sets, W3–5 three
    /// sets, W6 reduced back to two. "Controlled Hip Rotation" ignores this —
    /// its spec dosage is a constant "2×3" with no stated progression.
    private static let activeRangeWeeklyCycleCount: [Int] = [2, 2, 3, 3, 3, 2]
    /// Week-indexed hold seconds for the two end-range-isometric lift-off
    /// movements: W1–2 three seconds, W3–4 four, W5 five, W6 back to three.
    private static let activeRangeWeeklyHoldSeconds: [Int] = [3, 3, 4, 4, 5, 3]
    private static let controlledHipRotationCycleCount = 2

    private static func activeRangeOccurrences(
        movementIDsByName: [String: UUID],
        weekIndex: Int,
        firstOccurrenceNote: String?
    ) throws -> [MobilityMovementOccurrenceDefinition] {
        let cycleCount = activeRangeWeeklyCycleCount[weekIndex]
        let holdSeconds = activeRangeWeeklyHoldSeconds[weekIndex]
        return try activeRangeMovements.enumerated().map { index, spec in
            MobilityMovementOccurrenceDefinition(
                occurrenceID: spec.occurrenceID,
                occurrenceLabel: spec.label,
                mobilityDefinitionID: try movementID(spec.movementName, in: movementIDsByName),
                orderIndex: index,
                purpose: spec.purpose,
                sideStrategy: spec.sideStrategy,
                side: .alternating,
                method: spec.method,
                cycleCount: spec.usesWeekProgression ? cycleCount : controlledHipRotationCycleCount,
                targets: MobilityMetricTargets(repetitions: spec.repetitions),
                tempoPrescription: spec.needsHold ? MobilityTempoPrescription(holdSeconds: holdSeconds) : nil,
                notes: index == 0 ? firstOccurrenceNote : nil
            )
        }
    }

    private static func activeRangeWeek(
        weekIndex: Int,
        weekNote: String?,
        movementIDsByName: [String: UUID]
    ) throws -> MobilityProgramWeekDefinition {
        let dayIndices = [0, 2, 4]
        var sessions: [MobilityPlannedSessionDefinition] = []
        for (sessionNumber, day) in dayIndices.enumerated() {
            let occurrences = try activeRangeOccurrences(
                movementIDsByName: movementIDsByName,
                weekIndex: weekIndex,
                firstOccurrenceNote: weekNote
            )
            sessions.append(
                MobilityPlannedSessionDefinition(
                    sessionKey: "arerc-w\(weekIndex + 1)-s\(sessionNumber + 1)",
                    weekIndex: weekIndex,
                    dayIndex: day,
                    name: "Active Range and End-Range Control — Week \(weekIndex + 1), Day \(sessionNumber + 1)",
                    purpose: .development,
                    recipe: MobilityRoutineRecipeDefinition(occurrences: occurrences)
                )
            )
        }
        return MobilityProgramWeekDefinition(weekIndex: weekIndex, name: "Week \(weekIndex + 1)", sessions: sessions)
    }

    private static func activeRangeAndEndRangeControl(
        movementIDsByName: [String: UUID]
    ) throws -> MobilityProgramDefinitionPayload {
        let weekNotes: [Int: String] = [
            5: "Reduced volume to close the block. Optional: retest your range this week."
        ]
        var weeks: [MobilityProgramWeekDefinition] = []
        for weekIndex in 0..<6 {
            weeks.append(try activeRangeWeek(
                weekIndex: weekIndex,
                weekNote: weekNotes[weekIndex],
                movementIDsByName: movementIDsByName
            ))
        }

        return MobilityProgramDefinitionPayload(
            id: activeRangeEndRangeControlID,
            programKey: "active-range-end-range-control",
            name: "Active Range and End-Range Control",
            summary: "A six-week plan building active hip, ankle, and shoulder range with end-range hold control — three sessions a week.",
            durationWeeks: 6,
            supportedDaysPerWeek: [3],
            missedSessionPolicy: .shiftSequence,
            completionPolicy: .offerRestart(carryState: false),
            provenance: ProgramProvenance(
                kind: .guidelineAnchoredOriginalProgram,
                statement: "An original GymTracker plan combining widely taught active-range-of-motion and end-range isometric control drills. It is not affiliated with, endorsed by, or a reproduction of any organization's branded methodology or paid program."
            ),
            sourceReferences: [
                ProgramSourceReference(
                    organizationOrAuthors: "National Academy of Sports Medicine",
                    title: "NASM Essentials of Personal Fitness Training — Flexibility and Active/Dynamic Range of Motion",
                    year: 2021,
                    sourceIdentifier: "nasm-essentials-active-dynamic-flexibility",
                    supports: [
                        "General guidance on active range-of-motion and end-range control training used to shape this plan's structure"
                    ],
                    doesNotProvide: [
                        "This plan's specific movement selection",
                        "This plan's exact weekly set, hold, and rep progression"
                    ]
                )
            ],
            blocks: [
                MobilityProgramBlockDefinition(orderIndex: 0, name: "Active Range Progression", weeks: weeks)
            ]
        )
    }

    // MARK: - Loaded Flexibility Foundations (Release 11)

    private static let loadedFlexibilityFoundationsID = UUID(uuidString: "A1B2C3D4-E5F6-4A1B-8C2D-3E4F5A6B7C8D")!

    private enum LoadedFlexibilityMetricKind {
        case repetitions
        case duration
    }

    private struct LoadedFlexibilityMovementSpec {
        let occurrenceID: String
        let label: String
        let movementName: String
        let side: MobilitySide
        let sideStrategy: MobilitySideStrategy?
        let metricKind: LoadedFlexibilityMetricKind
        /// `false` only for Full-Range Calf Raise: the one movement in this
        /// block the spec never describes as loaded, so it carries no load
        /// target, no load-approval progression rule, and a fixed dosage
        /// rather than the shared weekly ramp.
        let isExternallyLoaded: Bool
    }

    private static let loadedFlexibilityMovements: [LoadedFlexibilityMovementSpec] = [
        LoadedFlexibilityMovementSpec(
            occurrenceID: "jefferson-curl", label: "Light Jefferson Curl", movementName: "Jefferson Curl",
            side: .none, sideStrategy: nil, metricKind: .repetitions, isExternallyLoaded: true
        ),
        LoadedFlexibilityMovementSpec(
            occurrenceID: "pancake-hold", label: "Weighted Pancake Hold", movementName: "Weighted Pancake Hold",
            side: .none, sideStrategy: nil, metricKind: .duration, isExternallyLoaded: true
        ),
        LoadedFlexibilityMovementSpec(
            occurrenceID: "cossack-squat", label: "Loaded Cossack Squat", movementName: "Loaded Cossack Squat",
            side: .alternating, sideStrategy: .completeSideThenSwitch, metricKind: .repetitions, isExternallyLoaded: true
        ),
        LoadedFlexibilityMovementSpec(
            occurrenceID: "goblet-squat-hold", label: "Goblet Deep-Squat Hold", movementName: "Goblet Deep-Squat Hold",
            side: .none, sideStrategy: nil, metricKind: .duration, isExternallyLoaded: true
        ),
        LoadedFlexibilityMovementSpec(
            occurrenceID: "calf-raise", label: "Full-Range Calf Raise", movementName: "Full-Range Calf Raise",
            side: .none, sideStrategy: nil, metricKind: .repetitions, isExternallyLoaded: false
        )
    ]

    /// Week-indexed (0…5) shared set count: W1–2 and W3–5 hold three sets,
    /// W6 reduces to two to close the block.
    private static let loadedFlexibilityWeeklyCycleCount: [Int] = [3, 3, 3, 3, 3, 2]
    /// Week-indexed reps for the two loaded movements tracked by
    /// repetitions (Jefferson Curl, Cossack Squat): stable at W1–2, one
    /// additional rep from W3 on, back to baseline at the closing week.
    private static let loadedFlexibilityWeeklyRepetitions: [Int] = [5, 5, 6, 6, 6, 5]
    /// Week-indexed hold seconds for the two loaded movements tracked by
    /// duration (Weighted Pancake Hold, Goblet Deep-Squat Hold), same shape.
    private static let loadedFlexibilityWeeklyDurationSeconds: [Int] = [20, 20, 25, 25, 25, 20]
    /// Full-Range Calf Raise's fixed "3x6-8" dosage — the spec states no
    /// weekly progression for it, unlike the four loaded movements.
    private static let loadedFlexibilityCalfRaiseTarget = MobilityIntTarget.range(6, 8)
    private static let loadedFlexibilityLoadApprovalIncrementKilograms = 2.5

    private static func loadedFlexibilityOccurrences(
        movementIDsByName: [String: UUID],
        weekIndex: Int,
        firstOccurrenceNote: String?
    ) throws -> [MobilityMovementOccurrenceDefinition] {
        let cycleCount = loadedFlexibilityWeeklyCycleCount[weekIndex]
        let repetitions = MobilityIntTarget.exact(loadedFlexibilityWeeklyRepetitions[weekIndex])
        let duration = MobilityIntTarget.exact(loadedFlexibilityWeeklyDurationSeconds[weekIndex])
        return try loadedFlexibilityMovements.enumerated().map { index, spec in
            var targets = MobilityMetricTargets()
            switch spec.metricKind {
            case .repetitions:
                targets.repetitions = spec.isExternallyLoaded ? repetitions : loadedFlexibilityCalfRaiseTarget
            case .duration:
                targets.durationSeconds = duration
            }
            // A light external load is never fixed to a specific number —
            // the user picks conservative equipment they own — so the
            // target is `.open`: still a required, logged metric (see
            // `MobilityTrackingType.derivedMetricProfile`), just with no
            // authored numeric floor.
            if spec.isExternallyLoaded {
                targets.load = .open
            }
            return MobilityMovementOccurrenceDefinition(
                occurrenceID: spec.occurrenceID,
                occurrenceLabel: spec.label,
                // Progression never applies itself (`.recommendation` is
                // `MobilityProgressionRuleDefinition`'s default application
                // mode): a load increase only reaches the next session after
                // the user explicitly requests and approves a review — see
                // `MobilityProgressionRecommendationService
                // .requestApprovalReview`. Nothing in this plan ever sets
                // `.automatic`.
                progressionKey: spec.isExternallyLoaded ? "loaded-flexibility-\(spec.occurrenceID)-load" : nil,
                mobilityDefinitionID: try movementID(spec.movementName, in: movementIDsByName),
                orderIndex: index,
                purpose: .strengthAtLength,
                sideStrategy: spec.sideStrategy,
                side: spec.side,
                method: .loadedFlexibility,
                cycleCount: cycleCount,
                targets: targets,
                targetLoadUnit: spec.isExternallyLoaded ? .kilograms : nil,
                notes: index == 0 ? firstOccurrenceNote : nil,
                progressionRules: spec.isExternallyLoaded ? [
                    MobilityProgressionRuleDefinition(
                        trigger: .userApproved,
                        action: .addLoad(value: loadedFlexibilityLoadApprovalIncrementKilograms)
                    )
                ] : nil
            )
        }
    }

    private static func loadedFlexibilityWeek(
        weekIndex: Int,
        weekNote: String?,
        movementIDsByName: [String: UUID]
    ) throws -> MobilityProgramWeekDefinition {
        let dayIndices = [0, 3]
        var sessions: [MobilityPlannedSessionDefinition] = []
        for (sessionNumber, day) in dayIndices.enumerated() {
            let occurrences = try loadedFlexibilityOccurrences(
                movementIDsByName: movementIDsByName,
                weekIndex: weekIndex,
                firstOccurrenceNote: weekNote
            )
            sessions.append(
                MobilityPlannedSessionDefinition(
                    sessionKey: "lff-w\(weekIndex + 1)-s\(sessionNumber + 1)",
                    weekIndex: weekIndex,
                    dayIndex: day,
                    name: "Loaded Flexibility Foundations — Week \(weekIndex + 1), Day \(sessionNumber + 1)",
                    purpose: .development,
                    recipe: MobilityRoutineRecipeDefinition(occurrences: occurrences)
                )
            )
        }
        return MobilityProgramWeekDefinition(weekIndex: weekIndex, name: "Week \(weekIndex + 1)", sessions: sessions)
    }

    private static func loadedFlexibilityFoundations(
        movementIDsByName: [String: UUID]
    ) throws -> MobilityProgramDefinitionPayload {
        let weekNotes: [Int: String] = [
            0: "Weeks 1–2: pick a light, conservative load you can control through the full range — a plate, a light kettlebell, or a light dumbbell.",
            2: "Weeks 3–4: same load as weeks 1–2. Hold or repetitions increase slightly this week.",
            4: "Week 5: optional. If the last two weeks felt fully controlled with no stop signal, you can request a review to approve a small load increase for next session — never required.",
            5: "Reduced volume to close the block."
        ]
        var weeks: [MobilityProgramWeekDefinition] = []
        for weekIndex in 0..<6 {
            weeks.append(try loadedFlexibilityWeek(
                weekIndex: weekIndex,
                weekNote: weekNotes[weekIndex],
                movementIDsByName: movementIDsByName
            ))
        }

        return MobilityProgramDefinitionPayload(
            id: loadedFlexibilityFoundationsID,
            programKey: "loaded-flexibility-foundations",
            name: "Loaded Flexibility Foundations",
            summary: "An advanced six-week plan building strength through end range with light external load — two sessions a week. Best suited to lifters already comfortable with the unloaded version of each position.",
            durationWeeks: 6,
            supportedDaysPerWeek: [2],
            missedSessionPolicy: .shiftSequence,
            completionPolicy: .offerRestart(carryState: false),
            provenance: ProgramProvenance(
                kind: .guidelineAnchoredOriginalProgram,
                statement: "An original GymTracker plan applying general resistance-training load-progression guidelines to flexibility-at-length work. It is not affiliated with, endorsed by, or a reproduction of any cited organization's program."
            ),
            sourceReferences: [
                ProgramSourceReference(
                    organizationOrAuthors: "American College of Sports Medicine",
                    title: "ACSM Guidelines for Exercise Testing and Prescription — Resistance Training Load Progression",
                    year: 2021,
                    sourceIdentifier: "acsm-guidelines-resistance-training-load-progression",
                    supports: [
                        "General conservative-starting-load and gradual-progression principles this plan's load ramp is built from"
                    ],
                    doesNotProvide: [
                        "This plan's specific movement selection",
                        "This plan's exact weekly load, duration, and repetition progression",
                        "A specific starting load — that choice is always the user's, made conservatively and increased only with explicit approval"
                    ]
                )
            ],
            blocks: [
                MobilityProgramBlockDefinition(orderIndex: 0, name: "Loaded Flexibility", weeks: weeks)
            ]
        )
    }

    // MARK: - Preparation/development integration helpers (Squat & Overhead Mobility Integration)

    /// Shared authoring shape for the two Release 11 "integration" plans.
    /// Each plan schedules a short preparation sequence and a separate
    /// standalone development sequence as two distinct
    /// `MobilityPlannedSessionDefinition`s (distinct `sessionKey`s, distinct
    /// `purpose`s) rather than one mixed session, so a preparation
    /// repetition can never be counted as development volume — the two
    /// session graphs share no occurrence.
    private struct IntegrationMovementSpec {
        let occurrenceID: String
        let label: String
        let movementName: String
        let side: MobilitySide
        let sideStrategy: MobilitySideStrategy?
        let method: MobilityMethod
        let purpose: MobilityTrainingPurpose
        let target: MobilityMetricTargets
        let cycleCount: Int
        let tempoPrescription: MobilityTempoPrescription?

        init(
            occurrenceID: String,
            label: String,
            movementName: String,
            side: MobilitySide,
            sideStrategy: MobilitySideStrategy?,
            method: MobilityMethod,
            purpose: MobilityTrainingPurpose,
            target: MobilityMetricTargets,
            cycleCount: Int = 2,
            tempoPrescription: MobilityTempoPrescription? = nil
        ) {
            self.occurrenceID = occurrenceID
            self.label = label
            self.movementName = movementName
            self.side = side
            self.sideStrategy = sideStrategy
            self.method = method
            self.purpose = purpose
            self.target = target
            self.cycleCount = cycleCount
            self.tempoPrescription = tempoPrescription
        }
    }

    private static func integrationOccurrences(
        _ movements: [IntegrationMovementSpec],
        movementIDsByName: [String: UUID],
        firstOccurrenceNote: String?
    ) throws -> [MobilityMovementOccurrenceDefinition] {
        try movements.enumerated().map { index, spec in
            MobilityMovementOccurrenceDefinition(
                occurrenceID: spec.occurrenceID,
                occurrenceLabel: spec.label,
                mobilityDefinitionID: try movementID(spec.movementName, in: movementIDsByName),
                orderIndex: index,
                purpose: spec.purpose,
                sideStrategy: spec.sideStrategy,
                side: spec.side,
                method: spec.method,
                cycleCount: spec.cycleCount,
                targets: spec.target,
                tempoPrescription: spec.tempoPrescription,
                notes: index == 0 ? firstOccurrenceNote : nil
            )
        }
    }

    /// One week of an integration plan: `dayIndices.count` calendar days,
    /// each carrying one `.preparation`-purpose session and one
    /// `.development`-purpose session at distinct `sameDayOrder` slots.
    private static func integrationWeek(
        sessionKeyPrefix: String,
        programName: String,
        weekIndex: Int,
        dayIndices: [Int],
        preparationMovements: [IntegrationMovementSpec],
        developmentMovements: [IntegrationMovementSpec],
        movementIDsByName: [String: UUID]
    ) throws -> MobilityProgramWeekDefinition {
        var sessions: [MobilityPlannedSessionDefinition] = []
        for (sessionNumber, day) in dayIndices.enumerated() {
            let prepOccurrences = try integrationOccurrences(
                preparationMovements, movementIDsByName: movementIDsByName, firstOccurrenceNote: nil
            )
            sessions.append(
                MobilityPlannedSessionDefinition(
                    sessionKey: "\(sessionKeyPrefix)-w\(weekIndex + 1)-s\(sessionNumber + 1)-prep",
                    weekIndex: weekIndex,
                    dayIndex: day,
                    sameDayOrder: 0,
                    name: "\(programName) — Week \(weekIndex + 1), Day \(sessionNumber + 1) Preparation",
                    purpose: .preparation,
                    recipe: MobilityRoutineRecipeDefinition(occurrences: prepOccurrences)
                )
            )
            let devOccurrences = try integrationOccurrences(
                developmentMovements, movementIDsByName: movementIDsByName, firstOccurrenceNote: nil
            )
            sessions.append(
                MobilityPlannedSessionDefinition(
                    sessionKey: "\(sessionKeyPrefix)-w\(weekIndex + 1)-s\(sessionNumber + 1)-dev",
                    weekIndex: weekIndex,
                    dayIndex: day,
                    sameDayOrder: 1,
                    name: "\(programName) — Week \(weekIndex + 1), Day \(sessionNumber + 1) Development",
                    purpose: .development,
                    recipe: MobilityRoutineRecipeDefinition(occurrences: devOccurrences)
                )
            )
        }
        return MobilityProgramWeekDefinition(weekIndex: weekIndex, name: "Week \(weekIndex + 1)", sessions: sessions)
    }

    // MARK: - Squat Mobility Integration (Release 11)

    private static let squatMobilityIntegrationID = UUID(uuidString: "B2C3D4E5-F6A7-4B2C-9D3E-4F5A6B7C8D9E")!

    private static let squatIntegrationPreparationMovements: [IntegrationMovementSpec] = [
        IntegrationMovementSpec(
            occurrenceID: "knee-to-wall", label: "Knee-to-Wall Ankle Mobilization",
            movementName: "Knee-to-Wall Ankle Mobilization", side: .alternating, sideStrategy: .completeSideThenSwitch,
            method: .activeRange, purpose: .preparation, target: MobilityMetricTargets(repetitions: .exact(8))
        ),
        IntegrationMovementSpec(
            occurrenceID: "hip-switch", label: "90/90 Hip Switch", movementName: "90/90 Hip Switch",
            side: .alternating, sideStrategy: .alternateEachRepetition, method: .dynamic, purpose: .preparation,
            target: MobilityMetricTargets(repetitions: .exact(8))
        ),
        // Reuses the existing "Tactical Frog" movement — a hips-wide rock
        // back and forward into the adductors — rather than adding a
        // near-duplicate catalog entry; its instructions already describe
        // exactly what "Adductor Rock-Back" names.
        IntegrationMovementSpec(
            occurrenceID: "adductor-rock-back", label: "Adductor Rock-Back", movementName: "Tactical Frog",
            side: .none, sideStrategy: nil, method: .dynamic, purpose: .preparation,
            target: MobilityMetricTargets(repetitions: .exact(8))
        ),
        IntegrationMovementSpec(
            occurrenceID: "deep-squat-transition", label: "Deep-Squat Transition", movementName: "Deep-Squat Transition",
            side: .none, sideStrategy: nil, method: .dynamic, purpose: .preparation,
            target: MobilityMetricTargets(repetitions: .exact(8))
        )
    ]

    private static let squatIntegrationDevelopmentMovements: [IntegrationMovementSpec] = [
        IntegrationMovementSpec(
            occurrenceID: "soleus-stretch", label: "Soleus Stretch", movementName: "Soleus Wall Stretch",
            side: .alternating, sideStrategy: .completeSideThenSwitch, method: .staticPassive, purpose: .flexibilityDevelopment,
            target: MobilityMetricTargets(durationSeconds: .exact(30))
        ),
        IntegrationMovementSpec(
            occurrenceID: "hip-flexor-stretch", label: "Hip-Flexor Stretch", movementName: "Half-Kneeling Hip-Flexor Stretch",
            side: .alternating, sideStrategy: .completeSideThenSwitch, method: .staticPassive, purpose: .flexibilityDevelopment,
            target: MobilityMetricTargets(durationSeconds: .exact(30))
        ),
        IntegrationMovementSpec(
            occurrenceID: "active-hip-rotation", label: "Active Hip Rotation", movementName: "Controlled Hip Rotation",
            side: .alternating, sideStrategy: .completeSideThenSwitch, method: .controlledRotation, purpose: .activeControl,
            target: MobilityMetricTargets(repetitions: .exact(3))
        ),
        // Reuses "Deep Squat Pry" — an elbow-assisted hold at the bottom of
        // a squat — for "Supported Deep-Squat Hold" rather than adding a
        // near-duplicate catalog entry.
        IntegrationMovementSpec(
            occurrenceID: "supported-deep-squat-hold", label: "Supported Deep-Squat Hold", movementName: "Deep Squat Pry",
            side: .none, sideStrategy: nil, method: .staticActive, purpose: .flexibilityDevelopment,
            target: MobilityMetricTargets(durationSeconds: .exact(30))
        )
    ]

    private static func squatMobilityIntegration(
        movementIDsByName: [String: UUID]
    ) throws -> MobilityProgramDefinitionPayload {
        let dayIndices = [0, 2, 4]
        var weeks: [MobilityProgramWeekDefinition] = []
        for weekIndex in 0..<4 {
            weeks.append(try integrationWeek(
                sessionKeyPrefix: "smi",
                programName: "Squat Mobility Integration",
                weekIndex: weekIndex,
                dayIndices: dayIndices,
                preparationMovements: squatIntegrationPreparationMovements,
                developmentMovements: squatIntegrationDevelopmentMovements,
                movementIDsByName: movementIDsByName
            ))
        }

        return MobilityProgramDefinitionPayload(
            id: squatMobilityIntegrationID,
            programKey: "squat-mobility-integration",
            name: "Squat Mobility Integration",
            summary: "A four-week plan pairing a short squat-day preparation sequence with a separate standalone development session — three days a week. Preparation reps are never counted toward development volume.",
            durationWeeks: 4,
            supportedDaysPerWeek: [3],
            missedSessionPolicy: .shiftSequence,
            completionPolicy: .offerRestart(carryState: false),
            provenance: ProgramProvenance(
                kind: .guidelineAnchoredOriginalProgram,
                statement: "An original GymTracker plan combining widely taught movement-preparation warm-up guidance with separate standalone flexibility development work. It is not affiliated with, endorsed by, or a reproduction of any cited organization's program."
            ),
            sourceReferences: [
                ProgramSourceReference(
                    organizationOrAuthors: "National Academy of Sports Medicine",
                    title: "NASM Essentials of Personal Fitness Training — The Flexibility Continuum and General Warm-Up",
                    year: 2021,
                    sourceIdentifier: "nasm-essentials-flexibility-continuum-warmup-squat",
                    supports: [
                        "General guidance distinguishing brief movement-preparation warm-up work from standalone flexibility development training, informing this plan's separate preparation and development sessions"
                    ],
                    doesNotProvide: [
                        "This plan's specific movement selection",
                        "This plan's exact weekly schedule"
                    ]
                )
            ],
            blocks: [
                MobilityProgramBlockDefinition(orderIndex: 0, name: "Squat Integration", weeks: weeks)
            ]
        )
    }

    // MARK: - Overhead Mobility Integration (Release 11)

    private static let overheadMobilityIntegrationID = UUID(uuidString: "C3D4E5F6-A7B8-4C3D-8E4F-5A6B7C8D9E0F")!

    private static let overheadIntegrationPreparationMovements: [IntegrationMovementSpec] = [
        IntegrationMovementSpec(
            occurrenceID: "shoulder-pass-through", label: "Shoulder Pass-Through", movementName: "Shoulder Pass-Throughs",
            side: .none, sideStrategy: nil, method: .dynamic, purpose: .preparation,
            target: MobilityMetricTargets(repetitions: .exact(10))
        ),
        IntegrationMovementSpec(
            occurrenceID: "wall-slide", label: "Wall Slide", movementName: "Wall Slides",
            side: .none, sideStrategy: nil, method: .dynamic, purpose: .preparation,
            target: MobilityMetricTargets(repetitions: .exact(10))
        ),
        IntegrationMovementSpec(
            occurrenceID: "thoracic-rotation", label: "Thoracic Rotation", movementName: "Thoracic Rotation",
            side: .alternating, sideStrategy: .alternateEachRepetition, method: .dynamic, purpose: .preparation,
            target: MobilityMetricTargets(repetitions: .exact(8))
        ),
        IntegrationMovementSpec(
            occurrenceID: "scapular-pull-up", label: "Scapular Pull-Up", movementName: "Scapular Pull-Ups",
            side: .none, sideStrategy: nil, method: .dynamic, purpose: .preparation,
            target: MobilityMetricTargets(repetitions: .exact(10))
        )
    ]

    private static let overheadIntegrationDevelopmentMovements: [IntegrationMovementSpec] = [
        IntegrationMovementSpec(
            occurrenceID: "kneeling-lat-stretch", label: "Kneeling Lat Stretch", movementName: "Kneeling Lat Stretch",
            side: .none, sideStrategy: nil, method: .staticPassive, purpose: .flexibilityDevelopment,
            target: MobilityMetricTargets(durationSeconds: .exact(30))
        ),
        IntegrationMovementSpec(
            occurrenceID: "doorway-chest-stretch", label: "Doorway Chest Stretch", movementName: "Doorway Chest Stretch",
            side: .alternating, sideStrategy: .completeSideThenSwitch, method: .staticPassive, purpose: .flexibilityDevelopment,
            target: MobilityMetricTargets(durationSeconds: .exact(30))
        ),
        IntegrationMovementSpec(
            occurrenceID: "wall-flexion-liftoff", label: "Wall Flexion Lift-Off", movementName: "Wall Shoulder Flexion Lift-Off",
            side: .alternating, sideStrategy: .completeSideThenSwitch, method: .endRangeIsometric, purpose: .jointControl,
            target: MobilityMetricTargets(repetitions: .exact(5)), tempoPrescription: MobilityTempoPrescription(holdSeconds: 4)
        ),
        // Reuses "Shoulder CARs" (a slow, controlled articular circle) for
        // "Controlled Shoulder Rotation" rather than adding a near-duplicate
        // catalog entry.
        IntegrationMovementSpec(
            occurrenceID: "controlled-shoulder-rotation", label: "Controlled Shoulder Rotation", movementName: "Shoulder CARs",
            side: .alternating, sideStrategy: .completeSideThenSwitch, method: .controlledRotation, purpose: .jointControl,
            target: MobilityMetricTargets(repetitions: .exact(6))
        )
    ]

    private static func overheadMobilityIntegration(
        movementIDsByName: [String: UUID]
    ) throws -> MobilityProgramDefinitionPayload {
        let dayIndices = [0, 2, 4]
        var weeks: [MobilityProgramWeekDefinition] = []
        for weekIndex in 0..<4 {
            weeks.append(try integrationWeek(
                sessionKeyPrefix: "omi",
                programName: "Overhead Mobility Integration",
                weekIndex: weekIndex,
                dayIndices: dayIndices,
                preparationMovements: overheadIntegrationPreparationMovements,
                developmentMovements: overheadIntegrationDevelopmentMovements,
                movementIDsByName: movementIDsByName
            ))
        }

        return MobilityProgramDefinitionPayload(
            id: overheadMobilityIntegrationID,
            programKey: "overhead-mobility-integration",
            name: "Overhead Mobility Integration",
            summary: "A four-week plan pairing a short overhead-day preparation sequence with a separate standalone development session — three days a week. Preparation reps are never counted toward development volume.",
            durationWeeks: 4,
            supportedDaysPerWeek: [3],
            missedSessionPolicy: .shiftSequence,
            completionPolicy: .offerRestart(carryState: false),
            provenance: ProgramProvenance(
                kind: .guidelineAnchoredOriginalProgram,
                statement: "An original GymTracker plan combining widely taught movement-preparation warm-up guidance with separate standalone flexibility development work. It is not affiliated with, endorsed by, or a reproduction of any cited organization's program."
            ),
            sourceReferences: [
                ProgramSourceReference(
                    organizationOrAuthors: "National Academy of Sports Medicine",
                    title: "NASM Essentials of Personal Fitness Training — Scapulothoracic and Glenohumeral Mobility Preparation",
                    year: 2021,
                    sourceIdentifier: "nasm-essentials-scapulothoracic-glenohumeral-prep",
                    supports: [
                        "General guidance distinguishing brief movement-preparation warm-up work from standalone flexibility development training, informing this plan's separate preparation and development sessions"
                    ],
                    doesNotProvide: [
                        "This plan's specific movement selection",
                        "This plan's exact weekly schedule"
                    ]
                )
            ],
            blocks: [
                MobilityProgramBlockDefinition(orderIndex: 0, name: "Overhead Integration", weeks: weeks)
            ]
        )
    }

    // MARK: - Front-Split Assistance Ladder (Release 11)

    private static let frontSplitAssistanceLadderID = UUID(uuidString: "D4E5F6A7-B8C9-4D4E-9F5A-6B7C8D9E0F1A")!

    /// Support stages progress High → Medium → Low → Fingertip across the
    /// eight-week ladder, two weeks per stage. `.unsupported` is
    /// deliberately never authored anywhere in this file — reaching it is
    /// only ever an explicit, standalone user choice made outside a program
    /// run (e.g. hand-editing a personal routine), never something this
    /// plan or its progression rules can produce.
    ///
    /// No progression rule anywhere in this plan uses `.reduceSupport` or
    /// `.reduceAssistance`, and that is deliberate, not an oversight: the
    /// runtime's ladder clamp (`MobilityProgramRunCoordinator.supportLadder`
    /// / `.apply(_:to:)`) has no notion of "stop one stage early" — it only
    /// clamps to the array's bounds, and `.unsupported` is the last entry in
    /// that array. A `.reduceSupport` rule that kept firing across enough
    /// accepted recommendations (nothing caps how many times a
    /// session-count or user-approval trigger can re-fire across an
    /// eight-week run) could mathematically walk an occurrence's support
    /// level all the way to `.unsupported`. Keeping the stage ladder as
    /// fixed, week-indexed authored data — exactly like every other
    /// plan in this file expresses its own weekly dosage — is what
    /// guarantees that can never happen here.
    private static let frontSplitWeeklySupportLevel: [MobilitySupportLevel] = [
        .highBlocks, .highBlocks, .mediumBlocks, .mediumBlocks,
        .lowBlocks, .lowBlocks, .fingertipSupport, .fingertipSupport
    ]

    private static let frontSplitWeeklyAssistance: [MobilityAssistancePrescription?] = [
        MobilityAssistancePrescription(assistanceTypeRaw: MobilityAssistanceType.blocks.rawValue, level: 3, equipmentRaw: "High support blocks"),
        MobilityAssistancePrescription(assistanceTypeRaw: MobilityAssistanceType.blocks.rawValue, level: 3, equipmentRaw: "High support blocks"),
        MobilityAssistancePrescription(assistanceTypeRaw: MobilityAssistanceType.blocks.rawValue, level: 2, equipmentRaw: "Medium support blocks"),
        MobilityAssistancePrescription(assistanceTypeRaw: MobilityAssistanceType.blocks.rawValue, level: 2, equipmentRaw: "Medium support blocks"),
        MobilityAssistancePrescription(assistanceTypeRaw: MobilityAssistanceType.blocks.rawValue, level: 1, equipmentRaw: "Low support blocks"),
        MobilityAssistancePrescription(assistanceTypeRaw: MobilityAssistanceType.blocks.rawValue, level: 1, equipmentRaw: "Low support blocks"),
        // Fingertip support uses no blocks at all, so no assistance
        // equipment is authored for the last two weeks.
        nil,
        nil
    ]

    private static let frontSplitWeeklyCycleCount: [Int] = [2, 2, 3, 3, 3, 3, 2, 2]
    private static let frontSplitWeeklyHoldDurationSeconds: [Int] = [15, 20, 20, 25, 20, 25, 20, 25]
    private static let frontSplitWeeklyEndRangeHoldSeconds: [Int] = [5, 5, 6, 6, 7, 7, 8, 8]
    private static let frontSplitWeeklyLiftHoldSeconds: [Int] = [2, 2, 3, 3, 3, 3, 4, 4]

    private static func frontSplitOccurrences(
        movementIDsByName: [String: UUID],
        weekIndex: Int,
        firstOccurrenceNote: String?
    ) throws -> [MobilityMovementOccurrenceDefinition] {
        let supportLevel = frontSplitWeeklySupportLevel[weekIndex]
        let assistance = frontSplitWeeklyAssistance[weekIndex]
        let cycleCount = frontSplitWeeklyCycleCount[weekIndex]
        let holdDuration = frontSplitWeeklyHoldDurationSeconds[weekIndex]
        let endRangeHold = frontSplitWeeklyEndRangeHoldSeconds[weekIndex]
        let liftHold = frontSplitWeeklyLiftHoldSeconds[weekIndex]

        return [
            MobilityMovementOccurrenceDefinition(
                occurrenceID: "hip-flexor-prep",
                occurrenceLabel: "Hip-Flexor Preparation",
                mobilityDefinitionID: try movementID("Half-Kneeling Hip-Flexor Stretch", in: movementIDsByName),
                orderIndex: 0,
                purpose: .preparation,
                sideStrategy: .completeSideThenSwitch,
                side: .alternating,
                method: .staticPassive,
                cycleCount: 1,
                targets: MobilityMetricTargets(durationSeconds: .exact(20)),
                notes: firstOccurrenceNote
            ),
            MobilityMovementOccurrenceDefinition(
                occurrenceID: "hamstring-prep",
                occurrenceLabel: "Hamstring Preparation",
                mobilityDefinitionID: try movementID("Hamstring Strap Stretch", in: movementIDsByName),
                orderIndex: 1,
                purpose: .preparation,
                sideStrategy: .completeSideThenSwitch,
                side: .alternating,
                method: .staticPassive,
                cycleCount: 1,
                targets: MobilityMetricTargets(durationSeconds: .exact(20))
            ),
            // Each side (front leg) advances independently: `side:
            // .alternating` + `.completeSideThenSwitch` gives this
            // occurrence two independent `MobilityResult` rows per session
            // (never averaged), and — because `progressionKey` is set — two
            // independent `MobilityProgressionState(progressionKey, side:)`
            // rows (see `MobilityProgramRunCoordinator.seedProgressionStates`
            // and `MobilityProgressionRecommendationService
            // .evaluateAfterCompletion`, which both iterate
            // `occurrence.side.resultSides`). A leg that meets its hold
            // target for three sessions gets its own duration-increase
            // recommendation regardless of what the other leg is doing.
            MobilityMovementOccurrenceDefinition(
                occurrenceID: "supported-front-split-hold",
                occurrenceLabel: "Supported Front-Split Hold",
                progressionKey: "front-split-supported-hold-duration",
                mobilityDefinitionID: try movementID("Supported Front-Split Hold", in: movementIDsByName),
                orderIndex: 2,
                purpose: .flexibilityDevelopment,
                sideStrategy: .completeSideThenSwitch,
                side: .alternating,
                method: .staticPassive,
                cycleCount: cycleCount,
                targets: MobilityMetricTargets(durationSeconds: .exact(holdDuration)),
                assistancePrescription: assistance,
                supportLevel: supportLevel,
                progressionRules: [
                    MobilityProgressionRuleDefinition(
                        trigger: .targetCompletedForSessions(3),
                        action: .addDuration(seconds: 5)
                    )
                ]
            ),
            MobilityMovementOccurrenceDefinition(
                occurrenceID: "active-front-leg-lift",
                occurrenceLabel: "Active Front-Leg Lift",
                mobilityDefinitionID: try movementID("Active Front-Leg Lift", in: movementIDsByName),
                orderIndex: 3,
                purpose: .activeControl,
                sideStrategy: .completeSideThenSwitch,
                side: .alternating,
                method: .endRangeIsometric,
                cycleCount: cycleCount,
                targets: MobilityMetricTargets(repetitions: .exact(6)),
                tempoPrescription: MobilityTempoPrescription(holdSeconds: liftHold)
            ),
            // The same "Supported Front-Split Hold" movement appears a
            // second time here for the deeper, near-end-range isometric
            // variant — the same repeated-occurrence idiom this file's
            // occurrence-definition type already documents (two authored
            // prescriptions against one catalog movement, distinguished by
            // `occurrenceID`, never deduplicated by `mobilityDefinitionID`).
            // Its target is repetitions of short isometric holds rather than
            // one long hold, which is why it carries an explicit
            // `metricProfile`: the movement's own catalog `trackingType` is
            // `.duration`, and without an authored override the session's
            // default-derived completion rule would require a duration
            // entry this occurrence never prescribes.
            MobilityMovementOccurrenceDefinition(
                occurrenceID: "end-range-isometric",
                occurrenceLabel: "End-Range Isometric",
                progressionKey: "front-split-end-range-hold-repetitions",
                mobilityDefinitionID: try movementID("Supported Front-Split Hold", in: movementIDsByName),
                orderIndex: 4,
                purpose: .jointControl,
                sideStrategy: .completeSideThenSwitch,
                side: .alternating,
                method: .endRangeIsometric,
                cycleCount: cycleCount,
                targets: MobilityMetricTargets(repetitions: .exact(3)),
                metricProfile: MobilityMetricProfile(
                    supportedMetrics: [.repetitions],
                    defaultCompletionRule: .all([.repetitions]),
                    primaryProgressMetric: .repetitions
                ),
                assistancePrescription: assistance,
                supportLevel: supportLevel,
                tempoPrescription: MobilityTempoPrescription(holdSeconds: endRangeHold),
                progressionRules: [
                    MobilityProgressionRuleDefinition(
                        trigger: .targetCompletedForSessions(3),
                        action: .addRepetitions(1)
                    )
                ]
            )
        ]
    }

    private static func frontSplitWeek(
        weekIndex: Int,
        weekNote: String?,
        movementIDsByName: [String: UUID]
    ) throws -> MobilityProgramWeekDefinition {
        let dayIndices = [0, 2, 4]
        var sessions: [MobilityPlannedSessionDefinition] = []
        for (sessionNumber, day) in dayIndices.enumerated() {
            let occurrences = try frontSplitOccurrences(
                movementIDsByName: movementIDsByName,
                weekIndex: weekIndex,
                firstOccurrenceNote: sessionNumber == 0 ? weekNote : nil
            )
            sessions.append(
                MobilityPlannedSessionDefinition(
                    sessionKey: "fsal-w\(weekIndex + 1)-s\(sessionNumber + 1)",
                    weekIndex: weekIndex,
                    dayIndex: day,
                    name: "Front-Split Assistance Ladder — Week \(weekIndex + 1), Day \(sessionNumber + 1)",
                    purpose: .development,
                    recipe: MobilityRoutineRecipeDefinition(occurrences: occurrences)
                )
            )
        }
        return MobilityProgramWeekDefinition(weekIndex: weekIndex, name: "Week \(weekIndex + 1)", sessions: sessions)
    }

    private static func frontSplitAssistanceLadder(
        movementIDsByName: [String: UUID]
    ) throws -> MobilityProgramDefinitionPayload {
        let weekNotes: [Int: String] = [
            0: "Stage: high support blocks under both hands. This should feel controlled, never sharp — ease in.",
            2: "Stage: medium support blocks. Only move to this stage if the last one felt fully controlled.",
            4: "Stage: low support blocks.",
            6: "Stage: fingertip support only — the deepest stage this plan authors. Moving beyond fingertip support to a fully unsupported split is always your own explicit choice, never something this plan or its recommendations will do for you."
        ]
        var weeks: [MobilityProgramWeekDefinition] = []
        for weekIndex in 0..<8 {
            weeks.append(try frontSplitWeek(
                weekIndex: weekIndex,
                weekNote: weekNotes[weekIndex],
                movementIDsByName: movementIDsByName
            ))
        }

        return MobilityProgramDefinitionPayload(
            id: frontSplitAssistanceLadderID,
            programKey: "front-split-assistance-ladder",
            name: "Front-Split Assistance Ladder",
            summary: "An advanced eight-week plan lowering external support for the front split in stages — high blocks, medium blocks, low blocks, then fingertip support — three sessions a week. Each leg progresses on its own; the fully unsupported split is never scheduled by this plan and is only ever your own explicit choice.",
            durationWeeks: 8,
            supportedDaysPerWeek: [3],
            missedSessionPolicy: .shiftSequence,
            completionPolicy: .offerRestart(carryState: false),
            provenance: ProgramProvenance(
                kind: .guidelineAnchoredOriginalProgram,
                statement: "An original GymTracker plan built from the general principle that external assistance can be progressively reduced as controlled range improves. It is not affiliated with, endorsed by, or a reproduction of any cited author's or organization's program."
            ),
            sourceReferences: [
                ProgramSourceReference(
                    organizationOrAuthors: "Sharman, M. J., Cresswell, A. G., & Riek, S.",
                    title: "Proprioceptive Neuromuscular Facilitation Stretching: Mechanisms and Clinical Implications",
                    year: 2006,
                    sourceIdentifier: "sharman-cresswell-riek-2006-assisted-end-range",
                    supports: [
                        "The general principle that assisted, controlled end-range work can be used to safely build range, informing this plan's graduated external-support structure"
                    ],
                    doesNotProvide: [
                        "This plan's specific support-level stages, movement selection, or per-side ladder structure",
                        "Any recommendation to progress to an unsupported split — that step is always the user's own explicit choice"
                    ]
                )
            ],
            blocks: [
                MobilityProgramBlockDefinition(orderIndex: 0, name: "Assistance Ladder", weeks: weeks)
            ]
        )
    }
}

#endif
