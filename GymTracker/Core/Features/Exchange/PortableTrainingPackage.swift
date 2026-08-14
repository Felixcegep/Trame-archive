import CryptoKit
import Foundation

#if !GYMTRACKER_EXTENSION

/// A coach-exchange package is deliberately smaller than `BackupDTO`: it is a
/// selected, portable definition artifact and never contains performed
/// workouts, active runs, or progression ledger truth.
enum PortableTrainingComponentKind: String, Codable, CaseIterable, Hashable {
    case planDefinition
    case workoutTemplate
    case repeatingPlan
    case mobilityProgram
    case exerciseDefinition
    case mobilityRoutine
}

enum PortableTrainingProvenanceKind: String, Codable, CaseIterable, Hashable {
    case userAuthored
    case imported
    case bundled
    case adaptedFromSource
}

struct PortableTrainingAuthor: Codable, Equatable, Hashable {
    let authorID: UUID?
    let displayName: String?
    let organization: String?
}

struct PortableTrainingProvenance: Codable, Equatable, Hashable {
    let kind: PortableTrainingProvenanceKind
    let sourceIdentifier: String?
    let statement: String?
}

struct PortableTrainingCompatibility: Codable, Equatable, Hashable {
    let minimumAppBuild: String?
    let minimumSchemaVersion: Int
    let requiredCapabilityIDs: [String]
}

struct PortableTrainingDependencyDescriptor: Codable, Equatable, Hashable {
    let dependencyID: UUID
    let kind: PortableTrainingComponentKind
    let name: String
    let minimumContentVersion: Int?
    let isRequired: Bool
}

/// One selected, definition-only component. `payload` is the component's
/// portable value payload; conversion into local SwiftData is a later import
/// step and is intentionally outside this contract.
struct PortableTrainingComponentDescriptor: Codable, Equatable, Hashable {
    let componentID: UUID
    let contentID: UUID
    let kind: PortableTrainingComponentKind
    let name: String
    let contentVersion: Int
    let selectionOrder: Int
    let dependencyIDs: [UUID]
    let payload: Data
}

enum PortableTrainingPackageValidationFailure: Error, Equatable, Hashable {
    case unsupportedPackageVersion(Int)
    case invalidSchemaVersion
    case invalidComponentVersion(UUID)
    case emptyPackage
    case duplicateComponentID(UUID)
    case duplicateContentID(UUID)
    case duplicateDependencyID(UUID)
    case missingDependency(UUID, UUID)
    case emptyComponentName(UUID)
    case emptyComponentPayload(UUID)
    case tooManyComponents(Int)
    case componentPayloadTooLarge(UUID)
    case packagePayloadTooLarge(Int)
    case invalidRequiredCapability(String)
    case invalidChecksum
}

struct PortableTrainingPackage: Codable, Equatable, Hashable {
    static let currentPackageVersion = 1
    static let checksumAlgorithm = "SHA-256"
    static let maximumComponentCount = 200
    static let maximumComponentPayloadBytes = 2 * 1_024 * 1_024
    static let maximumCombinedPayloadBytes = 10 * 1_024 * 1_024

    let packageID: UUID
    let contentID: UUID
    let packageVersion: Int
    let author: PortableTrainingAuthor
    let provenance: PortableTrainingProvenance
    let compatibility: PortableTrainingCompatibility
    let components: [PortableTrainingComponentDescriptor]
    let dependencies: [PortableTrainingDependencyDescriptor]
    /// Integrity only. This value does not authenticate the author or origin.
    let checksum: String

    init(
        packageID: UUID = UUID(),
        contentID: UUID = UUID(),
        packageVersion: Int = Self.currentPackageVersion,
        author: PortableTrainingAuthor,
        provenance: PortableTrainingProvenance,
        compatibility: PortableTrainingCompatibility,
        components: [PortableTrainingComponentDescriptor],
        dependencies: [PortableTrainingDependencyDescriptor],
        checksum: String? = nil
    ) {
        self.packageID = packageID
        self.contentID = contentID
        self.packageVersion = packageVersion
        self.author = author
        self.provenance = provenance
        self.compatibility = compatibility
        self.components = components
        self.dependencies = dependencies
        self.checksum = checksum ?? Self.computeChecksum(
            packageID: packageID,
            contentID: contentID,
            packageVersion: packageVersion,
            author: author,
            provenance: provenance,
            compatibility: compatibility,
            components: components,
            dependencies: dependencies
        )
    }

    var computedChecksum: String {
        Self.computeChecksum(
            packageID: packageID,
            contentID: contentID,
            packageVersion: packageVersion,
            author: author,
            provenance: provenance,
            compatibility: compatibility,
            components: components,
            dependencies: dependencies
        )
    }

