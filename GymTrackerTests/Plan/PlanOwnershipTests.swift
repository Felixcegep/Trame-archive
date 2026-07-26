import XCTest
@testable import GymTracker

/// The Plans browser splits "Mine" from "Ready-made" on this classification.
/// Seeded plans showing up under "Mine" made the user's own plans impossible to
/// pick out of a list dominated by content they never created.
final class PlanOwnershipTests: XCTestCase {
    func testSeededWorkoutPlanIsAppProvidedAndUserBuiltOneIsNot() {
        let seeded = WorkoutPlan(name: "Hypertrophy Base", daysPerWeek: 4, durationWeeks: 8)
        let mine = WorkoutPlan(name: "My Plan", daysPerWeek: 3, durationWeeks: 4)
        let records = [record(kind: .workoutPlan, entityID: seeded.id)]

        XCTAssertTrue(PlanOwnership.isAppProvided(seeded, seedRecords: records))
        XCTAssertFalse(PlanOwnership.isAppProvided(mine, seedRecords: records))
    }

    /// A record the user has taken ownership of stops being app-provided, so
    /// adopted content lands in "Mine" where they can manage it.
    func testPlanIsUserOwnedWhenItsSeedRecordIsNotSystemProvided() {
        let plan = WorkoutPlan(name: "Adopted", daysPerWeek: 3, durationWeeks: 4)
        let records = [record(kind: .workoutPlan, entityID: plan.id, isSystemProvided: false)]

        XCTAssertFalse(PlanOwnership.isAppProvided(plan, seedRecords: records))
    }

    func testSeedRecordOfADifferentKindDoesNotClassifyAPlan() {
        let plan = WorkoutPlan(name: "Mine", daysPerWeek: 3, durationWeeks: 4)
        let records = [record(kind: .workoutTemplate, entityID: plan.id)]

        XCTAssertFalse(PlanOwnership.isAppProvided(plan, seedRecords: records))
    }

    func testRepeatingPlanUsesItsBuiltInFlagOrTheRegistry() {
        let builtIn = RepeatingPlan(name: "Starter rotation", isBuiltIn: true)
        let registered = RepeatingPlan(name: "Seeded rotation")
        let mine = RepeatingPlan(name: "My rotation")
        let records = [record(kind: .repeatingPlan, entityID: registered.id)]

        XCTAssertTrue(PlanOwnership.isAppProvided(builtIn, seedRecords: records))
        XCTAssertTrue(PlanOwnership.isAppProvided(registered, seedRecords: records))
        XCTAssertFalse(PlanOwnership.isAppProvided(mine, seedRecords: records))
    }

    private func record(
        kind: SystemSeedEntityKind,
        entityID: UUID,
        isSystemProvided: Bool = true
    ) -> SystemSeedRecord {
        SystemSeedRecord(
            seedKey: "seed.\(kind.rawValue).\(entityID.uuidString)",
            entityKind: kind,
            entityID: entityID,
            seedVersion: 1,
            contentVersion: 1,
            isSystemProvided: isSystemProvided
        )
    }
}
