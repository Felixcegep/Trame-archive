import Foundation
import SwiftData

enum MobilityAssessmentDomainError: LocalizedError, Equatable {
    case noDefinitionsSelected
    case duplicateDefinition(String)
    case archivedDefinition(String)
    case invalidDefinition(String)
    case activeSessionAlreadyExists
    case sessionNotActive
    case definitionNotSelected
    case definitionNotCurrent
    case resultDayMismatch
    case resultValidation(MobilityAssessmentValidationError)
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .noDefinitionsSelected:
            "Select at least one assessment."
        case .duplicateDefinition(let key):
            "Assessment \(key) was selected more than once."
        case .archivedDefinition(let key):
            "Assessment \(key) is unavailable."
        case .invalidDefinition(let key):
            "Assessment \(key) has an invalid definition."
        case .activeSessionAlreadyExists:
            "An assessment session is already active."
        case .sessionNotActive:
            "This assessment session is no longer active."
        case .definitionNotSelected:
            "This assessment is not part of the session."
        case .definitionNotCurrent:
            "This assessment is not the current step."
        case .resultDayMismatch:
            "The result day must match its assessment session."
        case .resultValidation(let error):
            error.localizedDescription
        case .persistenceFailed:
            "The assessment could not be saved."
        }
    }
}

enum MobilityAssessmentValidationService {
    static func validateDefinition(
        _ definition: MobilityAssessmentDefinition
    ) -> MobilityAssessmentValidationError? {
        let sides = definition.supportedSides
        guard definition.definitionVersion > 0,
              definition.catalogueKey.isEmpty == false,
              definition.name.isEmpty == false,
              sides.isEmpty == false,
              Set(sides).count == sides.count,
              definition.setupKeys.isEmpty == false,
              Set(definition.setupKeys).count == definition.setupKeys.count,
              definition.setupKeys.contains(definition.defaultSetupKey),
              definition.manualMode.isManual,
              definition.manualMode != .cameraPose,
              unit(definition.unit, supports: definition.manualMode) else {
            return .invalidDefinition
        }
        return nil
    }

    static func validate(
        _ input: MobilityAssessmentResultInput,
        for definition: MobilityAssessmentDefinition
    ) -> MobilityAssessmentValidationError? {
        if let definitionError = validateDefinition(definition) {
            return definitionError
        }
        if input.method == .cameraPose {
            return .unsupportedCameraPose
        }
        guard definition.supportedSides.contains(input.side) else {
            return .unsupportedSide
        }
        guard definition.setupKeys.contains(input.setupKey) else {
            return .unsupportedSetup
        }
        let expectedMethod = input.source == .deviceMotion
            ? definition.preferredMode
            : definition.manualMode
        guard input.method == expectedMethod else {
            return .unsupportedMethod
        }
        guard (input.source == .manual && input.method.isManual)
                || (input.source == .deviceMotion && !input.method.isManual) else {
            return .manualSourceRequiresManualMethod
        }
        guard input.confidence.rank <= MobilityMeasurementConfidence.moderate.rank else {
            return .manualConfidenceTooHigh
        }
        guard input.unit == definition.unit, unit(input.unit, supports: input.method) else {
            return .incompatibleUnit
        }

        switch input.unit {
        case .criteria:
            guard input.numericValue == nil else { return .unexpectedNumericValue }
            guard input.criteria != nil else { return .missingCriteriaObservation }
            if let trials = input.trials, trials.isEmpty == false {
                return .unexpectedNumericValue
            }
        case .degrees, .centimetres:
            guard input.criteria == nil else { return .unexpectedCriteriaObservation }
            guard let value = input.numericValue else { return .missingNumericValue }
            guard value.isFinite else { return .nonFiniteValue }
            if let trials = input.trials {
                for trial in trials {
                    guard trial.isFinite else { return .nonFiniteValue }
                }
            }
        }
        return nil
    }

    private static func unit(
        _ unit: MobilityMeasurementUnit,
        supports method: MobilityMeasurementMode
    ) -> Bool {
        switch method {
        case .manualAngle, .inclinometer, .axialRotation, .twoSegmentAngle, .dynamicRange:
            return unit == .degrees
        case .manualLinear:
            return unit == .centimetres
        case .manualCriteria, .cameraPose:
            return unit == .criteria
        }
    }
}

@MainActor
enum MobilityAssessmentCatalogService {
    static func definitions(
        using context: ModelContext,
        includeArchived: Bool = false
    ) throws -> [MobilityAssessmentDefinition] {
        let all = try context.fetch(FetchDescriptor<MobilityAssessmentDefinition>())
        return all
            .filter { includeArchived || !$0.isArchived }
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    return $0.catalogueKey < $1.catalogueKey
                }
                return $0.sortOrder < $1.sortOrder
            }
    }

    static func definition(
        catalogueKey: String,
        using context: ModelContext
    ) throws -> MobilityAssessmentDefinition? {
        try context.fetch(FetchDescriptor<MobilityAssessmentDefinition>())
            .first { $0.catalogueKey == catalogueKey }
    }
}