    func validate() -> [PortableTrainingPackageValidationFailure] {
        var failures: [PortableTrainingPackageValidationFailure] = []
        func add(_ failure: PortableTrainingPackageValidationFailure) {
            if !failures.contains(failure) { failures.append(failure) }
        }

        if packageVersion < 1 || packageVersion > Self.currentPackageVersion {
            add(.unsupportedPackageVersion(packageVersion))
        }
        if compatibility.minimumSchemaVersion < 1 {
            add(.invalidSchemaVersion)
        }
        if components.isEmpty { add(.emptyPackage) }
        if components.count > Self.maximumComponentCount {
            add(.tooManyComponents(components.count))
        }

        var componentIDs = Set<UUID>()
        var contentIDs = Set<UUID>()
        var combinedPayloadBytes = 0
        for component in components {
            if !componentIDs.insert(component.componentID).inserted {
                add(.duplicateComponentID(component.componentID))
            }
            if !contentIDs.insert(component.contentID).inserted {
                add(.duplicateContentID(component.contentID))
            }
            if component.contentVersion < 1 {
                add(.invalidComponentVersion(component.componentID))
            }
            if component.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                add(.emptyComponentName(component.componentID))
            }
            if component.payload.isEmpty {
                add(.emptyComponentPayload(component.componentID))
            }
            if component.payload.count > Self.maximumComponentPayloadBytes {
                add(.componentPayloadTooLarge(component.componentID))
            }
            let (newTotal, overflowed) = combinedPayloadBytes.addingReportingOverflow(component.payload.count)
            combinedPayloadBytes = overflowed ? .max : newTotal
        }
        if combinedPayloadBytes > Self.maximumCombinedPayloadBytes {
            add(.packagePayloadTooLarge(combinedPayloadBytes))
        }

