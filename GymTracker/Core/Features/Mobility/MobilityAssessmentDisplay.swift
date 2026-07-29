import SwiftUI

/// User-facing vocabulary for the mobility-assessment domain.
///
/// `MobilityAssessmentTypes` is deliberately raw persistence vocabulary, and the
/// backend services are UI-neutral. This file is the only place that turns
/// either into display copy, so the observational language stays in one place.
///
/// Two rules govern every string here:
///
/// 1. An assessment reports **what was observed under stated conditions**. It
///    never grades, scores, or diagnoses, so words like *normal*, *poor*,
///    *limited*, *restricted*, *imbalance*, or *risk* never appear.
/// 2. The raw value outranks any interpretation, visually and in reading order.
enum MobilityAssessmentCopy {

    // MARK: - Seeded catalogue copy

    /// Seeded definitions and stored results carry localization *keys* rather
    /// than translated text, so a later catalogue revision never rewrites a
    /// snapshot that has already been recorded. A key with no translation falls
    /// back to authored text instead of surfacing the raw key.
    static func resolve(_ key: String, fallback: String = "") -> String {
        guard key.isEmpty == false else { return fallback }
        let resolved = String(localized: String.LocalizationValue(key))
        return resolved == key ? fallback : resolved
    }

    static func name(for definition: MobilityAssessmentDefinition) -> String {
        resolve(definition.nameLocalizationKey, fallback: definition.name)
    }

    static func instructions(for definition: MobilityAssessmentDefinition) -> String {
        resolve(definition.instructionsLocalizationKey)
    }

    static func setupInstructions(for definition: MobilityAssessmentDefinition) -> String {
        resolve(definition.setupInstructionsLocalizationKey)
    }

    static func measurementDescription(for definition: MobilityAssessmentDefinition) -> String {
        resolve(definition.measurementDescriptionLocalizationKey)
    }

    static func measurementLimitations(for definition: MobilityAssessmentDefinition) -> String {
        resolve(definition.measurementLimitationsLocalizationKey)
    }

    /// Setup keys are authored identifiers. A missing translation degrades to a
    /// readable form of the key rather than to nothing, because the setup is a
    /// recorded condition and hiding it would make a retest unverifiable.
    static func setupName(_ setupKey: String) -> String {
        resolve(
            "mobility.assessment.setup.\(setupKey)",
            fallback: humanized(setupKey)
        )
    }

    private static func humanized(_ key: String) -> String {
        let spaced = key.replacingOccurrences(of: "-", with: " ")
        guard let first = spaced.first else { return spaced }
        return String(first).uppercased() + spaced.dropFirst()
    }

    // MARK: - Conditions

    /// The conditions line is what makes a retest meaningful, so it is rendered
    /// as one plain sentence of recorded facts in a stable order.
    static func conditionsSummary(
        setupKey: String,
        isActiveRange: Bool,
        isWarm: Bool
    ) -> String {
        String(
            localized: "mobility.assessment.conditions.summary",
            defaultValue: "\(setupName(setupKey)) · \(rangeTypeName(isActiveRange: isActiveRange)) · \(warmStateName(isWarm: isWarm))"
        )
    }

    /// How the observation came to exist, kept beside every value. Confidence is
    /// whatever was frozen onto the result at capture; it is never recomputed
    /// from a rule that has changed since.
    static func provenanceSummary(
        source: MobilityMeasurementSource,
        confidence: MobilityMeasurementConfidence
    ) -> String {
        String(
            localized: "mobility.assessment.provenance.summary",
            defaultValue: "\(source.displayName) · \(confidence.displayName)"
        )
    }

    static func rangeTypeName(isActiveRange: Bool) -> String {
        isActiveRange
            ? String(localized: "mobility.assessment.range.active", defaultValue: "Active range")
            : String(localized: "mobility.assessment.range.passive", defaultValue: "Passive range")
    }

    static func warmStateName(isWarm: Bool) -> String {
        isWarm
            ? String(localized: "mobility.assessment.warmth.warm", defaultValue: "After training")
            : String(localized: "mobility.assessment.warmth.cold", defaultValue: "Before training")
    }
}

// MARK: - Enum display vocabulary

extension MobilityAssessmentZone {
    var displayName: String {
        switch self {
        case .shoulders: String(localized: "Shoulders")
        case .overhead: String(localized: "Overhead")
        case .thorax: String(localized: "Thorax")
        case .hips: String(localized: "Hips")
        case .posteriorChain: String(localized: "Posterior chain")
        case .ankles: String(localized: "Ankles")
        }
    }