@MainActor
enum MobilityAssessmentSessionService {
    static func activeSession(using context: ModelContext) throws -> MobilityAssessmentSession? {
        try context.fetch(FetchDescriptor<MobilityAssessmentSession>())
            .filter { $0.status == .active }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    static func start(
        definitions: [MobilityAssessmentDefinition],
        day: LocalDay? = nil,
        startedAt: Date = .now,
        using context: ModelContext
    ) throws -> MobilityAssessmentSession {
        guard definitions.isEmpty == false else {
            throw MobilityAssessmentDomainError.noDefinitionsSelected
        }
        if try activeSession(using: context) != nil {
            throw MobilityAssessmentDomainError.activeSessionAlreadyExists
        }

        var seen = Set<String>()
        for definition in definitions {
            guard seen.insert(definition.catalogueKey).inserted else {
                throw MobilityAssessmentDomainError.duplicateDefinition(definition.catalogueKey)
            }
            guard definition.isArchived == false else {
                throw MobilityAssessmentDomainError.archivedDefinition(definition.catalogueKey)
            }
            guard MobilityAssessmentValidationService.validateDefinition(definition) == nil else {
                throw MobilityAssessmentDomainError.invalidDefinition(definition.catalogueKey)
            }
        }

        let session = MobilityAssessmentSession(
            day: day ?? .today,
            selectedDefinitionKeys: definitions.map(\.catalogueKey),
            startedAt: startedAt,
            createdAt: startedAt,
            updatedAt: startedAt
        )
        context.insert(session)
        try save(context)
        return session
    }

    @discardableResult
    static func saveResult(
        in session: MobilityAssessmentSession,
        definition: MobilityAssessmentDefinition,
        input: MobilityAssessmentResultInput,
        now: Date = .now,
        using context: ModelContext
    ) throws -> MobilityAssessmentResult {
        try requireActive(session)
        guard let definitionIndex = session.selectedDefinitionKeys.firstIndex(of: definition.catalogueKey) else {
            throw MobilityAssessmentDomainError.definitionNotSelected
        }
        guard input.day == session.day else {
            throw MobilityAssessmentDomainError.resultDayMismatch
        }
        if let validationError = MobilityAssessmentValidationService.validate(input, for: definition) {
            throw MobilityAssessmentDomainError.resultValidation(validationError)
        }

        let sideOrder: Int
        switch input.side {
        case .left: sideOrder = 0
        case .right: sideOrder = 1
        case .combined: sideOrder = 0
        }
        let orderIndex = definitionIndex * 10 + sideOrder

        if let existing = session.results.first(where: {
            $0.definitionCatalogueKeySnapshot == definition.catalogueKey && $0.side == input.side
        }) {
            existing.orderIndex = orderIndex
            existing.numericValue = input.numericValue
            existing.criteria = input.criteria
            existing.isWarm = input.isWarm
            existing.setupKey = input.setupKey
            existing.method = input.method
            existing.unit = input.unit
            existing.isActiveRange = input.isActiveRange
            existing.day = input.day
            existing.source = input.source
            existing.confidence = input.confidence
            existing.updatedAt = now
            if let trials = input.trials, let newSample = MobilityAssessmentSample.create(from: trials, createdAt: now) {
                if let sample = existing.sample {
                    sample.sampleCount = newSample.sampleCount
                    sample.median = newSample.median
                    sample.minimum = newSample.minimum
                    sample.maximum = newSample.maximum
                    sample.standardDeviation = newSample.standardDeviation
                    sample.offAxisExcessDegrees = newSample.offAxisExcessDegrees
                    sample.captureDuration = newSample.captureDuration
                    sample.createdAt = now
                } else {
                    newSample.result = existing
                    existing.sample = newSample
                    context.insert(newSample)
                }
            } else {
                existing.sample = nil
            }
            session.updatedAt = now
            session.skippedDefinitionKeys.removeAll { $0 == definition.catalogueKey }
            try save(context)
            return existing
        }

        let result = MobilityAssessmentResult(
            definition: definition,
            input: input,
            orderIndex: orderIndex,
            createdAt: now,
            updatedAt: now
        )
        if let trials = input.trials, let sample = MobilityAssessmentSample.create(from: trials, createdAt: now) {
            sample.result = result
            result.sample = sample
            context.insert(sample)
        }
        result.session = session
        session.results.append(result)
        session.skippedDefinitionKeys.removeAll { $0 == definition.catalogueKey }
        session.updatedAt = now
        context.insert(result)
        try save(context)
        return result
    }

    static func advance(
        _ session: MobilityAssessmentSession,
        now: Date = .now,
        using context: ModelContext
    ) throws {
        try requireActive(session)
        session.currentDefinitionIndex = min(
            session.currentDefinitionIndex + 1,
            session.selectedDefinitionKeys.count
        )
        session.updatedAt = now
        try save(context)
    }

    static func skipCurrent(
        _ session: MobilityAssessmentSession,
        now: Date = .now,
        using context: ModelContext
    ) throws {
        try requireActive(session)
        guard session.selectedDefinitionKeys.indices.contains(session.currentDefinitionIndex) else {
            throw MobilityAssessmentDomainError.definitionNotCurrent
        }
        let key = session.selectedDefinitionKeys[session.currentDefinitionIndex]
        let hasSavedResult = session.results.contains {
            $0.definitionCatalogueKeySnapshot == key
        }
        if !hasSavedResult && !session.skippedDefinitionKeys.contains(key) {
            session.skippedDefinitionKeys.append(key)
        }
        session.currentDefinitionIndex += 1
        session.updatedAt = now
        try save(context)
    }

    static func complete(
        _ session: MobilityAssessmentSession,
        completedAt: Date = .now,
        using context: ModelContext
    ) throws {
        try requireActive(session)
        session.status = .completed
        session.currentDefinitionIndex = session.selectedDefinitionKeys.count
        session.completedAt = completedAt
        session.updatedAt = completedAt
        try save(context)
    }

    static func stop(
        _ session: MobilityAssessmentSession,
        stoppedAt: Date = .now,
        using context: ModelContext
    ) throws {
        try requireActive(session)
        session.status = .stopped
        session.completedAt = stoppedAt
        session.updatedAt = stoppedAt
        try save(context)
    }

    static func discard(
        _ session: MobilityAssessmentSession,
        using context: ModelContext
    ) throws {
        context.delete(session)
        try save(context)
    }

    private static func requireActive(_ session: MobilityAssessmentSession) throws {
        guard session.status == .active else {
            throw MobilityAssessmentDomainError.sessionNotActive
        }
    }

    private static func save(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw MobilityAssessmentDomainError.persistenceFailed
        }
    }
}

