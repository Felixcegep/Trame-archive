import Foundation
import SwiftData

struct OrphanCleanupResult: Equatable {
    let deletedExercises: Int
    let deletedSets: Int
    let deletedTemplateExercises: Int

    var hasChanges: Bool {
        deletedExercises > 0 || deletedSets > 0 || deletedTemplateExercises > 0
    }
}

/// Repairs records created before the ownership graph had explicit inverses and
/// cascade rules. The work is deliberately idempotent so it is safe to invoke
/// from tests and during recovery.
enum DataMaintenanceService {
    static let orphanCleanupVersion = 1

    static func runOrphanCleanupIfNeeded(
        using context: ModelContext,
        defaults: UserDefaults = .standard
    ) throws -> OrphanCleanupResult? {
        guard defaults.integer(forKey: DefaultsKey.orphanCleanupVersion) < orphanCleanupVersion else {
            return nil
        }

        let result = try cleanupOrphans(using: context)
        defaults.set(orphanCleanupVersion, forKey: DefaultsKey.orphanCleanupVersion)
        return result
    }

    @discardableResult
    static func cleanupOrphans(using context: ModelContext) throws -> OrphanCleanupResult {
        do {
            let orphanSets = try context.fetch(FetchDescriptor<ExerciseSet>(
                predicate: #Predicate { $0.exerciseEntry == nil }
            ))
            for set in orphanSets {
                context.delete(set)
            }

            let orphanEntries = try context.fetch(FetchDescriptor<ExerciseEntry>(
                predicate: #Predicate { $0.workout == nil }
            ))
            for entry in orphanEntries {
                context.delete(entry)
            }

            let orphanTemplateExercises = try context.fetch(FetchDescriptor<TemplateExercise>(
                predicate: #Predicate { $0.workoutTemplate == nil }
            ))
            for templateExercise in orphanTemplateExercises {
                context.delete(templateExercise)
            }

            if !orphanSets.isEmpty || !orphanEntries.isEmpty || !orphanTemplateExercises.isEmpty {
                try context.save()
            }

            return OrphanCleanupResult(
                deletedExercises: orphanEntries.count,
                deletedSets: orphanSets.count,
                deletedTemplateExercises: orphanTemplateExercises.count
            )
        } catch {
            context.rollback()
            throw error
        }
    }
}
