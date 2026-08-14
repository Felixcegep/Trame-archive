import Foundation
import SwiftData
import XCTest
@testable import GymTracker

/// Diagnostic-only performance probes. The normal unit lane explicitly skips
/// this class; only the opt-in diagnostic runner selects it, so the expensive
/// 100,000-set graph is never constructed by routine correctness validation.
@MainActor
final class LargeHistoryPerformanceTests: XCTestCase {
    func test100000SetHistoryProgressProjectionPerformance() throws {
        let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)
        let fixture = LargeHistoryTestFixture.make(referenceDate: referenceDate)
        XCTAssertEqual(fixture.setCount, LargeHistoryTestFixture.defaultSetCount)
        let calendar = Calendar(identifier: .gregorian)
        var projectedPointCount = 0

        measure {
            let projection = HistoryProgressProjection.make(
                workouts: fixture.workouts,
                displayWeightType: .kg,
                calendar: calendar,
                referenceDate: referenceDate
            )
            projectedPointCount = projection.exerciseSeries.reduce(0) {
                $0 + $1.totalPointCount
            }
        }

        XCTAssertGreaterThan(projectedPointCount, 0)
    }

    func test100000SetHistoryRecordsProjectionPerformance() throws {
        let fixture = LargeHistoryTestFixture.make()
        var recordCount = 0

        measure {
            let projection = HistoryRecordsProjection.make(
                workouts: fixture.workouts,
                displayWeightType: .kg
            )
            recordCount = projection.loadRecords.count
                + projection.repRecords.count
                + projection.velocityRecords.count
                + projection.specializedMetricRecords.count
                + projection.blockScoreRecords.count
                + projection.notableSessions.count
        }

        XCTAssertGreaterThan(recordCount, 0)
    }

    func test100000SetHistorySwiftDataFetchPerformance() throws {
        let fixture = LargeHistoryTestFixture.make()
        let context = try GymTrackerTestStore.makeInMemoryContext()
        try fixture.insert(into: context)
        var fetchedWorkoutCount = 0

        measure {
            fetchedWorkoutCount = (try? context.fetch(FetchDescriptor<Workout>()).count) ?? 0
        }

        XCTAssertEqual(fetchedWorkoutCount, fixture.workouts.count)
    }
}