struct MobilityAssessmentComparison: Equatable, Sendable {
    let comparability: MobilityAssessmentComparability
    let currentResultID: UUID
    let previousResultID: UUID?
    let numericDelta: Double?
    let differingConditions: [MobilityAssessmentConditionDifference]
}

@MainActor
enum MobilityAssessmentComparisonService {
    static func compare(
        current: MobilityAssessmentResult,
        previous: MobilityAssessmentResult
    ) -> MobilityAssessmentComparison {
        let differences = conditionDifferences(current: current, previous: previous)
        guard differences.isEmpty else {
            return MobilityAssessmentComparison(
                comparability: .notDirect,
                currentResultID: current.id,
                previousResultID: previous.id,
                numericDelta: nil,
                differingConditions: differences
            )
        }
        let delta: Double?
        if let currentValue = current.numericValue, let previousValue = previous.numericValue {
            delta = currentValue - previousValue
        } else {
            delta = nil
        }
        return MobilityAssessmentComparison(
            comparability: .direct,
            currentResultID: current.id,
            previousResultID: previous.id,
            numericDelta: delta,
            differingConditions: []
        )
    }

    static func latestComparison(
        for current: MobilityAssessmentResult,
        among history: [MobilityAssessmentResult]
    ) -> MobilityAssessmentComparison {
        let earlier = history
            .filter { $0.id != current.id && $0.createdAt < current.createdAt }
            .sorted { $0.createdAt > $1.createdAt }

        if let comparable = earlier.first(where: {
            conditionDifferences(current: current, previous: $0).isEmpty
        }) {
            return compare(current: current, previous: comparable)
        }

        guard let latest = earlier.first else {
            return MobilityAssessmentComparison(
                comparability: .notDirect,
                currentResultID: current.id,
                previousResultID: nil,
                numericDelta: nil,
                differingConditions: []
            )
        }
        return compare(current: current, previous: latest)
    }

    static func conditionDifferences(
        current: MobilityAssessmentResult,
        previous: MobilityAssessmentResult
    ) -> [MobilityAssessmentConditionDifference] {
        var differences = [MobilityAssessmentConditionDifference]()
        if current.definitionCatalogueKeySnapshot != previous.definitionCatalogueKeySnapshot {
            differences.append(.definition)
        }
        if current.sideRaw != previous.sideRaw { differences.append(.side) }
        if current.setupKey != previous.setupKey { differences.append(.setup) }
        if current.methodRaw != previous.methodRaw { differences.append(.method) }
        if current.unitRaw != previous.unitRaw { differences.append(.unit) }
        if current.isActiveRange != previous.isActiveRange { differences.append(.activePassive) }
        if current.isWarm != previous.isWarm { differences.append(.warmCold) }
        return differences
    }
}