        var dependencyIDs = Set<UUID>()
        for dependency in dependencies {
            if !dependencyIDs.insert(dependency.dependencyID).inserted {
                add(.duplicateDependencyID(dependency.dependencyID))
            }
        }
        let declaredDependencyIDs = dependencyIDs.union(componentIDs)
        for component in components {
            for dependencyID in component.dependencyIDs where !declaredDependencyIDs.contains(dependencyID) {
                add(.missingDependency(component.componentID, dependencyID))
            }
        }
        for capability in compatibility.requiredCapabilityIDs {
            if capability.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                add(.invalidRequiredCapability(capability))
            }
        }
        if checksum.lowercased() != computedChecksum.lowercased() {
            add(.invalidChecksum)
        }
        return failures
    }

    private static func computeChecksum(
        packageID: UUID,
        contentID: UUID,
        packageVersion: Int,
        author: PortableTrainingAuthor,
        provenance: PortableTrainingProvenance,
        compatibility: PortableTrainingCompatibility,
        components: [PortableTrainingComponentDescriptor],
        dependencies: [PortableTrainingDependencyDescriptor]
    ) -> String {
        let canonical = canonicalRepresentation(
            packageID: packageID,
            contentID: contentID,
            packageVersion: packageVersion,
            author: author,
            provenance: provenance,
            compatibility: compatibility,
            components: components,
            dependencies: dependencies
        )
        return SHA256.hash(data: Data(canonical.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func canonicalRepresentation(
        packageID: UUID,
        contentID: UUID,
        packageVersion: Int,
        author: PortableTrainingAuthor,
        provenance: PortableTrainingProvenance,
        compatibility: PortableTrainingCompatibility,
        components: [PortableTrainingComponentDescriptor],
        dependencies: [PortableTrainingDependencyDescriptor]
    ) -> String {
        let componentLines = components.sorted { $0.componentID.uuidString < $1.componentID.uuidString }.map {
            [
                $0.componentID.uuidString.lowercased(), $0.contentID.uuidString.lowercased(),
                $0.kind.rawValue, $0.name, String($0.contentVersion), String($0.selectionOrder),
                $0.dependencyIDs.map { $0.uuidString.lowercased() }.sorted().joined(separator: ","),
                $0.payload.base64EncodedString()
            ].map { escape($0) }.joined(separator: "|")
        }.joined(separator: "\n")
        let dependencyLines = dependencies.sorted { $0.dependencyID.uuidString < $1.dependencyID.uuidString }.map {
            [
                $0.dependencyID.uuidString.lowercased(), $0.kind.rawValue, $0.name,
                String($0.minimumContentVersion ?? 0), String($0.isRequired)
            ].map { escape($0) }.joined(separator: "|")
        }.joined(separator: "\n")
        return [
            "packageID=\(packageID.uuidString.lowercased())",
            "contentID=\(contentID.uuidString.lowercased())",
            "packageVersion=\(packageVersion)",
            "authorID=\(author.authorID?.uuidString.lowercased() ?? "")",
            "authorName=\(author.displayName ?? "")",
            "organization=\(author.organization ?? "")",
            "provenance=\(provenance.kind.rawValue)|\(provenance.sourceIdentifier ?? "")|\(provenance.statement ?? "")",
            "compatibility=\(compatibility.minimumAppBuild ?? "")|\(compatibility.minimumSchemaVersion)|\(compatibility.requiredCapabilityIDs.sorted().joined(separator: ","))",
            "components=\(componentLines)",
            "dependencies=\(dependencyLines)"
        ].map { escape($0) }.joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

struct PortableLocalComponent: Equatable, Hashable {
    let componentID: UUID
    let contentID: UUID
    let kind: PortableTrainingComponentKind
    let name: String
    let contentVersion: Int
    let checksum: String
}

enum PortableImportClassification: Equatable, Hashable {
    case addition
    case exactMatch
    case safeUpdate
    case identityConflict
    case nameConflict
    case missingDependency(UUID)
    case incompatible
    case versionConflict
}

struct PortableImportItemPreview: Equatable, Hashable {
    let component: PortableTrainingComponentDescriptor
    let classification: PortableImportClassification
    let detail: String
}

struct PortableImportProtectionGuarantee: Equatable, Hashable {
    let activeRunsUnchanged: Bool
    let completedHistoryUnchanged: Bool
    let existingDataMutatedOnlyAfterExplicitResolution: Bool
}

struct PortableImportPreview: Equatable {
    let packageID: UUID
    let validationFailures: [PortableTrainingPackageValidationFailure]
    let compatibilityFailures: [PortableImportClassification]
    let items: [PortableImportItemPreview]
    let protection: PortableImportProtectionGuarantee

    var canImport: Bool {
        validationFailures.isEmpty && compatibilityFailures.isEmpty &&
            items.allSatisfy {
                if case .addition = $0.classification { return true }
                if case .exactMatch = $0.classification { return true }
                return false
            }
    }
}

enum PortableImportPreviewPolicy {
    static func preview(
        package: PortableTrainingPackage,
        localComponents: [PortableLocalComponent],
        supportedCapabilityIDs: Set<String>,
        minimumSchemaVersion: Int,
        currentAppBuild: String? = nil,
        activeRunContentIDs: Set<UUID> = [],
        completedHistoryContentIDs: Set<UUID> = []
    ) -> PortableImportPreview {
        let validationFailures = package.validate()
        var compatibilityFailures: [PortableImportClassification] = []
        if package.compatibility.minimumSchemaVersion > minimumSchemaVersion {
            compatibilityFailures.append(.incompatible)
        }
        if let minimumAppBuild = package.compatibility.minimumAppBuild,
           currentAppBuild.map({ compareBuild(minimumAppBuild, $0) == .orderedDescending }) ?? true {
            if !compatibilityFailures.contains(.incompatible) { compatibilityFailures.append(.incompatible) }
        }
        if !Set(package.compatibility.requiredCapabilityIDs).isSubset(of: supportedCapabilityIDs) {
            if !compatibilityFailures.contains(.incompatible) { compatibilityFailures.append(.incompatible) }
        }

        let localByComponentID = Dictionary(grouping: localComponents, by: \.componentID)
        let localByContentID = Dictionary(grouping: localComponents, by: \.contentID)
        let localComponentIDs = Set(localComponents.map(\.componentID))
        var items: [PortableImportItemPreview] = []
        for component in package.components.sorted(by: { $0.selectionOrder < $1.selectionOrder }) {
            let missingDependency = component.dependencyIDs.first { dependencyID in
                if package.components.contains(where: { $0.componentID == dependencyID }) {
                    return false
                }
                guard let descriptor = package.dependencies.first(where: { $0.dependencyID == dependencyID }) else {
                    return true
                }
                return descriptor.isRequired && !localComponentIDs.contains(dependencyID)
            }
            if let missingDependency {
                items.append(PortableImportItemPreview(
                    component: component,
                    classification: .missingDependency(missingDependency),
                    detail: "A declared dependency is not available in the package descriptor."
                ))
                continue
            }
            if let existing = localByComponentID[component.componentID]?.first {
                if existing.contentID != component.contentID {
                    items.append(.init(component: component, classification: .identityConflict, detail: "The stable component identity already belongs to different content."))
                } else if existing.checksum == packageChecksum(component) {
                    items.append(.init(component: component, classification: .exactMatch, detail: "The local component has the same stable content and checksum."))
                } else if component.contentVersion > existing.contentVersion {
                    items.append(.init(component: component, classification: .safeUpdate, detail: "A newer content version is available; active runs and completed History remain unchanged."))
                } else if existing.name != component.name {
                    items.append(.init(component: component, classification: .nameConflict, detail: "The stable content identity has a different display name locally."))
                } else {
                    items.append(.init(component: component, classification: .versionConflict, detail: "The incoming content is not newer than the local content."))
                }
            } else if let sameContent = localByContentID[component.contentID], !sameContent.isEmpty {
                items.append(.init(component: component, classification: .identityConflict, detail: "The stable content identity exists under a different component identity."))
            } else {
                items.append(.init(component: component, classification: .addition, detail: "No local component has this stable identity."))
            }
        }
        _ = activeRunContentIDs
        _ = completedHistoryContentIDs
        return PortableImportPreview(
            packageID: package.packageID,
            validationFailures: validationFailures,
            compatibilityFailures: compatibilityFailures,
            items: items,
            protection: PortableImportProtectionGuarantee(
                activeRunsUnchanged: true,
                completedHistoryUnchanged: true,
                existingDataMutatedOnlyAfterExplicitResolution: true
            )
        )
    }

    private static func packageChecksum(_ component: PortableTrainingComponentDescriptor) -> String {
        SHA256.hash(data: component.payload).map { String(format: "%02x", $0) }.joined()
    }

    private static func compareBuild(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}

#endif
