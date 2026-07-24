import XCTest
@testable import GymTracker

/// Covers the shared decimal-entry parser used by every numeric field. The
/// central guarantee is that partial input is preserved and both regional
/// separators round-trip, so ".5" and ",5" both become 0.5.
final class DecimalParserTests: XCTestCase {
    func testAcceptsPartialEditingStates() {
        for candidate in ["", ".", ",", "0.", "0,", ".5", ",5", "25.", "25,"] {
            XCTAssertNotNil(DecimalParser.sanitizedEditingText(candidate), "\(candidate) should be a legal partial entry")
        }
    }

    func testRejectsInvalidCharactersAndDoubleSeparators() {
        for candidate in ["-5", "1.2.3", "1,2,3", "5a", "abc", "1 000", "1.2,3", "$5"] {
            XCTAssertNil(DecimalParser.sanitizedEditingText(candidate), "\(candidate) should be rejected")
        }
    }

    func testParsesBothSeparatorsToTheSameValue() {
        XCTAssertEqual(DecimalParser.value(from: ".5"), 0.5)
        XCTAssertEqual(DecimalParser.value(from: ",5"), 0.5)
        XCTAssertEqual(DecimalParser.value(from: "0.5"), 0.5)
        XCTAssertEqual(DecimalParser.value(from: "0,5"), 0.5)
        XCTAssertEqual(DecimalParser.value(from: "25.5"), 25.5)
        XCTAssertEqual(DecimalParser.value(from: "25,5"), 25.5)
        XCTAssertEqual(DecimalParser.value(from: "5."), 5)
    }

    func testPartialAndEmptyValuesAreNil() {
        XCTAssertNil(DecimalParser.value(from: ""))
        XCTAssertNil(DecimalParser.value(from: "."))
        XCTAssertNil(DecimalParser.value(from: ","))
    }

    func testDisplayTextUsesLocaleSeparatorAndDropsTrailingZeros() {
        XCTAssertEqual(DecimalParser.displayText(for: 0.5, locale: Locale(identifier: "en_US")), "0.5")
        XCTAssertEqual(DecimalParser.displayText(for: 0.5, locale: Locale(identifier: "fr_FR")), "0,5")
        XCTAssertEqual(DecimalParser.displayText(for: 25, locale: Locale(identifier: "en_US")), "25")
        XCTAssertEqual(DecimalParser.displayText(for: nil), "")
    }
}