    /// Fixed presentation order. It matches the seeded catalogue's grouping and
    /// carries no ranking — a zone's position is not a judgement about it.
    static var displayOrder: [MobilityAssessmentZone] {
        [.shoulders, .overhead, .thorax, .hips, .posteriorChain, .ankles]
    }
}

extension MobilityAssessmentSide {
    var displayName: String {
        switch self {
        case .left: String(localized: "Left")
        case .right: String(localized: "Right")
        case .combined: String(localized: "Both sides")
        }
    }
}

extension MobilityAssessmentCriteriaObservation {
    /// Observations, not a pass/fail grade: the copy states what was seen and
    /// stops there.
    var displayName: String {
        switch self {
        case .allCriteriaObserved: String(localized: "All criteria observed")
        case .someCriteriaObserved: String(localized: "Some criteria observed")
        case .criteriaNotObserved: String(localized: "Criteria not observed")
        }
    }
}

extension MobilityMeasurementMode {
    var displayName: String {
        switch self {
        case .manualAngle: String(localized: "Angle entered by hand")
        case .manualLinear: String(localized: "Distance entered by hand")
        case .manualCriteria: String(localized: "Criteria observed by hand")
        case .inclinometer: String(localized: "Device inclinometer")
        case .axialRotation: String(localized: "Device axial rotation")
        case .twoSegmentAngle: String(localized: "Two-segment device angle")
        case .dynamicRange: String(localized: "Device range sweep")
        case .cameraPose: String(localized: "Camera pose")
        }
    }
}

extension MobilityMeasurementSource {
    /// A hand-entered value says so. Labelling it "measured" would overstate
    /// what the record actually contains.
    var displayName: String {
        switch self {
        case .manual: String(localized: "Entered by hand")
        case .deviceMotion: String(localized: "Measured with device motion")
        case .imported: String(localized: "Imported")
        }
    }
}

extension MobilityMeasurementConfidence {
    var displayName: String {
        switch self {
        case .high: String(localized: "High confidence")
        case .moderate: String(localized: "Moderate confidence")
        case .low: String(localized: "Low confidence")
        case .unknown: String(localized: "Confidence not stated")
        }
    }
}

extension MobilityAssessmentConditionDifference {
    var displayName: String {
        switch self {
        case .definition: String(localized: "Assessment")
        case .side: String(localized: "Side")
        case .setup: String(localized: "Setup")
        case .method: String(localized: "Method")
        case .unit: String(localized: "Unit")
        case .activePassive: String(localized: "Active or passive range")
        case .warmCold: String(localized: "Before or after training")
        }
    }
}

// MARK: - Errors

/// The domain errors carry developer-facing English. A user needs the problem
/// *and* the next step, in their language, so the UI maps them rather than
/// surfacing `errorDescription` directly.
enum MobilityAssessmentErrorCopy {

    static func message(for error: Error) -> String {
        switch error {
        case let domainError as MobilityAssessmentDomainError:
            return message(for: domainError)
        case let validationError as MobilityAssessmentValidationError:
            return message(for: validationError)
        default:
            return generic
        }
    }

    static func message(for error: MobilityAssessmentDomainError) -> String {
        switch error {
        case .noDefinitionsSelected:
            String(localized: "Choose at least one assessment to record.")
        case .activeSessionAlreadyExists:
            String(localized: "An assessment is already in progress. Continue that one before starting another.")
        case .sessionNotActive:
            String(localized: "This assessment has already been finished. Your saved observations are unchanged.")
        case .definitionNotSelected, .definitionNotCurrent:
            String(localized: "That assessment is not part of this session. Go back a step and try again.")
        case .resultDayMismatch:
            String(localized: "This observation belongs to a different day than the assessment. Start a new assessment for today.")
        case .duplicateDefinition, .archivedDefinition, .invalidDefinition:
            String(localized: "One of the chosen assessments is unavailable. Change your selection and try again.")
        case .resultValidation(let validationError):
            message(for: validationError)
        case .persistenceFailed:
            String(localized: "The observation could not be saved. Your entry is still here — try again.")
        }
    }

