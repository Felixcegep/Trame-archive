import Foundation

nonisolated enum ReceiptBackupValidator {
    static func validate(_ backup: BackupDTO) throws {
        if backup.version >= BackupDTO.programVersion {
            try validateUniqueIdentifiers(
                backup.progressionRecommendations.map(\.id),
                named: "progression recommendation"
            )
            let runIDs = Set(backup.planRuns.map(\.id))
            let completedWorkoutIDs = Set(backup.workouts.compactMap(\.id))

            for recommendation in backup.progressionRecommendations {
                guard runIDs.contains(recommendation.planRunID),
                      completedWorkoutIDs.contains(recommendation.workoutID),
                      UUID(uuidString: recommendation.ruleID) != nil,
                      ProgressionCadence(rawValue: recommendation.cadence) != nil,
                      ProgressionScope(rawValue: recommendation.scope) != nil,
                      ProgressionApplicationMode(rawValue: recommendation.applicationMode) != nil,
                      (try? JSONDecoder().decode(ProgressionAction.self, from: recommendation.actionData)) != nil
                else {
                    throw BackupValidationError.invalidIdentifier("progression recommendation")
                }

                if let decisionOutcome = recommendation.decisionOutcome {
                    guard ProgressionDecisionOutcome(rawValue: decisionOutcome) != nil else {
                        throw BackupValidationError.invalidIdentifier("progression recommendation decision outcome")
                    }
                }
                if let proposedLoadUnit = recommendation.proposedLoadUnit {
                    guard WeightType(rawValue: proposedLoadUnit) != nil else {
                        throw BackupValidationError.invalidIdentifier("progression recommendation load unit")
                    }
                }
            }
        }
    }

    private static func validateUniqueIdentifiers(_ identifiers: [String], named name: String) throws {
        guard Set(identifiers).count == identifiers.count else {
            let duplicate = Dictionary(grouping: identifiers, by: \.self)
                .first(where: { $0.value.count > 1 })?.key ?? "Unknown"
            throw BackupValidationError.duplicateIdentifier("\(name) (\(duplicate))")
        }
        for identifier in identifiers {
            guard UUID(uuidString: identifier) != nil else {
                throw BackupValidationError.invalidIdentifier("\(name) (\(identifier))")
            }
        }
    }
}
