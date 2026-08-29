import XCTest
@testable import GymTracker

final class RecentSetTypesTests: XCTestCase {
    
    func testDecodeEmptyStringReturnsEmptyArray() {
        let decoded = RecentSetTypes.decode("")
        XCTAssertTrue(decoded.isEmpty)
    }
    
    func testDecodeFiltersOutUnknownRawValues() {
        let raw = "normal,fake_type,dropSet"
        let decoded = RecentSetTypes.decode(raw)
        XCTAssertTrue(decoded.isEmpty)
    }
    
    func testDecodeFiltersOutCommonTypes() {
        // Common types should not be remembered
        let raw = "normal,warmup,topSet,backoff,amrap"
        let decoded = RecentSetTypes.decode(raw)
        XCTAssertEqual(decoded, [.amrap])
    }
    
    func testDecodeDeduplicatesTypes() {
        let raw = "amrap,dropSet,amrap,technique"
        let decoded = RecentSetTypes.decode(raw)
        XCTAssertEqual(decoded, [.amrap, .technique])
    }
    
    func testDecodeRespectsLimit() {
        // limit is 3
        let raw = "amrap,failure,technique,dropSet,test"
        let decoded = RecentSetTypes.decode(raw)
        XCTAssertEqual(decoded, [.amrap, .failure, .technique])
        XCTAssertEqual(decoded.count, 3)
    }
    
    func testEncodeArrayToString() {
        let types: [SetType] = [.amrap, .dropSet]
        let encoded = RecentSetTypes.encode(types)
        XCTAssertEqual(encoded, "amrap,dropSet")
    }
    
    func testRecordingCommonTypeDoesNotChangeStorage() {
        let initial = "amrap,dropSet"
        let updated = RecentSetTypes.recording(.normal, into: initial)
        XCTAssertEqual(updated, initial)
    }
    
    func testRecordingNewTypeAddsToFront() {
        let initial = "dropSet"
        let updated = RecentSetTypes.recording(.amrap, into: initial)
        XCTAssertEqual(updated, "amrap")
    }
    
    func testRecordingExistingTypeMovesToFront() {
        let initial = "dropSet,amrap,technique"
        let updated = RecentSetTypes.recording(.technique, into: initial)
        XCTAssertEqual(updated, "technique,amrap")
    }
    
    func testRecordingPushesOutOldestTypeWhenFull() {
        let initial = "dropSet,amrap,technique" // 3 items
        let updated = RecentSetTypes.recording(.failure, into: initial)
        XCTAssertEqual(updated, "failure,amrap,technique")
    }

    func testDropSetRoleIsNeverRememberedBecauseDropsetIsAMethod() {
        XCTAssertEqual(RecentSetTypes.recording(.dropSet, into: "amrap"), "amrap")
    }

    func testStretchIsRememberedLikeEveryOtherNonCommonRole() {
        XCTAssertEqual(RecentSetTypes.recording(.stretch, into: "amrap"), "stretch,amrap")
        XCTAssertEqual(RecentSetTypes.decode("stretch,amrap"), [.stretch, .amrap])
    }

    func testStretchIsOfferedInTheSpecialGroup() {
        XCTAssertEqual(SetType.stretch.group, .special)
        XCTAssertTrue(SetTypeGroup.special.members.contains(.stretch))
    }

    func testStretchIsExcludedFromStrengthAnalyticsLikeWarmup() {
        XCTAssertTrue(SetType.warmup.isStrengthAnalyticsExcluded)
        XCTAssertTrue(SetType.stretch.isStrengthAnalyticsExcluded)
        XCTAssertFalse(SetType.normal.isStrengthAnalyticsExcluded)
        XCTAssertFalse(SetType.recovery.isStrengthAnalyticsExcluded)
    }

    /// A type nobody filed into a group would be unreachable from the picker,
    /// so the grid and the lookup have to agree for every case.
    func testEverySetTypeIsReachableFromExactlyOneGroup() {
        for type in SetType.allCases {
            XCTAssertTrue(
                SetTypeGroup.allCases
                    .filter { $0.members.contains(type) } == [type.group],
                "\(type.rawValue) is not offered by exactly its own group"
            )
        }
    }
}
