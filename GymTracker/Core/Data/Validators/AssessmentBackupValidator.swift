import Foundation

enum AssessmentBackupValidator {
    static func validate(_ backup: BackupDTO) throws {
        let definitions = backup.mobilityAssessmentDefinitions
        let mobilityAssessmentSessions = backup.mobilityAssessmentSessions

        try validateUniqueIdentifiers(definitions.map(\.id), named: "mobility assessment definition")
        let catalogueKeys = definitions.map(\.catalogueKey)
        guard Set(catalogueKeys).count == catalogueKeys.count else {
            throw BackupValidationError.duplicateIdentifier("mobility assessment catalogue key")
        }

        let definitionsByKey = Dictionary(
            definitions.map { ($0.catalogueKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for definition in definitions {
            guard let preferredMode = MobilityMeasurementMode(rawValue: definition.preferredMode),
                  let manualMode = MobilityMeasurementMode(rawValue: definition.manualMode),
                  let unit = MobilityMeasurementUnit(rawValue: definition.unit),
                  MobilityAssessmentZone(rawValue: definition.zone) != nil,
                  definition.definitionVersion > 0,
                  !definition.name.isEmpty,
                  !definition.nameLocalizationKey.isEmpty,
                  !definition.instructionsLocalizationKey.isEmpty,
                  !definition.setupInstructionsLocalizationKey.isEmpty,
                  !definition.measurementDescriptionLocalizationKey.isEmpty,
                  !definition.measurementLimitationsLocalizationKey.isEmpty,
                  manualMode.isManual,
                  manualMode != .cameraPose,
                  measurementUnit(unit, supports: manualMode),
                  preferredMode != .cameraPose,
                  !definition.supportedSides.isEmpty,
                  Set(definition.supportedSides).count == definition.supportedSides.count,
                  definition.supportedSides.allSatisfy({ MobilityAssessmentSide(rawValue: $0) != nil }),
                  !definition.setupKeys.isEmpty,
                  Set(definition.setupKeys).count == definition.setupKeys.count,
                  definition.setupKeys.contains(definition.defaultSetupKey)
            else {
                throw BackupValidationError.invalidIdentifier("mobility assessment definition")
            }
        }

        try validateUniqueIdentifiers(mobilityAssessmentSessions.map(\.id), named: "mobility assessment session")
        var resultIDs = [String]()
        var sampleIDs = [String]()
        var activeSessionCount = 0

        for session in mobilityAssessmentSessions {
            guard let status = MobilityAssessmentSessionStatus(rawValue: session.status),
                  isValidLocalDayKey(session.dayKey),
                  !session.selectedDefinitionKeys.isEmpty,
                  Set(session.selectedDefinitionKeys).count == session.selectedDefinitionKeys.count,
                  session.selectedDefinitionKeys.allSatisfy({ definitionsByKey[$0] != nil }),
                  Set(session.skippedDefinitionKeys).count == session.skippedDefinitionKeys.count,
                  Set(session.skippedDefinitionKeys).isSubset(of: Set(session.selectedDefinitionKeys)),
                  (0...session.selectedDefinitionKeys.count).contains(session.currentDefinitionIndex),
                  (status == .active) == (session.completedAt == nil)
            else {
                throw BackupValidationError.invalidIdentifier("mobility assessment session")
            }
            if status == .active { activeSessionCount += 1 }

            var resultKeys = Set<String>()
            for result in session.results {
                resultIDs.append(result.id)
                guard let definition = definitionsByKey[result.definitionCatalogueKeySnapshot],
                      let side = MobilityAssessmentSide(rawValue: result.side),
                      let method = MobilityMeasurementMode(rawValue: result.method),
                      let unit = MobilityMeasurementUnit(rawValue: result.unit),
                      let source = MobilityMeasurementSource(rawValue: result.source),
                      let confidence = MobilityMeasurementConfidence(rawValue: result.confidence),
                      result.orderIndex >= 0,
                      isValidLocalDayKey(result.dayKey),
                      UUID(uuidString: result.definitionIDSnapshot) != nil,
                      result.definitionVersionSnapshot > 0,
                      !result.definitionNameSnapshot.isEmpty,
                      !result.instructionsLocalizationKeySnapshot.isEmpty,
                      !result.setupInstructionsLocalizationKeySnapshot.isEmpty,
                      !result.measurementDescriptionLocalizationKeySnapshot.isEmpty,
                      !result.measurementLimitationsLocalizationKeySnapshot.isEmpty,
                      session.selectedDefinitionKeys.contains(result.definitionCatalogueKeySnapshot),
                      definition.supportedSides.contains(side.rawValue),
                      definition.setupKeys.contains(result.setupKey),
                      method != .cameraPose,
                      method == MobilityMeasurementMode(rawValue: definition.manualMode) || method == MobilityMeasurementMode(rawValue: definition.preferredMode),
                      measurementUnit(unit, supports: method),
                      resultKeys.insert("\(result.definitionCatalogueKeySnapshot)|\(result.side)").inserted
                else {
                    throw BackupValidationError.invalidIdentifier("mobility assessment result")
                }
                if source == .manual {
                    guard method.isManual, confidence.rank <= MobilityMeasurementConfidence.moderate.rank else {
                        throw BackupValidationError.invalidIdentifier("mobility assessment result manual confidence")
                    }
                }
                switch unit {
                case .criteria:
                    guard result.numericValue == nil,
                          let rawCriteria = result.criteria,
                          MobilityAssessmentCriteriaObservation(rawValue: rawCriteria) != nil
                    else {
                        throw BackupValidationError.invalidIdentifier("mobility assessment criteria result")
                    }
                case .degrees, .centimetres:
                    guard result.criteria == nil,
                          let numericValue = result.numericValue,
                          numericValue.isFinite
                    else {
                        throw BackupValidationError.invalidIdentifier("mobility assessment numeric result")
                    }
                }
                if let sample = result.sample {
                    sampleIDs.append(sample.id)
                    guard sample.sampleCount > 0,
                          sample.median.isFinite,
                          sample.minimum.isFinite,
                          sample.maximum.isFinite,
                          sample.minimum <= sample.median,
                          sample.median <= sample.maximum,
                          sample.standardDeviation.isFinite,
                          sample.standardDeviation >= 0,
                          sample.offAxisExcessDegrees.isFinite,
                          sample.offAxisExcessDegrees >= 0,
                          sample.captureDuration >= 0
                    else {
                        throw BackupValidationError.invalidIdentifier("mobility assessment sample")
                    }
                }
            }
        }

        guard activeSessionCount <= 1 else {
            throw BackupValidationError.invalidIdentifier("active mobility assessment session")
        }
        try validateUniqueIdentifiers(resultIDs, named: "mobility assessment result")
        try validateUniqueIdentifiers(sampleIDs, named: "mobility assessment sample")
    }

    private static func measurementUnit(_ unit: MobilityMeasurementUnit, supports method: MobilityMeasurementMode) -> Bool {
        switch method {
        case .manualAngle, .inclinometer, .axialRotation, .twoSegmentAngle, .dynamicRange:
            return unit == .degrees
        case .manualLinear:
            return unit == .centimetres
        case .manualCriteria, .cameraPose:
            return unit == .criteria
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

    private static func isValidLocalDayKey(_ value: String) -> Bool {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
            return false
        }
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        guard let date = components.date else { return false }
        let normalized = components.calendar?.dateComponents([.year, .month, .day], from: date)
        return normalized?.year == year && normalized?.month == month && normalized?.day == day
    }
}
