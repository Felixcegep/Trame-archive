import Foundation
import XCTest
@testable import GymTracker

#if !GYMTRACKER_EXTENSION

final class PortableTrainingPackageAssemblyTests: XCTestCase {
    func testAssemblyIncludesSelectedDefinitionsAndDeduplicatedDependencies() throws {
        let planID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let templateID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let exerciseID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let template = source(
            id: templateID,
            kind: .workoutTemplate,
            name: "Template",
            payload: Data("template".utf8),
            dependencies: [dependency(id: exerciseID, kind: .exerciseDefinition, name: "Squat")]
        )
        let plan = source(
            id: planID,
            kind: .planDefinition,
            name: "Plan",
            payload: Data("plan".utf8),
            dependencies: [dependency(id: exerciseID, kind: .exerciseDefinition, name: "Squat")]
        )

        let package = try PortableTrainingPackageAssemblyProjection.assemble(
            selection: PortableTrainingPackageSelection(componentIDs: [planID, templateID]),
            sources: [template, plan],
            author: PortableTrainingAuthor(authorID: nil, displayName: "Local", organization: nil),
            provenance: PortableTrainingProvenance(kind: .userAuthored, sourceIdentifier: "test", statement: nil),
            compatibility: PortableTrainingCompatibility(minimumAppBuild: nil, minimumSchemaVersion: 1, requiredCapabilityIDs: [])
        )

        XCTAssertEqual(package.components.map(\.name), ["Plan", "Template"])
        XCTAssertEqual(package.dependencies.count, 1)
        XCTAssertEqual(package.dependencies.first?.dependencyID, exerciseID)
        XCTAssertTrue(package.validate().isEmpty)
    }

    func testAssemblyIDsAndChecksumAreDeterministicForStableSources() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let source = source(id: id, kind: .mobilityProgram, name: "Mobility", payload: Data("payload".utf8))
        let inputs = (
            selection: PortableTrainingPackageSelection(componentIDs: [id]),
            sources: [source],
            author: PortableTrainingAuthor(authorID: nil, displayName: "Local", organization: nil),
            provenance: PortableTrainingProvenance(kind: .userAuthored, sourceIdentifier: "test", statement: nil),
            compatibility: PortableTrainingCompatibility(minimumAppBuild: nil, minimumSchemaVersion: 1, requiredCapabilityIDs: [])
        )

        let first = try PortableTrainingPackageAssemblyProjection.assemble(
            selection: inputs.selection,
            sources: inputs.sources,
            author: inputs.author,
            provenance: inputs.provenance,
            compatibility: inputs.compatibility
        )
        let second = try PortableTrainingPackageAssemblyProjection.assemble(
            selection: inputs.selection,
            sources: inputs.sources,
            author: inputs.author,
            provenance: inputs.provenance,
            compatibility: inputs.compatibility
        )

        XCTAssertEqual(first.packageID, second.packageID)
        XCTAssertEqual(first.contentID, second.contentID)
        XCTAssertEqual(first.checksum, second.checksum)
    }

    func testAssemblyRejectsEmptyAndUnavailableSelections() {
        let sourceID = UUID()
        let common = (
            author: PortableTrainingAuthor(authorID: nil, displayName: "Local", organization: nil),
            provenance: PortableTrainingProvenance(kind: .userAuthored, sourceIdentifier: "test", statement: nil),
            compatibility: PortableTrainingCompatibility(minimumAppBuild: nil, minimumSchemaVersion: 1, requiredCapabilityIDs: [])
        )
        XCTAssertThrowsError(try PortableTrainingPackageAssemblyProjection.assemble(
            selection: PortableTrainingPackageSelection(),
            sources: [],
            author: common.author,
            provenance: common.provenance,
            compatibility: common.compatibility
        )) { error in
            XCTAssertEqual(error as? PortableTrainingPackageAssemblyError, .noComponentsSelected)
        }
        XCTAssertThrowsError(try PortableTrainingPackageAssemblyProjection.assemble(
            selection: PortableTrainingPackageSelection(componentIDs: [sourceID]),
            sources: [],
            author: common.author,
            provenance: common.provenance,
            compatibility: common.compatibility
        )) { error in
            XCTAssertEqual(error as? PortableTrainingPackageAssemblyError, .selectedComponentUnavailable(sourceID))
        }
    }

    private func source(
        id: UUID,
        kind: PortableTrainingComponentKind,
        name: String,
        payload: Data,
        dependencies: [PortableTrainingDependencyDescriptor] = []
    ) -> PortableTrainingAssemblySource {
        PortableTrainingAssemblySource(
            componentID: id,
            contentID: id,
            kind: kind,
            name: name,
            contentVersion: 1,
            payload: payload,
            dependencies: dependencies
        )
    }

    private func dependency(
        id: UUID,
        kind: PortableTrainingComponentKind,
        name: String
    ) -> PortableTrainingDependencyDescriptor {
        PortableTrainingDependencyDescriptor(
            dependencyID: id,
            kind: kind,
            name: name,
            minimumContentVersion: 1,
            isRequired: true
        )
    }
}

#endif
