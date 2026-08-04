import Foundation

/// Presentation and comparison policy for independent occurrences of one
/// catalogue exercise. Stable identity remains the existing exposure/
/// progression key; this policy never substitutes a display label for it.
nonisolated enum WorkoutOccurrenceSnapshotPolicy {
    nonisolated static func occurrenceLabel(
        catalogueName: String,
        progressionKey: String?,
        role: ExerciseRole?
    ) -> String? {
        if let progressionKey,
           !progressionKey.isEmpty,
           UUID(uuidString: progressionKey) == nil {
            let words = progressionKey
                .replacingOccurrences(of: "_", with: "-")
                .split(separator: "-")
                .map { word in
                    let value = String(word)
                    return value.count <= 3 ? value.uppercased() : value.capitalized
                }
                .joined(separator: " ")
            if normalized(words) != normalized(catalogueName) {
                return words
            }
        }
        guard let role, role != .main else { return nil }
        return role.rawValue.capitalized
    }

    nonisolated static func displayName(
        catalogueName: String,
        progressionKey: String?,
        role: ExerciseRole?
    ) -> String {
        guard let label = occurrenceLabel(
            catalogueName: catalogueName,
            progressionKey: progressionKey,
            role: role
        ) else { return catalogueName }
        return "\(catalogueName) — \(label)"
    }

    nonisolated static func comparisonKey(
        historicalExerciseID: UUID,
        progressionKey: String?,
        role: ExerciseRole?
    ) -> String {
        let occurrence = progressionKey.flatMap { $0.isEmpty ? nil : $0 }
            ?? role.flatMap { $0 == .main ? nil : $0.rawValue }
            ?? ""
        return "\(historicalExerciseID.uuidString)|\(occurrence)"
    }

    private nonisolated static func normalized(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter }
    }
}

extension TemplateExercise {
    var occurrenceLabel: String? {
        WorkoutOccurrenceSnapshotPolicy.occurrenceLabel(
            catalogueName: exercise.name,
            progressionKey: progressionKey,
            role: nil
        )
    }
}

extension PlannedExercise {
    var occurrenceLabel: String? {
        WorkoutOccurrenceSnapshotPolicy.occurrenceLabel(
            catalogueName: exercise.name,
            progressionKey: progressionKey,
            role: role
        )
    }

    var occurrenceDisplayName: String {
        WorkoutOccurrenceSnapshotPolicy.displayName(
            catalogueName: exercise.name,
            progressionKey: progressionKey,
            role: role
        )
    }
}

extension ExerciseEntry {
    var occurrenceLabel: String? {
        WorkoutOccurrenceSnapshotPolicy.occurrenceLabel(
            catalogueName: displayName,
            progressionKey: progressionKey,
            role: prescribedRole
        )
    }

    var occurrenceDisplayName: String {
        WorkoutOccurrenceSnapshotPolicy.displayName(
            catalogueName: displayName,
            progressionKey: progressionKey,
            role: prescribedRole
        )
    }

    var occurrenceComparisonKey: String {
        WorkoutOccurrenceSnapshotPolicy.comparisonKey(
            historicalExerciseID: historicalExerciseID,
            progressionKey: progressionKey,
            role: prescribedRole
        )
    }
}
