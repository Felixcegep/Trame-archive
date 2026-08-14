import Foundation

/// Validates program domain entities within a backup archive:
/// program definitions, plans, plan runs, repeating plans, progression state, and recommendation records.
nonisolated enum ProgramBackupValidator {
    static func validate(_ dto: BackupDTO) throws {
        let planIDs = Set(dto.plans.map { $0.id.lowercased() })
        
        for run in dto.planRuns {
            if let planID = run.planID?.lowercased() {
                guard planIDs.contains(planID) else {
                    throw BackupValidationError.missingPlan(planID)
                }
            }
        }

        let repeatingPlanIDs = Set(dto.repeatingPlans.map { $0.id.lowercased() })
        for repeatingRun in dto.repeatingPlanRuns {
            if let planID = repeatingRun.planID?.lowercased() {
                guard repeatingPlanIDs.contains(planID) else {
                    throw BackupValidationError.missingPlan(planID)
                }
            }
        }
    }
}
