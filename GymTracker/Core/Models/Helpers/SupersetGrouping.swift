import Foundation

/// Shared integrity rules for the flat, snapshot-local superset identifier.
/// A valid group has at least two contiguous members in ordered collection
/// order. This deliberately dissolves invalid data rather than moving an
/// exercise the user intentionally reordered.
enum SupersetGrouping {
    static func dissolveInvalidGroups(in exercises: [ExerciseEntry]) {
        dissolveInvalidGroups(
            in: exercises,
            groupID: \ExerciseEntry.supersetGroupID
        )
    }

    static func dissolveInvalidGroups(in exercises: [TemplateExercise]) {
        dissolveInvalidGroups(
            in: exercises,
            groupID: \TemplateExercise.supersetGroupID
        )
    }

    static func dissolveInvalidGroups(in exercises: [PlannedExercise]) {
        dissolveInvalidGroups(
            in: exercises,
            groupID: \PlannedExercise.supersetGroupID
        )
    }

    private static func dissolveInvalidGroups<Member: AnyObject>(
        in members: [Member],
        groupID: ReferenceWritableKeyPath<Member, UUID?>
    ) {
        let positions = Dictionary(grouping: members.indices.compactMap { index in
            members[index][keyPath: groupID].map { ($0, index) }
        }, by: \.0)

        for (identifier, indexedMembers) in positions {
            let indexes = indexedMembers.map(\.1).sorted()
            let contiguous = indexes.enumerated().allSatisfy { offset, index in
                index == indexes[0] + offset
            }
            guard indexes.count >= 2, contiguous else {
                for member in members where member[keyPath: groupID] == identifier {
                    member[keyPath: groupID] = nil
                }
                continue
            }
        }
    }
}
