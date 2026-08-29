import SwiftUI

/// Turns an evaluation snapshot's codes into localized, deterministic display
/// strings.
///
/// Every string here is assembled from `String(localized:defaultValue:)` at
/// render time. Nothing is generated, nothing is persisted as a sentence, and
/// there is no single equivalence percentage anywhere — suitability and
/// comparability are always presented as two separate statements, because a
/// merged score would imply a precision the app does not have.
enum SubstitutionPresentation {

    // MARK: - Reason

    static func reasonTitle(_ reason: SubstitutionReason) -> String {
        switch reason {
        case .equipmentUnavailable:
            return String(localized: "substitution.reason.equipmentUnavailable",
                          defaultValue: "Equipment is busy or unavailable")
        case .discomfort:
            return String(localized: "substitution.reason.discomfort",
                          defaultValue: "Something feels uncomfortable today")
        case .fatigue:
            return String(localized: "substitution.reason.fatigue",
                          defaultValue: "I'm too fatigued for this one")
        case .skillOrConfidence:
            return String(localized: "substitution.reason.skillOrConfidence",
                          defaultValue: "I'm not confident with this movement")
        case .preference:
            return String(localized: "substitution.reason.preference",
                          defaultValue: "I'd rather do something else")
        case .timeConstraint:
            return String(localized: "substitution.reason.timeConstraint",
                          defaultValue: "I'm short on time")
        case .homeEquipment:
            return String(localized: "substitution.reason.homeEquipment",
                          defaultValue: "I'm training with home equipment")
        case .permanentPlanChange:
            return String(localized: "substitution.reason.permanentPlanChange",
                          defaultValue: "I want to change this in my plan")
        case .notSure:
            return String(localized: "substitution.reason.notSure",
                          defaultValue: "Not sure")
        }
    }

    /// Shown only for `notSure`, so choosing it never feels like a failure.
    static var notSureFootnote: String {
        String(localized: "substitution.reason.notSure.footnote",
               defaultValue: "That's fine. Options will be ranked on what your plan already asks for.")
    }

    // MARK: - Suitability

    static func suitabilityTitle(_ value: SubstitutionSuitability) -> String {
        switch value {
        case .excellent:
            return String(localized: "substitution.suitability.excellent", defaultValue: "Excellent fit")
        case .good:
            return String(localized: "substitution.suitability.good", defaultValue: "Good fit")
        case .acceptable:
            return String(localized: "substitution.suitability.acceptable", defaultValue: "Acceptable fit")
        case .poor:
            return String(localized: "substitution.suitability.poor", defaultValue: "Poor fit")
        case .notRecommended:
            return String(localized: "substitution.suitability.notRecommended", defaultValue: "Not recommended")
        case .insufficientInformation:
            return String(localized: "substitution.suitability.insufficient", defaultValue: "Not enough information")
        }
    }

    /// Shape and glyph carry the meaning alongside color, so the two
    /// indicators stay distinguishable without color vision.
    static func suitabilityIcon(_ value: SubstitutionSuitability) -> String {
        switch value {
        case .excellent: return AppIcon.checkmarkCircle
        case .good: return "checkmark.circle"
        case .acceptable: return AppIcon.circle
        case .poor: return AppIcon.warningCircle
        case .notRecommended: return AppIcon.failureCircle
        case .insufficientInformation: return AppIcon.circleDashed
        }
    }

    /// Four values, and only one of them earns a hue: a blocked option is a
    /// safety statement. "Acceptable" and "Poor" are separated by their glyph
    /// and their title, which is what lets amber stay reserved for rest instead
    /// of becoming a fourth verdict colour on a list of verdicts.
    static func suitabilityColor(_ value: SubstitutionSuitability) -> Color {
        switch value {
        case .excellent, .good: return .trameCompleted
        case .acceptable, .poor: return .trameText
        case .notRecommended: return .trameDestructiveText
        case .insufficientInformation: return .trameSubdued
        }
    }

    // MARK: - Comparability

    static func comparabilityTitle(_ value: SubstitutionComparability) -> String {
        switch value {
        case .direct:
            return String(localized: "substitution.comparability.direct", defaultValue: "History carries over")
        case .limited:
            return String(localized: "substitution.comparability.limited", defaultValue: "History compares loosely")
        case .notDirect:
            return String(localized: "substitution.comparability.notDirect", defaultValue: "Separate history")
        case .unknown:
            return String(localized: "substitution.comparability.unknown", defaultValue: "History effect unknown")
        }
    }

    static func comparabilityDetail(_ value: SubstitutionComparability) -> String {
        switch value {
        case .direct:
            return String(
                localized: "substitution.comparability.direct.detail",
                defaultValue: "Same setup, loading, and logging, so your previous loads mean the same thing."
            )
        case .limited:
            return String(
                localized: "substitution.comparability.limited.detail",
                defaultValue: "Related movement, but the loads aren't directly equivalent. Trends compare; numbers don't."
            )
        case .notDirect:
            return String(
                localized: "substitution.comparability.notDirect.detail",
                defaultValue: "The same number means a different amount of work here, so this keeps its own history."
            )
        case .unknown:
            return String(
                localized: "substitution.comparability.unknown.detail",
                defaultValue: "Not enough is recorded about these two exercises to compare their loads. This keeps its own history."
            )
        }
    }

