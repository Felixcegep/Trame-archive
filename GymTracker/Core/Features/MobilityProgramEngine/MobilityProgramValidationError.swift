import Foundation

#if !GYMTRACKER_EXTENSION

nonisolated struct MobilityProgramValidationIssue: Codable, Hashable, Identifiable {
    enum Code: String, Codable, Hashable {
        case invalidSchemaVersion
        case emptyProgramKey
        case emptyName
        case invalidDuration
        case invalidSchedule
        case emptyBlocks
        case emptyWeeks
        case emptySessions
        case invalidDayIndex
        case emptySessionKey
        case duplicateSessionKey
        case duplicateOrderIndex
        case sessionWeekIndexMismatch
        case emptyOccurrences
        case emptyOccurrenceID
        case duplicateOccurrenceID
        case invalidCycleCount
        case invalidPhaseSequence
        case invalidTargets
        case invalidRest
        case invalidCompletionRule
        case emptyBlockKey
        case duplicateBlockKey
        case blockNestedInBlock
        case unknownBlockReference
        case duplicateIdentifier
        case invalidProvenance
    }

    var id: UUID = UUID()
    var path: String
    var code: Code
    var message: String
}

/// Structural, catalog-free validation for a `MobilityProgramDefinitionPayload`,
/// mirroring `ProgramDefinitionValidator`'s idiom. Unresolvable
/// `MobilityDefinition` references are a catalog-aware concern and are
/// validated separately, by `MobilityProgramCompiler`, exactly like the
/// workout engine splits structural validation from exercise-catalog
/// validation.
nonisolated enum MobilityProgramDefinitionValidator {
    static func validate(
        _ definition: MobilityProgramDefinitionPayload,
        isBuiltIn: Bool = false
    ) -> [MobilityProgramValidationIssue] {
        var issues: [MobilityProgramValidationIssue] = []
        func add(_ path: String, _ code: MobilityProgramValidationIssue.Code, _ message: String) {
            issues.append(MobilityProgramValidationIssue(path: path, code: code, message: message))
        }

        if definition.schemaVersion < 1 { add("schemaVersion", .invalidSchemaVersion, "Schema version must be positive.") }
        if definition.templateVersion < 1 { add("templateVersion", .invalidSchemaVersion, "Template version must be positive.") }
        if isBuiltIn, definition.programKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add("programKey", .emptyProgramKey, "A built-in mobility program requires a stable program key.")
        }
        if definition.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add("name", .emptyName, "A mobility program name is required.")
        }
        if definition.durationWeeks < 1 {
            add("durationWeeks", .invalidDuration, "A mobility program must contain at least one week.")
        }
        if definition.supportedDaysPerWeek.isEmpty || definition.supportedDaysPerWeek.contains(where: { $0 < 1 || $0 > 7 }) {
            add("supportedDaysPerWeek", .invalidSchedule, "Supported days must be between one and seven.")
        }
        if definition.blocks.isEmpty { add("blocks", .emptyBlocks, "A mobility program must contain a block.") }
        if definition.provenance == nil, definition.sourceReferences?.isEmpty == false {
            add("sourceReferences", .invalidProvenance, "Source references require an explicit provenance classification.")
        }
        for (index, reference) in (definition.sourceReferences ?? []).enumerated() {
            let path = "sourceReferences[\(index)]"
            if reference.organizationOrAuthors.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || reference.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || reference.sourceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                add(path, .invalidProvenance, "A source reference requires authorship, title, and a stable source identifier.")
            }
        }

        var identifiers = Set<UUID>()
        func checkID(_ id: UUID, _ path: String) {
            if !identifiers.insert(id).inserted { add(path, .duplicateIdentifier, "Identifier is used more than once.") }
        }

        var sessionKeys = Set<String>()
        var blockOrders = Set<Int>()
        for (blockIndex, block) in definition.blocks.enumerated() {
            let blockPath = "blocks[\(blockIndex)]"
            checkID(block.id, blockPath)
            if !blockOrders.insert(block.orderIndex).inserted {
                add("\(blockPath).orderIndex", .duplicateOrderIndex, "Block order indices must be unique within the program.")
            }
            if block.weeks.isEmpty { add(blockPath, .emptyWeeks, "A block must contain a week.") }

            var weekIndices = Set<Int>()
            for (weekIndex, week) in block.weeks.enumerated() {
                let weekPath = "\(blockPath).weeks[\(weekIndex)]"
                checkID(week.id, weekPath)
                if !weekIndices.insert(week.weekIndex).inserted {
                    add("\(weekPath).weekIndex", .duplicateOrderIndex, "Week indices must be unique within a block.")
                }
                if week.sessions.isEmpty { add(weekPath, .emptySessions, "A week must contain a session.") }

                var sessionSlots = Set<String>()
                for (sessionIndex, session) in week.sessions.enumerated() {
                    let sessionPath = "\(weekPath).sessions[\(sessionIndex)]"
                    checkID(session.id, sessionPath)
                    let key = session.sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    if key.isEmpty {
                        add("\(sessionPath).sessionKey", .emptySessionKey, "Every session needs a stable key.")
                    } else if !sessionKeys.insert(key).inserted {
                        add("\(sessionPath).sessionKey", .duplicateSessionKey, "Session keys must be unique within a program.")
                    }
                    if session.weekIndex != week.weekIndex {
                        add("\(sessionPath).weekIndex", .sessionWeekIndexMismatch, "A session's weekIndex must match its owning week.")
                    }
                    if session.dayIndex < 0 || session.dayIndex > 6 {
                        add("\(sessionPath).dayIndex", .invalidDayIndex, "Day index must be between zero and six.")
                    }
                    let slot = "\(session.dayIndex)|\(session.sameDayOrder)"
                    if !sessionSlots.insert(slot).inserted {
                        add("\(sessionPath).sameDayOrder", .duplicateOrderIndex, "Same-day order must be unique among sessions sharing a day within a week.")
                    }
                    validateRecipe(session.recipe, path: "\(sessionPath).recipe", checkID: checkID, add: add)
                }
            }
        }

        return issues
    }

    private static func validateRecipe(
        _ recipe: MobilityRoutineRecipeDefinition,
        path: String,
        checkID: (UUID, String) -> Void,
        add: (String, MobilityProgramValidationIssue.Code, String) -> Void
    ) {
        if recipe.occurrences.isEmpty {
            add(path, .emptyOccurrences, "A routine recipe must contain a movement occurrence.")
        }

        var blockKeys = Set<String>()
        var blockOrders = Set<Int>()
        for (blockIndex, block) in recipe.blocks.enumerated() {
            let blockPath = "\(path).blocks[\(blockIndex)]"
            checkID(block.id, blockPath)
            let key = block.blockKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty {
                add("\(blockPath).blockKey", .emptyBlockKey, "Every block needs a stable key.")
            } else if !blockKeys.insert(key).inserted {
                add("\(blockPath).blockKey", .duplicateBlockKey, "Block keys must be unique within a session recipe.")
            }
            if !blockOrders.insert(block.orderIndex).inserted {
                add("\(blockPath).orderIndex", .duplicateOrderIndex, "Block order indices must be unique within a session recipe.")
            }
            if let rest = block.restPrescription, rest.isValid == false {
                add("\(blockPath).restPrescription", .invalidRest, "Block rest prescription is invalid.")
            }
            if let rounds = block.targetRounds, rounds <= 0 {
                add("\(blockPath).targetRounds", .invalidCycleCount, "Target rounds must be positive.")
            }
        }
        // `MobilityProgramRoutineBlockDefinition` has no field capable of
        // referencing another block, so a block nested inside a block cannot
        // be authored in this payload shape at all — the same structural
        // guarantee `MobilityRoutineBlock` documents. `.blockNestedInBlock`
        // is retained in the issue vocabulary for a portable boundary (e.g.
        // backup restore) that decodes a foreign/tampered payload shape.

        var occurrenceOrders = Set<Int>()
        var occurrenceIDs = Set<String>()
        for (index, occurrence) in recipe.occurrences.enumerated() {
            let occurrencePath = "\(path).occurrences[\(index)]"
            checkID(occurrence.id, occurrencePath)
            let occurrenceID = occurrence.occurrenceID.trimmingCharacters(in: .whitespacesAndNewlines)
            if occurrenceID.isEmpty {
                add("\(occurrencePath).occurrenceID", .emptyOccurrenceID, "Every occurrence needs a stable occurrenceID.")
            } else if !occurrenceIDs.insert(occurrenceID).inserted {
                add("\(occurrencePath).occurrenceID", .duplicateOccurrenceID, "occurrenceID must be unique within a session, even for repeated movements.")
            }
            if !occurrenceOrders.insert(occurrence.orderIndex).inserted {
                add("\(occurrencePath).orderIndex", .duplicateOrderIndex, "Occurrence order indices must be unique within a session.")
            }
            if let blockKey = occurrence.blockKey, !blockKeys.contains(blockKey) {
                add("\(occurrencePath).blockKey", .unknownBlockReference, "The occurrence references a block that does not exist in this session recipe.")
            }
            if occurrence.cycleCount < 1 {
                add("\(occurrencePath).cycleCount", .invalidCycleCount, "Cycle count must be positive.")
            }
            if occurrence.targets.isValid == false {
                add("\(occurrencePath).targets", .invalidTargets, "Typed metric targets are invalid.")
            }
            if let rest = occurrence.restPrescription, rest.isValid == false {
                add("\(occurrencePath).restPrescription", .invalidRest, "Occurrence rest prescription is invalid.")
            }
            validatePhases(occurrence.phases, path: "\(occurrencePath).phases", checkID: checkID, add: add)
            validateCompletionAgainstProfile(occurrence, path: occurrencePath, add: add)
        }
    }

    private static func validatePhases(
        _ phases: [MobilityProgramPhaseDefinition],
        path: String,
        checkID: (UUID, String) -> Void,
        add: (String, MobilityProgramValidationIssue.Code, String) -> Void
    ) {
        guard phases.isEmpty == false else { return }
        var orders = Set<Int>()
        for (index, phase) in phases.enumerated() {
            let phasePath = "\(path)[\(index)]"
            checkID(phase.id, phasePath)
            if phase.orderIndex < 0 || !orders.insert(phase.orderIndex).inserted {
                add("\(phasePath).orderIndex", .invalidPhaseSequence, "Phase order indices must be non-negative and unique within an occurrence.")
            }
            if phase.durationSeconds <= 0 {
                add("\(phasePath).durationSeconds", .invalidPhaseSequence, "Phase duration must be positive.")
            }
        }
    }

    /// A completion rule requiring a metric the profile does not support is
    /// rejected wherever the author supplied an explicit `metricProfile`; a
    /// profile-less occurrence resolves its completion rule from the
    /// catalogued `MobilityDefinition`'s tracking type at compile time and is
    /// validated there instead (mirrors the workout engine's split between
    /// `ProgramDefinitionValidator` and `ProgramMetricCompletionValidator`).
    private static func validateCompletionAgainstProfile(
        _ occurrence: MobilityMovementOccurrenceDefinition,
        path: String,
        add: (String, MobilityProgramValidationIssue.Code, String) -> Void
    ) {
        guard let profile = occurrence.metricProfile else { return }
        if profile.supportedMetrics.isEmpty {
            add("\(path).metricProfile", .invalidCompletionRule, "A metric profile must support at least one metric.")
        }
        if let primary = profile.primaryProgressMetric, profile.supportedMetrics.contains(primary) == false {
            add("\(path).metricProfile.primaryProgressMetric", .invalidCompletionRule, "The primary progress metric must be one of the profile's supported metrics.")
        }
        switch profile.defaultCompletionRule {
        case .all(let metrics), .any(let metrics):
            if metrics.isEmpty {
                add("\(path).metricProfile.defaultCompletionRule", .invalidCompletionRule, "A metric completion rule must include at least one metric.")
            }
            let unsupported = metrics.subtracting(profile.completionWritableMetrics)
            if !unsupported.isEmpty {
                let names = unsupported.sorted { $0.rawValue < $1.rawValue }.map(\.rawValue).joined(separator: ", ")
                add("\(path).metricProfile.defaultCompletionRule", .invalidCompletionRule, "These metrics cannot currently require session completion: \(names).")
            }
        case .prescribedTargets:
            let usable = occurrence.targets.prescribedMetrics.intersection(profile.completionWritableMetrics)
            if usable.isEmpty {
                add("\(path).metricProfile.defaultCompletionRule", .invalidCompletionRule, "Prescribed-target completion requires at least one explicit typed target the profile can write.")
            }
        case .phaseSequenceCompleted:
            if occurrence.phases.isEmpty {
                add("\(path).metricProfile.defaultCompletionRule", .invalidCompletionRule, "Phase-sequence completion requires at least one authored phase.")
            }
        }
    }
}

#endif
