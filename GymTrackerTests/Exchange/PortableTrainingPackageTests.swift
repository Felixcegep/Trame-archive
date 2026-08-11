import CryptoKit
import Foundation
import XCTest
@testable import GymTracker

#if !GYMTRACKER_EXTENSION

final class PortableTrainingPackageTests: XCTestCase {
    func testChecksumIsCanonicalAndValidationRejectsTampering() {
        let first = component(name: "Plan", order: 0, payload: Data("plan".utf8))
        let second = component(name: "Template", order: 1, payload: Data("template".utf8))
        let packageA = makePackage(components: [first, second])
        let packageB = makePackage(components: [second, first], packageID: packageA.packageID, contentID: packageA.contentID)

        XCTAssertEqual(packageA.checksum, packageB.checksum)
        XCTAssertTrue(packageA.validate().isEmpty)

        let tampered = PortableTrainingPackage(
            packageID: packageA.packageID,
            contentID: packageA.contentID,
            author: packageA.author,
            provenance: packageA.provenance,
            compatibility: packageA.compatibility,
            components: packageA.components,
            dependencies: packageA.dependencies,
            checksum: "tampered"
        )
        XCTAssertTrue(tampered.validate().contains(.invalidChecksum))
    }

    func testPackageValidationNamesDuplicateAndMissingDependencyFailures() {
        let duplicateID = UUID()
        let missingDependency = UUID()
        let duplicateA = component(id: duplicateID, name: "A", order: 0, payload: Data([1]))
        let duplicateB = component(id: duplicateID, name: "B", order: 1, payload: Data([2]), dependencyIDs: [missingDependency])
        let package = makePackage(components: [duplicateA, duplicateB])

        let failures = package.validate()
        XCTAssertTrue(failures.contains(.duplicateComponentID(duplicateID)))
        XCTAssertFalse(failures.contains(.duplicateContentID(duplicateA.contentID)))
        XCTAssertTrue(failures.contains(.missingDependency(duplicateID, missingDependency)))
    }

    func testImportPreviewClassifiesAddExactUpdateIdentityNameAndMissingDependency() {
        let exact = component(name: "Exact", order: 0, payload: Data("same".utf8))
        let update = component(name: "Update", order: 1, payload: Data("new".utf8), contentVersion: 2)
        let identityConflict = component(id: UUID(), name: "Conflict", order: 2, payload: Data("conflict".utf8))
        let nameConflict = component(name: "Incoming Name", order: 3, payload: Data("name".utf8))
        let missing = component(name: "Missing", order: 4, payload: Data("missing".utf8), dependencyIDs: [UUID()])
        let addition = component(name: "Addition", order: 5, payload: Data("addition".utf8))
        let package = makePackage(components: [exact, update, identityConflict, nameConflict, missing, addition])

        let local = [
            localComponent(exact, name: exact.name),
            localComponent(update, name: update.name, version: 1, payload: Data("old".utf8)),
            localComponent(identityConflict, name: identityConflict.name, contentID: UUID()),
            localComponent(nameConflict, name: "Local Name", payload: Data("local-name".utf8))
        ]
        let preview = PortableImportPreviewPolicy.preview(
            package: package,
            localComponents: local,
            supportedCapabilityIDs: [],
            minimumSchemaVersion: 1,
            activeRunContentIDs: [update.contentID],
            completedHistoryContentIDs: [exact.contentID]
        )

        XCTAssertEqual(preview.items.first { $0.component.componentID == exact.componentID }?.classification, .exactMatch)
        XCTAssertEqual(preview.items.first { $0.component.componentID == update.componentID }?.classification, .safeUpdate)
        XCTAssertEqual(preview.items.first { $0.component.componentID == identityConflict.componentID }?.classification, .identityConflict)
        XCTAssertEqual(preview.items.first { $0.component.componentID == nameConflict.componentID }?.classification, .nameConflict)
        XCTAssertEqual(preview.items.first { $0.component.componentID == missing.componentID }?.classification, .missingDependency(missing.dependencyIDs[0]))
        XCTAssertEqual(preview.items.first { $0.component.componentID == addition.componentID }?.classification, .addition)
        XCTAssertTrue(preview.protection.activeRunsUnchanged)
        XCTAssertTrue(preview.protection.completedHistoryUnchanged)
        XCTAssertFalse(preview.canImport)
    }

    func testImportPreviewReportsCompatibilityWithoutClaimingAuthenticity() {
        let component = component(name: "Plan", order: 0, payload: Data([1]))
        let package = PortableTrainingPackage(
            author: PortableTrainingAuthor(authorID: nil, displayName: "Coach", organization: nil),
            provenance: PortableTrainingProvenance(kind: .imported, sourceIdentifier: "source", statement: nil),
            compatibility: PortableTrainingCompatibility(
                minimumAppBuild: "99.0",
                minimumSchemaVersion: 9,
                requiredCapabilityIDs: ["futureCapability"]
            ),
            components: [component],
            dependencies: []
        )
        let preview = PortableImportPreviewPolicy.preview(
            package: package,
            localComponents: [],
            supportedCapabilityIDs: [],
            minimumSchemaVersion: 1
        )

        XCTAssertTrue(preview.compatibilityFailures.contains(.incompatible))
        XCTAssertEqual(PortableTrainingPackage.checksumAlgorithm, "SHA-256")
        XCTAssertTrue(preview.protection.existingDataMutatedOnlyAfterExplicitResolution)
    }

    private func makePackage(
        components: [PortableTrainingComponentDescriptor],
        packageID: UUID = UUID(),
        contentID: UUID = UUID()
    ) -> PortableTrainingPackage {
        PortableTrainingPackage(
            packageID: packageID,
            contentID: contentID,
            author: PortableTrainingAuthor(
                authorID: UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
                displayName: "Coach",
                organization: "Local"
            ),
            provenance: PortableTrainingProvenance(kind: .userAuthored, sourceIdentifier: nil, statement: "Selected definitions"),
            compatibility: PortableTrainingCompatibility(minimumAppBuild: nil, minimumSchemaVersion: 1, requiredCapabilityIDs: []),
            components: components,
            dependencies: []
        )
    }

    private func component(
        id: UUID = UUID(),
        contentID: UUID = UUID(),
        name: String,
        order: Int,
        payload: Data,
        contentVersion: Int = 1,
        dependencyIDs: [UUID] = []
    ) -> PortableTrainingComponentDescriptor {
        PortableTrainingComponentDescriptor(
            componentID: id,
            contentID: contentID,
            kind: .planDefinition,
            name: name,
            contentVersion: contentVersion,
            selectionOrder: order,
            dependencyIDs: dependencyIDs,
            payload: payload
        )
    }

    private func localComponent(
        _ component: PortableTrainingComponentDescriptor,
        name: String,
        version: Int? = nil,
        contentID: UUID? = nil,
        payload: Data? = nil
    ) -> PortableLocalComponent {
        let bytes = payload ?? component.payload
        let checksum = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        return PortableLocalComponent(
            componentID: component.componentID,
            contentID: contentID ?? component.contentID,
            kind: component.kind,
            name: name,
            contentVersion: version ?? component.contentVersion,
            checksum: checksum
        )
    }
}

#endif