    /// Deliberately distinct glyph family from suitability so the two
    /// indicators never read as one combined rating.
    static func comparabilityIcon(_ value: SubstitutionComparability) -> String {
        switch value {
        case .direct: return "arrow.left.arrow.right.circle.fill"
        case .limited: return "arrow.left.arrow.right.circle"
        case .notDirect: return "arrow.triangle.branch"
        case .unknown: return "questionmark.circle"
        }
    }

    static func comparabilityColor(_ value: SubstitutionComparability) -> Color {
        switch value {
        case .direct: return .trameCompleted
        case .limited: return .trameText
        case .notDirect: return .trameSubdued
        case .unknown: return .trameSubdued
        }
    }

    // MARK: - Scope

    /// Short label for a scope value. Reuses the exact keys
    /// `SubstitutionConfirmationView` already defines inline for its scope
    /// picker rows, so a scope reads identically wherever it appears rather
    /// than duplicating the same two strings under a second key.
    static func scopeTitle(_ scope: SubstitutionScope) -> String {
        switch scope {
        case .todayOnly:
            return String(localized: "substitution.scope.todayOnly", defaultValue: "Just today")
        case .futurePlan:
            return String(localized: "substitution.scope.futurePlan", defaultValue: "Replace in my plan")
        }
    }

    // MARK: - Confidence

    static func confidenceTitle(_ value: SubstitutionEvidenceConfidence) -> String {
        switch value {
        case .high:
            return String(localized: "substitution.confidence.high", defaultValue: "Based on complete information")
        case .moderate:
            return String(localized: "substitution.confidence.moderate", defaultValue: "Based on most of the details")
        case .low:
            return String(localized: "substitution.confidence.low", defaultValue: "Based on limited information")
        case .insufficient:
            return String(localized: "substitution.confidence.insufficient", defaultValue: "Too little information to judge")
        }
    }

    // MARK: - Factor codes

    /// Persisted codes resolved to localized names at render time. An
    /// unrecognized code (written by a newer build) returns `nil` and is simply
    /// not shown, rather than leaking a raw key into the interface.
    static func factorTitle(_ code: String) -> String? {
        switch code {
        case SubstitutionFactorCode.movementPattern:
            return String(localized: "substitution.factor.movementPattern", defaultValue: "Movement pattern")
        case SubstitutionFactorCode.primaryMuscles:
            return String(localized: "substitution.factor.primaryMuscles", defaultValue: "Primary muscles")
        case SubstitutionFactorCode.secondaryMuscles:
            return String(localized: "substitution.factor.secondaryMuscles", defaultValue: "Secondary muscles")
        case SubstitutionFactorCode.variationFamily:
            return String(localized: "substitution.factor.variationFamily", defaultValue: "Movement family")
        case SubstitutionFactorCode.equipment:
            return String(localized: "substitution.factor.equipment", defaultValue: "Equipment")
        case SubstitutionFactorCode.resistance:
            return String(localized: "substitution.factor.resistance", defaultValue: "Type of resistance")
        case SubstitutionFactorCode.mechanics:
            return String(localized: "substitution.factor.mechanics", defaultValue: "Compound or isolation")
        case SubstitutionFactorCode.rangeOfMotion:
            return String(localized: "substitution.factor.rangeOfMotion", defaultValue: "Range of motion")
        case SubstitutionFactorCode.grip:
            return String(localized: "substitution.factor.grip", defaultValue: "Grip")
        case SubstitutionFactorCode.stance:
            return String(localized: "substitution.factor.stance", defaultValue: "Stance")
        case SubstitutionFactorCode.laterality:
            return String(localized: "substitution.factor.laterality", defaultValue: "One side or both")
        case SubstitutionFactorCode.tracking:
            return String(localized: "substitution.factor.tracking", defaultValue: "How sets are logged")
        case SubstitutionFactorCode.loadInterpretation:
            return String(localized: "substitution.factor.loadInterpretation", defaultValue: "How load is counted")
        case SubstitutionFactorCode.difficulty:
            return String(localized: "substitution.factor.difficulty", defaultValue: "Difficulty")
        case SubstitutionFactorCode.stimulus:
            return String(localized: "substitution.factor.stimulus", defaultValue: "Training stimulus")
        case SubstitutionFactorCode.goal:
            return String(localized: "substitution.factor.goal", defaultValue: "What this exercise is for today")
        case SubstitutionFactorCode.curatedRationale:
            return String(localized: "substitution.factor.curatedRationale", defaultValue: "Reviewed substitution")
        case SubstitutionFactorCode.unreviewedLink:
            return String(localized: "substitution.factor.unreviewedLink", defaultValue: "Substitution not yet reviewed")
        default:
            return nil
        }
    }

