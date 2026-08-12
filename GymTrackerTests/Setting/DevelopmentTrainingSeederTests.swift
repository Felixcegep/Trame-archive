import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class DevelopmentTrainingSeederTests: XCTestCase {
    func testSeedCreatesTwoYearsOfCompletedHistory() throws {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let exercises = [
            Exercise(name: "Bench Press", primaryMuscles: [.middleChest]),
            Exercise(name: "Squat", primaryMuscles: [.quadriceps]),
            Exercise(name: "Deadlift", primaryMuscles: [.hamstrings]),
            Exercise(name: "Overhead Press", primaryMuscles: [.frontDeltoid])
        ]
        exercises.forEach(context.insert)

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try DevelopmentTrainingSeeder.seed(in: context, now: now)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(workouts.count, 312)
        XCTAssertTrue(workouts.allSatisfy { $0.status == .completed && $0.endTime != nil })
        XCTAssertEqual(workouts.first?.exercises.count, 4)
        XCTAssertEqual(workouts.first?.exercises.first?.sets.count, 3)
        XCTAssertTrue(workouts.flatMap(\.exercises).flatMap(\.sets).allSatisfy(\.done))
        XCTAssertTrue(workouts.contains { $0.name?.contains("Powerlifting") == true })
        XCTAssertTrue(workouts.contains { $0.name?.contains("Olympic Weightlifting") == true })
        XCTAssertTrue(workouts.contains { $0.name?.contains("PPL") == true })
        XCTAssertTrue(workouts.contains { $0.name?.contains("Exploration") == true })
    }
}
