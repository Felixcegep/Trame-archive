import XCTest
@testable import GymTracker

final class CaffeineGuidanceTests: XCTestCase {
    private let referenceDate = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 7, day: 20).date!

    private func birthdate(yearsAgo: Int) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .year, value: -yearsAgo, to: referenceDate)!
    }

    func testAgeBandUnknownWithoutBirthdate() {
        XCTAssertEqual(CaffeineGuidance.ageBand(birthdate: nil, referenceDate: referenceDate), .unknown)
    }

    func testAgeBandBoundaries() {
        XCTAssertEqual(CaffeineGuidance.ageBand(birthdate: birthdate(yearsAgo: 13), referenceDate: referenceDate), .child)
        XCTAssertEqual(CaffeineGuidance.ageBand(birthdate: birthdate(yearsAgo: 14), referenceDate: referenceDate), .teen)
        XCTAssertEqual(CaffeineGuidance.ageBand(birthdate: birthdate(yearsAgo: 17), referenceDate: referenceDate), .teen)
        XCTAssertEqual(CaffeineGuidance.ageBand(birthdate: birthdate(yearsAgo: 18), referenceDate: referenceDate), .adult)
        XCTAssertEqual(CaffeineGuidance.ageBand(birthdate: birthdate(yearsAgo: 40), referenceDate: referenceDate), .adult)
    }

    func testDailyLimitAdultIsFlat400() {
        XCTAssertEqual(CaffeineGuidance.dailyLimit(ageBand: .adult, bodyWeightKilograms: nil), .milligrams(400, isPersonalized: true))
    }

    func testDailyLimitUnknownFallsBackTo400ButIsNotPersonalized() {
        XCTAssertEqual(CaffeineGuidance.dailyLimit(ageBand: .unknown, bodyWeightKilograms: nil), .milligrams(400, isPersonalized: false))
    }

    func testDailyLimitTeenWithWeightUses2point5PerKilogram() {
        XCTAssertEqual(CaffeineGuidance.dailyLimit(ageBand: .teen, bodyWeightKilograms: 60), .milligrams(150, isPersonalized: true))
    }

    func testDailyLimitTeenWithoutWeightNeedsBodyWeight() {
        XCTAssertEqual(CaffeineGuidance.dailyLimit(ageBand: .teen, bodyWeightKilograms: nil), .needsBodyWeight)
        XCTAssertEqual(CaffeineGuidance.dailyLimit(ageBand: .teen, bodyWeightKilograms: 0), .needsBodyWeight)
    }

    func testDailyLimitChildIsNotRecommended() {
        XCTAssertEqual(CaffeineGuidance.dailyLimit(ageBand: .child, bodyWeightKilograms: 45), .notRecommended)
    }
}
