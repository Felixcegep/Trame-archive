import Foundation

#if !GYMTRACKER_EXTENSION

enum HealthKitBackupValidator {
    static func validate(_ backup: BackupDTO) throws {
        guard backup.version >= BackupDTO.healthKitIntegrationVersion else { return }

        let bodyWeightIDs = Set(backup.bodyWeightEntries.compactMap { UUID(uuidString: $0.id) })
        var provenanceIDs = Set<String>()
        var sampleIDs = Set<String>()
        for provenance in backup.healthKitBodyMassProvenance {
            guard UUID(uuidString: provenance.id) != nil,
                  UUID(uuidString: provenance.bodyWeightEntryID) != nil,
                  bodyWeightIDs.contains(UUID(uuidString: provenance.bodyWeightEntryID)!),
                  !provenance.healthKitSampleID.isEmpty,
                  provenance.sourceBundleIdentifier.isEmpty == false,
                  provenance.valueKilograms.isFinite,
                  provenance.valueKilograms > 0,
                  provenance.sampleEndDate >= provenance.sampleStartDate,
                  provenanceIDs.insert(provenance.id).inserted,
                  sampleIDs.insert(provenance.healthKitSampleID).inserted else {
                throw BackupValidationError.invalidIdentifier("HealthKit body-mass provenance")
            }
        }

        var receiptIDs = Set<String>()
        var workoutIDs = Set<String>()
        for receipt in backup.healthKitWorkoutExportReceipts {
            guard UUID(uuidString: receipt.id) != nil,
                  UUID(uuidString: receipt.workoutID) != nil,
                  backup.workouts.contains(where: { $0.id == receipt.workoutID }),
                  HealthKitWorkoutExportStatus(rawValue: receipt.status) != nil,
                  receipt.workoutEndDate >= receipt.workoutStartDate,
                  receipt.completedExerciseCount >= 0,
                  receipt.completedSetCount >= 0,
                  receiptIDs.insert(receipt.id).inserted,
                  workoutIDs.insert(receipt.workoutID).inserted else {
                throw BackupValidationError.invalidIdentifier("HealthKit workout export receipt")
            }
            if let healthKitWorkoutID = receipt.healthKitWorkoutID {
                guard UUID(uuidString: healthKitWorkoutID) != nil else {
                    throw BackupValidationError.invalidIdentifier("HealthKit workout export identity")
                }
            }
        }
    }
}

#endif
