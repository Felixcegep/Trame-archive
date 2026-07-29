import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class MobilityAssessmentSeedTests: XCTestCase {
    func testTenStableDefinitionsInstallIdempotently() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)

        let first = try MobilityAssessmentCatalogService.definitions(
            using: context,
            includeArchived: true
        )
        XCTAssertEqual(first.count, 10)
        XCTAssertEqual(Set(first.map(\.catalogueKey)).count, 10)
        XCTAssertEqual(Set(first.map(\.id)).count, 10)
        XCTAssertEqual(first.map(\.sortOrder), Array(0..<10))
        XCTAssertTrue(first.allSatisfy {
            MobilityAssessmentValidationService.validateDefinition($0) == nil
        })
        let firstIDs = Dictionary(uniqueKeysWithValues: first.map { ($0.catalogueKey, $0.id) })

        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)
        let second = try MobilityAssessmentCatalogService.definitions(
            using: context,
            includeArchived: true
        )
        XCTAssertEqual(second.count, 10)
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: second.map { ($0.catalogueKey, $0.id) }),
            firstIDs
        )
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<SystemSeedRecord>()).filter {
                $0.entityKind == .mobilityAssessmentDefinition
            }.count,
            10
        )
    }

    func testSeedRefreshPreservesUserOwnedArchiveState() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)
        let definition = try XCTUnwrap(
            try MobilityAssessmentCatalogService.definitions(using: context).first
        )
        definition.isArchived = true
        definition.name = "Locally changed authored field"
        try context.save()

        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)
        let refreshed = try XCTUnwrap(
            try MobilityAssessmentCatalogService.definitions(
                using: context,
                includeArchived: true
            ).first { $0.id == definition.id }
        )
        XCTAssertTrue(refreshed.isArchived)
        XCTAssertNotEqual(refreshed.name, "Locally changed authored field")
    }
}
