#if DEBUG
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class StrengthStabilityProgramSeederTests: XCTestCase {
    func testSeedCreatesRepeatingPlanTemplatesAndMobility() throws {
        let context = try makeSeededContext()

        try StrengthStabilityProgramSeeder.seed(in: context)

        let plans = try context.fetch(FetchDescriptor<RepeatingPlan>())
        XCTAssertEqual(plans.count, 1)
        let plan = try XCTUnwrap(plans.first)
        XCTAssertEqual(plan.name, StrengthStabilityProgramSeeder.planName)
        XCTAssertFalse(plan.isBuiltIn)
        XCTAssertEqual(plan.goal, .generalStrength)
        XCTAssertEqual(plan.experienceLevel, .intermediate)
        XCTAssertEqual(plan.orderedSlots.map(\.templateNameSnapshot), StrengthStabilityProgramSeeder.templateNames)

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        XCTAssertEqual(templates.count, 4)
        XCTAssertTrue(templates.allSatisfy { $0.preWorkoutMobilityRoutine != nil })
        XCTAssertTrue(templates.allSatisfy { ($0.preWorkoutMobilityRoutine?.orderedItems.isEmpty == false) })

        let ohpTemplate = try XCTUnwrap(templates.first { $0.name == "Upper / OHP" })
        let overheadPress = try XCTUnwrap(ohpTemplate.orderedTemplateExercises.first { $0.exercise.name == "Overhead Press" })
        XCTAssertEqual(overheadPress.targetSets, 4)
        XCTAssertEqual(overheadPress.repRangeMinimum, 5)
        XCTAssertEqual(overheadPress.repRangeMaximum, 6)
        XCTAssertEqual(overheadPress.stimulus, .strength)

        let squatTemplate = try XCTUnwrap(templates.first { $0.name == "Lower / Quads + Abductors" })
        let squat = try XCTUnwrap(squatTemplate.orderedTemplateExercises.first { $0.exercise.name == "High-Bar Back Squat" })
        XCTAssertEqual(squat.targetSets, 4)
        XCTAssertEqual(squat.repRangeMinimum, 5)
        XCTAssertEqual(squat.repRangeMaximum, 5)

        let benchTemplate = try XCTUnwrap(templates.first { $0.name == "Upper / Bench" })
        let bench = try XCTUnwrap(benchTemplate.orderedTemplateExercises.first { $0.exercise.name == "Bench Press" })
        XCTAssertEqual(bench.targetSets, 4)
        XCTAssertEqual(bench.repRangeMinimum, 5)
        XCTAssertEqual(bench.repRangeMaximum, 6)

        let posteriorTemplate = try XCTUnwrap(templates.first { $0.name == "Posterior Chain / Deadlift + Abductors" })
        let deadlift = try XCTUnwrap(posteriorTemplate.orderedTemplateExercises.first { $0.exercise.name == "Deadlift" })
        XCTAssertEqual(deadlift.targetSets, 3)
        XCTAssertEqual(deadlift.repRangeMinimum, 5)
        XCTAssertEqual(deadlift.repRangeMaximum, 5)
        XCTAssertEqual(deadlift.targetRPE, 6.5)
        XCTAssertTrue(posteriorTemplate.orderedTemplateExercises.contains { $0.exercise.name == "Pallof Press" })

        let routines = try context.fetch(FetchDescriptor<MobilityRoutine>())
        XCTAssertEqual(routines.count, 5)
        XCTAssertTrue(routines.contains { $0.name == "Strength & Stability recovery" })
    }

    func testSecondSeedDoesNotDuplicatePlan() throws {
        let context = try makeSeededContext()

        try StrengthStabilityProgramSeeder.seed(in: context)
        try StrengthStabilityProgramSeeder.seed(in: context)

        let plans = try context.fetch(FetchDescriptor<RepeatingPlan>())
        XCTAssertEqual(plans.count, 1)

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        XCTAssertEqual(templates.count, 4)

        let routines = try context.fetch(FetchDescriptor<MobilityRoutine>())
        XCTAssertEqual(routines.count, 5)
    }

    private func makeSeededContext() throws -> ModelContext {
        let context = try GymTrackerTestStore.makeInMemoryContext()

        let exerciseNames = [
            "Band Pull-Apart",
            "Overhead Press",
            "Chest-Supported Row",
            "Dumbbell Incline Press",
            "Lat Pulldown",
            "Lateral Raise",
            "Barbell Curl",
            "Bodyweight Squat",
            "High-Bar Back Squat",
            "Bulgarian Split Squat",
            "Leg Extension",
            "Hip Abduction Machine",
            "Side Plank",
            "Bench Press",
            "Seated Cable Row",
            "Pull Up",
            "Military Press",
            "Rear Delt Fly",
            "Triceps Pushdown",
            "Glute Bridge",
            "Bird Dog",
            "Deadlift",
            "Leg Curl",
            "Barbell Hip Thrust"
        ]
        exerciseNames.forEach { name in
            let trackingType: TrackingType = name == "Side Plank" ? .duration : .weightAndReps
            context.insert(Exercise(name: name, primaryMuscles: [.middleChest], trackingType: trackingType))
        }

        let mobilityNames = [
            "Thoracic Rotation",
            "Wall Slides",
            "Knee-to-Wall Ankle Mobilization",
            "90/90 Hip Switch",
            "Tactical Frog",
            "Fire Hydrants",
            "Shoulder CARs",
            "Couch Stretch"
        ]
        mobilityNames.forEach { name in
            context.insert(
                MobilityDefinition(
                    name: name,
                    trackingType: name == "Couch Stretch" ? .duration : .repetitions,
                    defaultDurationSeconds: name == "Couch Stretch" ? 30 : nil,
                    defaultRepetitions: name == "Couch Stretch" ? nil : 8,
                    isCustom: false
                )
            )
        }

        try context.save()
        return context
    }
}
#endif
