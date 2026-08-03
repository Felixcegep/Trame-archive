import Foundation

#if !GYMTRACKER_EXTENSION

/// The three initial bundled mobility plans (Release 9): "General Flexibility
/// Foundation", "Contract-Relax Lower Body", and "Active Range and End-Range
/// Control". Each is an original GymTracker plan anchored to general,
/// widely-taught guidelines (`.guidelineAnchoredOriginalProgram`) — never
/// presented as any organization's official program, and never a
/// reproduction of paid or branded content.
///
/// Every occurrence's `mobilityDefinitionID` is resolved by movement *name*
/// against the live `MobilityDefinition` catalogue at seed time (see
/// `MobilityProgramLibrarySeedData.seedBundledCatalog`), never authored as a
/// hardcoded UUID literal — `MobilityProgramCompiler` resolves that field
/// with a strict dictionary lookup against whatever `id` a device's own
/// catalogue rows actually carry, and that `id` is only stable *within* one
/// device's install, never as a cross-device constant.
nonisolated enum MobilityProgramLibraryData {
    static func payloads(movementIDsByName: [String: UUID]) throws -> [MobilityProgramDefinitionPayload] {
        [
            try generalFlexibilityFoundation(movementIDsByName: movementIDsByName),
            try contractRelaxLowerBody(movementIDsByName: movementIDsByName),
            try activeRangeAndEndRangeControl(movementIDsByName: movementIDsByName)
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
}

#endif
