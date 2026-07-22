import Foundation
import SwiftData

enum ExerciseRelationshipSeedData {
    struct SeedResult: Equatable {
        var insertedCount: Int
        var unresolvedNames: Set<String>
    }

    struct Definition {
        let source: String
        let target: String
        let type: ExerciseRelationshipType
    }

    @MainActor
    static func seed(in context: ModelContext, saveChanges: Bool = true) throws -> SeedResult {
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let byName = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0) })
        let existing = try context.fetch(FetchDescriptor<ExerciseRelationship>())
        var existingKeys = Set(existing.compactMap { relationship -> String? in
            guard let source = relationship.sourceExercise, let target = relationship.targetExercise else { return nil }
            return key(source.id, target.id, relationship.type)
        })
        var unresolvedNames = Set<String>()
        var insertedCount = 0

        for definition in definitions {
            guard let source = byName[definition.source], let target = byName[definition.target] else {
                if byName[definition.source] == nil { unresolvedNames.insert(definition.source) }
                if byName[definition.target] == nil { unresolvedNames.insert(definition.target) }
                continue
            }
            let relationshipKey = key(source.id, target.id, definition.type)
            guard existingKeys.insert(relationshipKey).inserted else { continue }
            context.insert(
                ExerciseRelationship(
                    sourceExercise: source,
                    targetExercise: target,
                    type: definition.type
                )
            )
            insertedCount += 1
        }

        assert(unresolvedNames.isEmpty, "Unresolved seeded exercise relationships: \(unresolvedNames.sorted())")
        if insertedCount > 0 && saveChanges { try context.save() }
        return SeedResult(insertedCount: insertedCount, unresolvedNames: unresolvedNames)
    }

    private static func key(_ sourceID: UUID, _ targetID: UUID, _ type: ExerciseRelationshipType) -> String {
        "\(sourceID.uuidString)|\(targetID.uuidString)|\(type.rawValue)"
    }

    static let definitions: [Definition] = [
        .init(source: "Assisted Pull-Up", target: "Neutral-Grip Pull-Up", type: .progression),
        .init(source: "Neutral-Grip Pull-Up", target: "Pull-Up", type: .progression),
        .init(source: "Pull-Up", target: "Weighted Pull-Up", type: .progression),
        .init(source: "Pull-Up", target: "Neutral-Grip Pull-Up", type: .regression),
        .init(source: "Incline Push-Up", target: "Push-Up", type: .progression),
        .init(source: "Push-Up", target: "Decline Push-Up", type: .progression),
        .init(source: "Decline Push-Up", target: "Pseudo Planche Push-Up", type: .progression),
        .init(source: "Pseudo Planche Push-Up", target: "Weighted Push-Up", type: .progression),
        .init(source: "Box Squat (Bodyweight)", target: "Bodyweight Squat", type: .progression),
        .init(source: "Bodyweight Squat", target: "Bulgarian Split Squat", type: .progression),
        .init(source: "Bulgarian Split Squat", target: "Shrimp Squat", type: .progression),
        .init(source: "Glute Bridge", target: "Single-Leg Glute Bridge", type: .progression),
        .init(source: "Single-Leg Glute Bridge", target: "Romanian Deadlift", type: .progression),
        .init(source: "Romanian Deadlift", target: "Nordic Curl (Assisted)", type: .progression),
        .init(source: "Incline Ring Row", target: "Ring Row", type: .progression),
        .init(source: "Ring Row", target: "Chest-Supported Row", type: .progression),
        .init(source: "Chest-Supported Row", target: "Front Lever Row (Tuck)", type: .progression),
        .init(source: "Crunch", target: "Hanging Knee Raise", type: .progression),
        .init(source: "Hanging Knee Raise", target: "Hanging Leg Raise", type: .progression),
        .init(source: "Plank", target: "Side Plank", type: .progression),
        .init(source: "Side Plank", target: "Copenhagen Plank", type: .progression),
        .init(source: "Dip", target: "Weighted Dip", type: .progression),
        .init(source: "Bench Press", target: "Close-Grip Bench Press", type: .substitution),
        .init(source: "Back Squat", target: "Front Squat", type: .substitution),
        .init(source: "Lat Pulldown", target: "Assisted Pull-Up", type: .substitution)
    ]
}
