import XCTest
@testable import GymTracker

@MainActor
final class MobilityFilteringTests: XCTestCase {
    func testFocusMatchesSeedFamilyAndExcludesOtherRegions() {
        let hip = definition("Couch Stretch", family: "Hip mobility")
        let neck = definition("Upper Trap Stretch", family: "Neck & Upper Traps")

        var filter = MobilityFilterState()
        filter.focus = .hips

        XCTAssertTrue(filter.matches(hip, searchText: ""))
        XCTAssertFalse(filter.matches(neck, searchText: ""))
        XCTAssertEqual(filter.activeFilterCount, 1)
    }

    func testTrackingAndFavoritesFilters() {
        let hold = definition("Pigeon Stretch", family: "Hip mobility", tracking: .duration)
        hold.isFavorite = true
        let reps = definition("90/90 Hip Switch", family: "Hip mobility", tracking: .repetitions)

        var trackingFilter = MobilityFilterState()
        trackingFilter.tracking = .duration
        XCTAssertTrue(trackingFilter.matches(hold, searchText: ""))
        XCTAssertFalse(trackingFilter.matches(reps, searchText: ""))

        var favoriteFilter = MobilityFilterState()
        favoriteFilter.favoritesOnly = true
        XCTAssertTrue(favoriteFilter.matches(hold, searchText: ""))
        XCTAssertFalse(favoriteFilter.matches(reps, searchText: ""))
    }

    func testSearchMatchesNameFamilyAndChipLabel() {
        let hip = definition("Couch Stretch", family: "Hip mobility")
        let shoulder = definition("Wall Slides", family: "Shoulder mobility")

        let filter = MobilityFilterState()
        XCTAssertTrue(filter.matches(hip, searchText: "couch"))
        XCTAssertTrue(filter.matches(hip, searchText: "hip"))
        XCTAssertTrue(filter.matches(hip, searchText: "Hips"))
        XCTAssertFalse(filter.matches(shoulder, searchText: "couch"))
    }

    func testClearResetsActiveFilters() {
        var filter = MobilityFilterState()
        filter.focus = .spine
        filter.tracking = .repetitions
        filter.favoritesOnly = true
        XCTAssertEqual(filter.activeFilterCount, 3)

        filter.clear()
        XCTAssertEqual(filter, MobilityFilterState())
        XCTAssertEqual(filter.activeFilterCount, 0)
    }

    func testUnfamiliedCustomMovementOnlyAppearsInAll() {
        let custom = MobilityDefinition(name: "Desk stretch")
        var hips = MobilityFilterState()
        hips.focus = .hips
        XCTAssertFalse(hips.matches(custom, searchText: ""))
        XCTAssertTrue(MobilityFilterState().matches(custom, searchText: "desk"))
    }

    private func definition(
        _ name: String,
        family: String,
        tracking: MobilityTrackingType = .duration
    ) -> MobilityDefinition {
        MobilityDefinition(
            name: name,
            trackingType: tracking,
            family: MobilityFamily(name: family)
        )
    }
}