struct MobilityAssessmentDefinitionProjection: Equatable, Sendable, Identifiable {
    let id: UUID
    let catalogueKey: String
    let name: String
    let nameLocalizationKey: String
    let instructionsLocalizationKey: String
    let setupInstructionsLocalizationKey: String
    let measurementDescriptionLocalizationKey: String
    let measurementLimitationsLocalizationKey: String
    let zone: MobilityAssessmentZone
    let preferredMode: MobilityMeasurementMode
    let manualMode: MobilityMeasurementMode
    let unit: MobilityMeasurementUnit
    let supportedSides: [MobilityAssessmentSide]
    let setupKeys: [String]
    let defaultSetupKey: String
    let defaultIsActiveRange: Bool
    let sortOrder: Int

    init(_ definition: MobilityAssessmentDefinition) {
        id = definition.id
        catalogueKey = definition.catalogueKey
        name = definition.name
        nameLocalizationKey = definition.nameLocalizationKey
        instructionsLocalizationKey = definition.instructionsLocalizationKey
        setupInstructionsLocalizationKey = definition.setupInstructionsLocalizationKey
        measurementDescriptionLocalizationKey = definition.measurementDescriptionLocalizationKey
        measurementLimitationsLocalizationKey = definition.measurementLimitationsLocalizationKey
        zone = definition.zone
        preferredMode = definition.preferredMode
        manualMode = definition.manualMode
        unit = definition.unit
        supportedSides = definition.supportedSides
        setupKeys = definition.setupKeys
        defaultSetupKey = definition.defaultSetupKey
        defaultIsActiveRange = definition.defaultIsActiveRange
        sortOrder = definition.sortOrder
    }
}

struct MobilityAssessmentResultProjection: Equatable, Sendable, Identifiable {
    let id: UUID
    let definitionCatalogueKey: String
    let definitionNameSnapshot: String
    let definitionVersionSnapshot: Int
    let numericValue: Double?
    let criteria: MobilityAssessmentCriteriaObservation?
    let side: MobilityAssessmentSide
    let isWarm: Bool
    let setupKey: String
    let method: MobilityMeasurementMode
    let unit: MobilityMeasurementUnit
    let isActiveRange: Bool
    let day: LocalDay
    let source: MobilityMeasurementSource
    let confidence: MobilityMeasurementConfidence
    let createdAt: Date

    init(_ result: MobilityAssessmentResult) {
        id = result.id
        definitionCatalogueKey = result.definitionCatalogueKeySnapshot
        definitionNameSnapshot = result.definitionNameSnapshot
        definitionVersionSnapshot = result.definitionVersionSnapshot
        numericValue = result.numericValue
        criteria = result.criteria
        side = result.side
        isWarm = result.isWarm
        setupKey = result.setupKey
        method = result.method
        unit = result.unit
        isActiveRange = result.isActiveRange
        day = result.day
        source = result.source
        confidence = result.confidence
        createdAt = result.createdAt
    }
}

struct MobilityAssessmentSessionProjection: Equatable, Sendable, Identifiable {
    let id: UUID
    let status: MobilityAssessmentSessionStatus
    let day: LocalDay
    let selectedDefinitionKeys: [String]
    let skippedDefinitionKeys: [String]
    let currentDefinitionIndex: Int
    let results: [MobilityAssessmentResultProjection]
    let startedAt: Date
    let completedAt: Date?
}

@MainActor
enum MobilityAssessmentHistoryQuery {
    static func sessions(using context: ModelContext) throws -> [MobilityAssessmentSessionProjection] {
        try context.fetch(FetchDescriptor<MobilityAssessmentSession>())
            .sorted { $0.startedAt > $1.startedAt }
            .map {
                MobilityAssessmentSessionProjection(
                    id: $0.id,
                    status: $0.status,
                    day: $0.day,
                    selectedDefinitionKeys: $0.selectedDefinitionKeys,
                    skippedDefinitionKeys: $0.skippedDefinitionKeys,
                    currentDefinitionIndex: $0.currentDefinitionIndex,
                    results: $0.orderedResults.map(MobilityAssessmentResultProjection.init),
                    startedAt: $0.startedAt,
                    completedAt: $0.completedAt
                )
            }
    }

    static func results(
        definitionCatalogueKey: String,
        side: MobilityAssessmentSide? = nil,
        using context: ModelContext
    ) throws -> [MobilityAssessmentResult] {
        try context.fetch(FetchDescriptor<MobilityAssessmentResult>())
            .filter { result in
                result.definitionCatalogueKeySnapshot == definitionCatalogueKey
                    && (side.map { requestedSide in requestedSide == result.side } ?? true)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
