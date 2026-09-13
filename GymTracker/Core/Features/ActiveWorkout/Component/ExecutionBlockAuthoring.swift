import Foundation

/// Value-only authoring rules for the Active Workout grouping sheet.
///
/// The domain still stores an execution block; this type only says how many
/// exercises a format needs, which formats belong together, and what to show
/// when the lifter cannot finish yet.
enum ExecutionBlockAuthoring {
    enum ExerciseRequirement: Equatable {
        case exactly(Int)
        case atLeast(Int)
    }

    enum FormatFamily: String, CaseIterable, Equatable {
        case pairing
        case timed
        case sequence

        var kinds: [ExerciseBlockKind] {
            switch self {
            case .pairing: [.pairedSet, .triset, .giantSet, .circuit]
            case .timed: [.amrap, .emom, .forTime, .interval]
            case .sequence: [.chipper, .ladder, .olympicComplex, .medley, .straight]
            }
        }
    }

    static func exerciseRequirement(for kind: ExerciseBlockKind) -> ExerciseRequirement {
        switch kind {
        case .straight: .exactly(1)
        case .pairedSet: .exactly(2)
        case .triset: .exactly(3)
        case .giantSet: .atLeast(4)
        default: .atLeast(1)
        }
    }

    static func meetsExerciseRequirement(_ count: Int, kind: ExerciseBlockKind) -> Bool {
        switch exerciseRequirement(for: kind) {
        case .exactly(let expected): count == expected
        case .atLeast(let minimum): count >= minimum
        }
    }

    static func selectionStatus(kind: ExerciseBlockKind, selected: Int) -> String {
        switch exerciseRequirement(for: kind) {
        case .exactly(let expected):
            if selected == 0 { return kind.exerciseSelectionHint }
            return String(localized: "\(selected) of \(expected) selected")
        case .atLeast(let minimum):
            if selected == 0 { return kind.exerciseSelectionHint }
            if selected < minimum {
                return String(localized: "Select \(minimum - selected) more")
            }
            return String(localized: "\(selected) selected")
        }
    }

    static func saveDisabledReason(
        kind: ExerciseBlockKind,
        selectedCount: Int,
        availableCount: Int,
        sessionExerciseCount: Int
    ) -> String? {
        if meetsExerciseRequirement(selectedCount, kind: kind) { return nil }
        if sessionExerciseCount == 0 {
            return String(localized: "Add an exercise to this workout first.")
        }
        if availableCount == 0 {
            return String(localized: "Every exercise is already in a group. Add another exercise to continue.")
        }
        return kind.exerciseSelectionHint
    }

    static func groupedSubtitle(blockName: String?, kindTitle: String) -> String {
        let trimmed = blockName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let label = trimmed.isEmpty ? kindTitle : trimmed
        return String(localized: "In \(label)")
    }

    /// A new group with exactly one eligible exercise should start selected
    /// when the format accepts a single component, so the primary action is
    /// immediately available instead of a disabled Add with no next step.
    static func shouldPreselectSingleAvailableExercise(
        isEditing: Bool,
        availableCount: Int,
        kind: ExerciseBlockKind
    ) -> Bool {
        !isEditing && availableCount == 1 && meetsExerciseRequirement(1, kind: kind)
    }
}
