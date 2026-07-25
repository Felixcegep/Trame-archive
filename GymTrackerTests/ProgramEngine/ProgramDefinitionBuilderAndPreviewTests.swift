import Foundation
import XCTest
@testable import GymTracker

final class ProgramDefinitionBuilderAndPreviewTests: XCTestCase {
    func testProgramDefinitionCodecRejectsInvalidImportedRecipes() throws {
        let valid = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "squat",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
            )
        ])
        let data = try ProgramDefinitionCodec.encode(valid)
        XCTAssertEqual(try ProgramDefinitionCodec.decode(data), valid)

        var invalid = valid
        invalid.name = ""
        XCTAssertThrowsError(try ProgramDefinitionCodec.encode(invalid)) { error in
            guard let codecError = error as? ProgramDefinitionCodecError,
                  case .validation(let issues) = codecError else {
                return XCTFail("Expected validation error")
            }
            XCTAssertTrue(issues.contains { $0.code == .emptyName })
        }
        XCTAssertThrowsError(try ProgramDefinitionCodec.decode(Data("not-json".utf8))) { error in
            XCTAssertEqual(error as? ProgramDefinitionCodecError, .malformed)
        }
    }

    func testProgramDefinitionBuilderCreatesAndReordersAValidRecipe() throws {
        var builder = ProgramDefinitionBuilder(name: "Builder Test", durationWeeks: 1)
        let block = builder.addBlock(name: "Strength", phaseType: .strength)
        let week = try builder.addWeek(toBlock: block, name: "Week 1")
        let workout = try builder.addWorkout(toBlock: block, week: week, name: "Day 1", dayOffset: 0)
        let first = try builder.addExercise(toBlock: block, week: week, workout: workout, exerciseID: UUID(), exposureKey: "squat")
        let second = try builder.addExercise(toBlock: block, week: week, workout: workout, exerciseID: UUID(), exposureKey: "bench")
        try builder.addSet(toBlock: block, week: week, workout: workout, exercise: first, prescription: SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5)))
        try builder.addSet(toBlock: block, week: week, workout: workout, exercise: second, prescription: SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(8)))
        try builder.moveExercise(fromBlock: block, week: week, workout: workout, from: 0, to: 2)

        let definition = try builder.build()
        let exercises = try XCTUnwrap(definition.blocks.first?.weeks.first?.workouts.first?.plannedExercises)
        XCTAssertEqual(exercises.map(\.exposureKey), ["bench", "squat"])
        XCTAssertEqual(exercises.map(\.orderIndex), [0, 1])
        XCTAssertEqual(exercises.last?.plannedSets.count, 1)
    }

    func testProgramDefinitionBuilderRetainsADeferredSourceBasedBackOff() throws {
        var builder = ProgramDefinitionBuilder(name: "Top set builder", durationWeeks: 1)
        let block = builder.addBlock(name: "Strength", phaseType: .strength)
        let week = try builder.addWeek(toBlock: block)
        let workout = try builder.addWorkout(toBlock: block, week: week, name: "Press", dayOffset: 0)
        let bench = try builder.addExercise(
            toBlock: block,
            week: week,
            workout: workout,
            exerciseID: UUID(),
            exposureKey: "bench"
        )
        try builder.addSet(
            toBlock: block,
            week: week,
            workout: workout,
            exercise: bench,
            prescription: SetPrescriptionDefinition(
                orderIndex: 0,
                role: .topSet,
                repetitions: .fixed(5)
            )
        )
        try builder.addSet(
            toBlock: block,
            week: week,
            workout: workout,
            exercise: bench,
            prescription: SetPrescriptionDefinition(
                orderIndex: 1,
                role: .backOff,
                repetitions: .fixed(5),
                load: LoadPrescription(
                    reference: .init(kind: .topSet, exposureKey: "bench"),
                    percentage: 0.9
                ),
                generatesAfterSourceCompletion: true
            )
        )

        let definition = try builder.build()
        let sets = try XCTUnwrap(
            definition.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first?.plannedSets
        )
        XCTAssertEqual(sets.count, 2)
        XCTAssertTrue(sets[1].generatesAfterSourceCompletion)
    }

    func testPolicyPresetsProduceValidatedDataOnlyRules() {
        for preset in ProgramPolicyPreset.allCases {
            let rules = preset.rules()
            XCTAssertFalse(rules.isEmpty, preset.rawValue)
            XCTAssertTrue(rules.allSatisfy { $0.version > 0 }, preset.rawValue)
        }
    }

    func testWaveAndAlternativeExposureDataRoundTripsAndValidates() throws {
        let mainID = UUID()
        let alternativeID = UUID()
        let waveSets = [
            SetPrescriptionDefinition(
                orderIndex: 0,
                repetitions: .fixed(2),
                load: LoadPrescription(reference: LoadReference(kind: .fixedLoad), fixedValue: 80)
            ),
            SetPrescriptionDefinition(
                orderIndex: 1,
                repetitions: .fixed(1),
                load: LoadPrescription(reference: LoadReference(kind: .fixedLoad), fixedValue: 85)
            )
        ]
        let definition = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: mainID,
                exposureKey: "clean-wave",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(3))],
                waves: [
                    ProgramWaveDefinition(orderIndex: 0, name: "Wave 1", plannedSets: waveSets),
                    ProgramWaveDefinition(orderIndex: 1, name: "Wave 2", plannedSets: waveSets.map { set in
                        var copy = set
                        copy.id = UUID()
                        copy.orderIndex += 2
                        return copy
                    })
                ],
                alternativeExerciseIDs: [alternativeID]
            )
        ])

        let data = try JSONEncoder().encode(definition)
        let decoded = try JSONDecoder().decode(ProgramDefinitionPayload.self, from: data)
        XCTAssertEqual(decoded, definition)
        XCTAssertTrue(ProgramDefinitionValidator.validate(decoded).isEmpty)
        XCTAssertEqual(decoded.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first?.waves.count, 2)
        XCTAssertEqual(decoded.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first?.alternativeExerciseIDs, [alternativeID])
    }

    func testProgramDefinitionPreviewFlattensEveryPlannedExposure() throws {
        let definition = ProgramFixtureCatalog.mixedAcceptance(exerciseIDs: [
            "squat": UUID(), "bench": UUID(), "row": UUID(), "plank": UUID(), "complex": UUID(), "clean": UUID(), "jerk": UUID()
        ])
        let rows = try ProgramDefinitionPreview.rows(for: definition)
        XCTAssertEqual(rows.count, 5)
        XCTAssertTrue(rows.contains { $0.roles.contains(.topSet) && $0.loadReferences.contains(.topSet) })
        XCTAssertTrue(rows.contains { $0.sets.contains { $0.generatesAfterSourceCompletion } })
        XCTAssertTrue(rows.contains { $0.repPrescriptions.contains { if case .sequence = $0 { return true }; return false } })
        XCTAssertTrue(rows.contains { !$0.transitions.isEmpty })
    }

    func testDeferredBackOffValidationRequiresABackOffWithASourceSetReference() {
        let invalidRole = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "bench",
                orderIndex: 0,
                plannedSets: [
                    SetPrescriptionDefinition(
                        orderIndex: 0,
                        role: .working,
                        repetitions: .fixed(5),
                        load: LoadPrescription(reference: .init(kind: .topSet, exposureKey: "bench")),
                        generatesAfterSourceCompletion: true
                    )
                ]
            )
        ])
        XCTAssertTrue(ProgramDefinitionValidator.validate(invalidRole).contains {
            $0.code == .invalidPrescriptionValue
        })

        let invalidReference = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "bench",
                orderIndex: 0,
                plannedSets: [
                    SetPrescriptionDefinition(
                        orderIndex: 0,
                        role: .backOff,
                        repetitions: .fixed(5),
                        load: LoadPrescription(reference: .init(kind: .previousOccurrence, exposureKey: "bench")),
                        generatesAfterSourceCompletion: true
                    )
                ]
            )
        ])
        XCTAssertTrue(ProgramDefinitionValidator.validate(invalidReference).contains {
            $0.code == .invalidLoadReference
        })
    }

    func testProgramDefinitionPreviewResolvesInitialLoadsAndDeloadMetadata() throws {
        let squatID = UUID()
        let definition = ProgramDefinitionPayload(
            name: "Preview Cycle",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [
                ProgramBlockDefinition(
                    orderIndex: 0,
                    name: "Deload",
                    phaseType: .deload,
                    deloadVolumeReductionPercent: 40,
                    deloadIntensityReductionPercent: 15,
                    weeks: [
                        ProgramWeekDefinition(
                            weekIndex: 0,
                            name: "Recovery Week",
                            workouts: [
                                ProgramWorkoutDefinition(
                                    orderIndex: 0,
                                    name: "Recovery",
                                    dayOffset: 2,
                                    role: "recovery",
                                    plannedExercises: [
                                        ProgramExerciseDefinition(
                                            exerciseID: squatID,
                                            exposureKey: "squat",
                                            orderIndex: 0,
                                            plannedSets: [
                                                SetPrescriptionDefinition(
                                                    orderIndex: 0,
                                                    role: .working,
                                                    repetitions: .fixed(5),
                                                    load: LoadPrescription(
                                                        reference: .init(kind: .trainingMax, exposureKey: "squat"),
                                                        percentage: 0.8,
                                                        rounding: .nearestIncrement(2.5)
                                                    ),
                                                    restSeconds: 120
                                                )
                                            ],
                                            initialTrainingMax: 200
                                        )
                                    ]
                                )
                            ]
                        )
                    ]
                )
            ]
        )

        let row = try XCTUnwrap(ProgramDefinitionPreview.rows(for: definition).first)
        XCTAssertEqual(row.phaseType, .deload)
        XCTAssertEqual(row.weekName, "Recovery Week")
        XCTAssertEqual(row.workoutRole, "recovery")
        XCTAssertEqual(row.dayOffset, 2)
        XCTAssertEqual(row.deloadVolumeReductionPercent, 40)
        XCTAssertEqual(row.deloadIntensityReductionPercent, 15)
        XCTAssertEqual(row.sets.first?.unroundedLoad ?? .nan, 160, accuracy: 0.001)
        XCTAssertEqual(row.sets.first?.prescribedLoad ?? .nan, 160, accuracy: 0.001)
        XCTAssertEqual(row.sets.first?.restSeconds, 120)
    }

    func testValidatorRejectsDeloadReductionsOutsideDeloadPhases() {
        let definition = ProgramDefinitionPayload(
            name: "Invalid Deload",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [
                ProgramBlockDefinition(
                    orderIndex: 0,
                    name: "Strength",
                    deloadVolumeReductionPercent: 95,
                    weeks: [
                        ProgramWeekDefinition(
                            weekIndex: 0,
                            workouts: [
                                ProgramWorkoutDefinition(
                                    orderIndex: 0,
                                    name: "Day",
                                    dayOffset: 0,
                                    plannedExercises: [
                                        ProgramExerciseDefinition(
                                            exerciseID: UUID(),
                                            exposureKey: "squat",
                                            orderIndex: 0,
                                            plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
                                        )
                                    ]
                                )
                            ]
                        )
                    ]
                )
            ]
        )

        let issues = ProgramDefinitionValidator.validate(definition)
        XCTAssertTrue(issues.contains { $0.path == "blocks[0].deloadVolumeReductionPercent" })
    }

    // MARK: - Preview coverage (moved from ProgramEngineTypesTests)

    func testWaveLoadingFixturePreservesStructuredWavesInPreview() throws {
        let rows = try ProgramDefinitionPreview.rows(for: ProgramFixtureCatalog.waveLoading(exerciseIDs: ["squat": UUID()]))
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.waveCount, 2)
        XCTAssertEqual(rows.first?.setCount, 2)
    }

}