    static func message(for error: MobilityAssessmentValidationError) -> String {
        switch error {
        case .missingNumericValue:
            String(localized: "Enter a value for at least one side before saving.")
        case .nonFiniteValue:
            String(localized: "Enter a number for this observation.")
        case .missingCriteriaObservation:
            String(localized: "Choose what you observed before saving.")
        case .unexpectedNumericValue, .unexpectedCriteriaObservation, .incompatibleUnit:
            String(localized: "This assessment records a different kind of value. Reopen it and try again.")
        case .unsupportedSide:
            String(localized: "This assessment does not record that side.")
        case .unsupportedSetup:
            String(localized: "Choose one of the setups this assessment supports.")
        case .unsupportedMethod, .manualSourceRequiresManualMethod, .unsupportedCameraPose:
            String(localized: "This version records observations you enter yourself.")
        case .manualConfidenceTooHigh:
            String(localized: "An observation entered by hand is recorded with moderate confidence.")
        case .invalidDefinition:
            String(localized: "This assessment is unavailable. Change your selection and try again.")
        }
    }

    static var generic: String {
        String(localized: "Something went wrong. Your entry is still here — try again.")
    }
}

// MARK: - Values

/// Formats a recorded observation. The unit is always attached: a bare number
/// invites being read as a grade, and the typed unit is the whole point of the
/// stored `unitRaw`.
enum MobilityAssessmentValueFormatter {

    static func text(
        numericValue: Double?,
        criteria: MobilityAssessmentCriteriaObservation?,
        unit: MobilityMeasurementUnit
    ) -> String {
        switch unit {
        case .criteria:
            return criteria?.displayName ?? placeholder
        case .degrees:
            guard let numericValue else { return placeholder }
            return degreesText(numericValue)
        case .centimetres:
            guard let numericValue else { return placeholder }
            return String(
                localized: "mobility.assessment.value.centimetres",
                defaultValue: "\(number(numericValue)) cm"
            )
        }
    }

    /// Spoken form. "67°" reads as "sixty-seven" without the unit in several
    /// VoiceOver voices, and the unit is exactly what makes the value checkable.
    static func accessibilityText(
        numericValue: Double?,
        criteria: MobilityAssessmentCriteriaObservation?,
        unit: MobilityMeasurementUnit
    ) -> String {
        switch unit {
        case .criteria:
            return criteria?.displayName ?? placeholder
        case .degrees:
            guard let numericValue else { return placeholder }
            return String(
                localized: "mobility.assessment.value.degrees.spoken",
                defaultValue: "\(number(numericValue)) degrees"
            )
        case .centimetres:
            guard let numericValue else { return placeholder }
            return String(
                localized: "mobility.assessment.value.centimetres.spoken",
                defaultValue: "\(number(numericValue)) centimetres"
            )
        }
    }

    /// A signed difference between two directly comparable observations. It is
    /// a difference, never an improvement or a regression.
    static func differenceText(_ delta: Double, unit: MobilityMeasurementUnit) -> String? {
        guard delta.isFinite else { return nil }
        switch unit {
        case .criteria:
            return nil
        case .degrees:
            return String(
                localized: "mobility.assessment.difference.degrees",
                defaultValue: "\(signedNumber(delta))°"
            )
        case .centimetres:
            return String(
                localized: "mobility.assessment.difference.centimetres",
                defaultValue: "\(signedNumber(delta)) cm"
            )
        }
    }

    /// Unsigned gap between the left and right observation of one assessment.
    static func gapText(_ gap: Double, unit: MobilityMeasurementUnit) -> String? {
        guard gap.isFinite else { return nil }
        switch unit {
        case .criteria:
            return nil
        case .degrees:
            return String(
                localized: "mobility.assessment.gap.degrees",
                defaultValue: "\(number(abs(gap)))° difference"
            )
        case .centimetres:
            return String(
                localized: "mobility.assessment.gap.centimetres",
                defaultValue: "\(number(abs(gap))) cm difference"
            )
        }
    }

    static func unitSuffix(_ unit: MobilityMeasurementUnit) -> String {
        switch unit {
        case .degrees: "°"
        case .centimetres: String(localized: "cm")
        case .criteria: ""
        }
    }

    static var placeholder: String {
        String(localized: "Not entered")
    }

    private static func degreesText(_ value: Double) -> String {
        String(
            localized: "mobility.assessment.value.degrees",
            defaultValue: "\(number(value))°"
        )
    }

    /// Entered precision is preserved up to one decimal; a hand-entered angle
    /// carries no more resolution than that.
    private static func number(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...1)))
    }

    private static func signedNumber(_ value: Double) -> String {
        value.formatted(
            .number
                .grouping(.never)
                .precision(.fractionLength(0...1))
                .sign(strategy: .always(includingZero: false))
        )
    }
}
