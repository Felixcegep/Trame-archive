import Foundation
import XCTest
@testable import GymTracker

final class HealthKitBodyMassImportPlannerTests: XCTestCase {
    func testChoosesLatestSamplePerDayAndKeepsAuthoredEntry() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 1_754_006_400)
        let samples = [
            sample(id: "older", date: day, kilograms: 80),
            sample(id: "latest", date: day.addingTimeInterval(300), kilograms: 81),
            sample(id: "next-day", date: day.addingTimeInterval(86_400), kilograms: 82)
        ]
        let authored = HealthKitBodyMassExistingEntry(id: UUID(), dayKey: "2025-08-01", source: .checkIn)
        let plan = HealthKitBodyMassImportPlanner(calendar: calendar).plan(
            samples: samples,
            entries: [authored],
            provenance: []
        )

        XCTAssertEqual(plan.invalidSampleCount, 0)
        XCTAssertEqual(plan.decisions.count, 2)
        XCTAssertTrue(plan.decisions.contains { decision in
            if case let .skipAuthored(entryID, sample) = decision {
                return entryID == authored.id && sample.id == "latest"
            }
            return false
        })
        XCTAssertTrue(plan.decisions.contains { decision in
            if case let .insert(sample) = decision { return sample.id == "next-day" }
            return false
        })
    }

    func testExistingSampleIDIsIdempotentAndInvalidValuesAreNotImported() {
        let date = Date(timeIntervalSince1970: 1_754_006_400)
        let entryID = UUID()
        let plan = HealthKitBodyMassImportPlanner(calendar: .current).plan(
            samples: [
                sample(id: "known", date: date, kilograms: 80),
                sample(id: "invalid", date: date.addingTimeInterval(86_400), kilograms: 0)
            ],
            entries: [HealthKitBodyMassExistingEntry(id: entryID, dayKey: LocalDay(date: date).rawValue, source: .healthKit)],
            provenance: [HealthKitBodyMassExistingProvenance(sampleID: "known", entryID: entryID)]
        )

        XCTAssertEqual(plan.invalidSampleCount, 1)
        XCTAssertEqual(plan.decisions, [.unchanged(entryID: entryID, sampleID: "known")])
    }

    private func sample(id: String, date: Date, kilograms: Double) -> HealthKitBodyMassSample {
        HealthKitBodyMassSample(
            id: id,
            startDate: date,
            endDate: date,
            kilograms: kilograms,
            sourceBundleIdentifier: "com.example.scale",
            sourceVersion: "1",
            sourceProductType: "Scale"
        )
    }
}