    static func hardFilterTitle(_ code: String) -> String? {
        switch code {
        case SubstitutionFactorCode.equipmentUnavailable:
            return String(localized: "substitution.filter.equipmentUnavailable",
                          defaultValue: "Needs equipment you marked unavailable")
        case SubstitutionFactorCode.incompatibleTracking:
            return String(localized: "substitution.filter.incompatibleTracking",
                          defaultValue: "Can't be logged against today's prescription")
        case SubstitutionFactorCode.uncomfortablePosition:
            return String(localized: "substitution.filter.uncomfortablePosition",
                          defaultValue: "Uses a position you said is uncomfortable")
        case SubstitutionFactorCode.skillInappropriate:
            return String(localized: "substitution.filter.skillInappropriate",
                          defaultValue: "Harder than the exercise you're replacing")
        default:
            return nil
        }
    }

    static func factorTitles(_ codes: [String]) -> [String] {
        codes.compactMap { factorTitle($0) }
    }

    // MARK: - Progression effect

    static func progressionEffect(_ policy: ProgressionTransferPolicy) -> String {
        switch policy {
        case .separate:
            return String(
                localized: "substitution.progression.separate",
                defaultValue: "This exercise keeps its own progression. Your original exercise's progression is untouched."
            )
        case .continueShared:
            return String(
                localized: "substitution.progression.shared",
                defaultValue: "Progression continues from your original exercise, because the setup and loading match exactly."
            )
        case .undetermined:
            return String(
                localized: "substitution.progression.undetermined",
                defaultValue: "There isn't enough information to link progression, so this keeps its own."
            )
        }
    }

    // MARK: - Why? model

    /// Assembles the explanation from the snapshot's codes.
    ///
    /// Every section is derived — nothing is written at decision time and
    /// replayed. That is what lets an explanation recorded months ago still
    /// render in the reader's current language.
    ///
    /// Section headings and ordering come from `WhyExplanationSectionKind`, not
    /// from here: substitution was the first adopter of the shared surface, and
    /// keeping its own wording would have made it the exception every later
    /// surface copied.
    static func whyModel(
        for evaluation: SubstitutionEvaluation,
        replacing originalName: String,
        scope: SubstitutionScope,
        policy: ProgressionTransferPolicy
    ) -> WhyExplanationModel {
        let snapshot = evaluation.snapshot

        let subtitleFormat = String(
            localized: "substitution.why.subtitle",
            defaultValue: "Replacing %@ with %@"
        )

        var builder = WhyExplanationBuilder(
            title: String(localized: "substitution.why.title", defaultValue: "Why?"),
            subtitle: String(format: subtitleFormat, originalName, evaluation.exercise.name),
            isDecision: true
        )

        // Why it is offered — including the honest case where the only reason
        // is that someone linked the two exercises.
        let matched = factorTitles(snapshot.matchedFactorCodes)
        builder.add(
            .evidenceUsed,
            body: matched.isEmpty
                ? String(
                    localized: "substitution.why.suggested.linkOnly",
                    defaultValue: "This option is offered because it's linked as a substitute in your exercise library, not because its details match."
                )
                : nil,
            items: matched
        )

        // A hard block and an informational difference are different claims,
        // so they use different kinds rather than one relabelled section.
        if snapshot.hardFilterFailureCodes.isEmpty {
            builder.add(.whatDiffers, items: factorTitles(snapshot.differingFactorCodes))
        } else {
            builder.add(.blockers, items: snapshot.hardFilterFailureCodes.compactMap { hardFilterTitle($0) })
        }

        // Effect on history — always stated, never implied.
        builder.add(.effectOnHistory, body: comparabilityDetail(snapshot.comparability))
        builder.add(.effectOnHistory, body: progressionEffect(policy))

        builder.add(.effectOnPlan, body: scopeEffect(scope))

        // Naming the gaps is the point: a confident-looking verdict built on
        // absent data is exactly what this surface exists to prevent. Routing
        // through `noteMissingEvidence` makes it impossible to record the gaps
        // and then render no confidence section.
        builder.noteMissingEvidence(
            qualifier: confidenceTitle(snapshot.confidence),
            missing: factorTitles(snapshot.missingEvidenceCodes),
            introduction: String(
                localized: "substitution.why.missing.intro",
                defaultValue: "Not recorded for these exercises:"
            )
        )

        builder.add(
            .override,
            body: String(
                localized: "substitution.why.override.body",
                defaultValue: "You can pick any option here regardless of this assessment. Nothing is chosen for you, and no load is converted automatically."
            )
        )

        return builder.build()
    }

    static func scopeEffect(_ scope: SubstitutionScope) -> String {
        switch scope {
        case .todayOnly:
            return String(
                localized: "substitution.scope.todayOnly.effect",
                defaultValue: "Your plan is unchanged. This applies to today's session only."
            )
        case .futurePlan:
            return String(
                localized: "substitution.scope.futurePlan.effect",
                defaultValue: "This replaces the exercise in your plan from here on. You'll see a preview before anything changes."
            )
        }
    }
}
