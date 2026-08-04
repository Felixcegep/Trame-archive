import Foundation
import SwiftData

enum SystemSeedEntityKind: String, Codable, CaseIterable {
    case exercise
    case exerciseRelationship
    case workoutTemplate
    case workoutCollection
    case workoutPlan
    case repeatingPlan
    case programDefinition
    case mobilityProgramDefinition
    case mobilityFamily
    case mobilityDefinition
    case mobilityRoutine
    case mobilityAssessmentDefinition
    case foodItem
    case foodServing
    case mealTemplate
}

enum SystemSeedSourceKind: String, Codable, CaseIterable {
    case bundled
    case curated
    case migratedLegacy
}

/// Installation bookkeeping for bundled catalogue content.
///
/// Domain records continue to own user data and completed snapshots. This
/// record only identifies which live definition a stable seed key owns and
/// which bundled revision was applied successfully.
@Model
final class SystemSeedRecord {
    @Attribute(.unique) var seedKey: String
    var entityKindRaw: String
    var entityID: UUID
    var seedVersion: Int
    var contentVersion: Int
    var sourceKindRaw: String
    var isSystemProvided: Bool
    var isDeprecated: Bool
    var replacementSeedKey: String?
    var createdAt: Date
    var updatedAt: Date

    var entityKind: SystemSeedEntityKind {
        get { SystemSeedEntityKind(rawValue: entityKindRaw) ?? .exercise }
        set { entityKindRaw = newValue.rawValue }
    }

    var sourceKind: SystemSeedSourceKind {
        get { SystemSeedSourceKind(rawValue: sourceKindRaw) ?? .bundled }
        set { sourceKindRaw = newValue.rawValue }
    }

    init(
        seedKey: String,
        entityKind: SystemSeedEntityKind,
        entityID: UUID,
        seedVersion: Int,
        contentVersion: Int,
        sourceKind: SystemSeedSourceKind = .bundled,
        isSystemProvided: Bool = true,
        isDeprecated: Bool = false,
        replacementSeedKey: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.seedKey = seedKey
        entityKindRaw = entityKind.rawValue
        self.entityID = entityID
        self.seedVersion = seedVersion
        self.contentVersion = contentVersion
        sourceKindRaw = sourceKind.rawValue
        self.isSystemProvided = isSystemProvided
        self.isDeprecated = isDeprecated
        self.replacementSeedKey = replacementSeedKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum SystemSeedKey {
    static func make(namespace: String, legacyName: String) -> String {
        let folded = legacyName
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        var slug = ""
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                slug.append(Character(String(scalar)))
            } else if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                slug.append("-")
            } else {
                switch scalar {
                case "-": slug.append("--")
                case "+": slug.append("-plus-")
                case "/": slug.append("-slash-")
                default: slug.append("-u\(String(scalar.value, radix: 16))-")
                }
            }
        }
        while slug.hasPrefix("-") { slug.removeFirst() }
        while slug.hasSuffix("-") { slug.removeLast() }
        return "\(namespace).\(slug)"
    }

    /// Folds a name down to a punctuation- and whitespace-insensitive
    /// identity for detecting "same movement, different spelling" -- e.g.
    /// "Pull Up" and "Pull-Up" both fold to "pullup".
    ///
    /// `make(namespace:legacyName:)` cannot double as this check: it turns
    /// a space into "-" and escapes a literal "-" as "--", so those two
    /// names still produce distinct keys ("exercise.pull-up" vs
    /// "exercise.pull--up") even though they name the same exercise. That
    /// gap is exactly how the legacy and imported catalogues both shipped a
    /// pull-up record. This normalization strips separators entirely
    /// instead of re-encoding them, so callers that need to ask "is this
    /// the same exercise as that one" (like `ExerciseSeedData.templates()`
    /// deduping its two source catalogues) get a real equality check
    /// instead of a key comparison that punctuation can slip through.
    static func normalizedComparisonKey(_ name: String) -> String {
        let folded = name
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        return String(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init))
    }
}
