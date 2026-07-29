import Foundation

/// The closed vocabulary every "Why?" explanation is built from.
///
/// This enum is the whole point of Phase 2c. Before it, a surface supplied its
/// own section identifiers *and* its own headings, which meant two screens
/// explaining the same kind of thing could name it differently and order it
/// differently — the per-surface bespoke copy the shared component exists to
/// prevent. A surface now supplies **content**; the vocabulary, the wording of
/// the headings, and the order are fixed here.
///
/// Adding a case is a deliberate product decision, not a convenience for one
/// screen. If a surface feels like it needs a new section, the question to ask
/// first is whether an existing kind already means that.
enum WhyExplanationSectionKind: String, CaseIterable, Comparable, Sendable {
    /// What is being proposed, or what happened.
    case whatChanged
    /// Why an option is unavailable. Distinct from `whatDiffers`: a blocker is
    /// disqualifying, a difference is informational.
    case blockers
    /// The data the decision was actually built from.
    case evidenceUsed
    /// How this departs from the alternative it replaces.
    case whatDiffers
    /// What it does to recorded truth.
    case effectOnHistory
    /// What it does to future prescription.
    case effectOnPlan
    /// The qualifier, plus the evidence that is *missing*. Never a number.
    case confidence
    /// The consequence of accepting.
    case ifYouAccept
    /// The consequence of declining. Never framed as failure or noncompliance.
    case ifYouDecline
    /// That the choice belongs to the user.
    case override

    /// Fixed presentation order, so the same concept never appears in a
    /// different position on a different screen.
    var order: Int {
        switch self {
        case .whatChanged: return 0
        case .blockers: return 1
        case .evidenceUsed: return 2
        case .whatDiffers: return 3
        case .effectOnHistory: return 4
        case .effectOnPlan: return 5
        case .confidence: return 6
        case .ifYouAccept: return 7
        case .ifYouDecline: return 8
        case .override: return 9
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.order < rhs.order }

    /// The heading. Callers cannot override it — that is the constraint that
    /// keeps "How confident this is" from being renamed on one screen.
    var title: String {
        switch self {
        case .whatChanged:
            return String(localized: "why.section.whatChanged", defaultValue: "What changes")
        case .blockers:
            return String(localized: "why.section.blockers", defaultValue: "Why this isn't available")
        case .evidenceUsed:
            return String(localized: "why.section.evidenceUsed", defaultValue: "What this is based on")
        case .whatDiffers:
            return String(localized: "why.section.whatDiffers", defaultValue: "What's different")
        case .effectOnHistory:
            return String(localized: "why.section.effectOnHistory", defaultValue: "Effect on your history")
        case .effectOnPlan:
            return String(localized: "why.section.effectOnPlan", defaultValue: "Effect on your plan")
        case .confidence:
            return String(localized: "why.section.confidence", defaultValue: "How confident this is")
        case .ifYouAccept:
            return String(localized: "why.section.ifYouAccept", defaultValue: "If you accept")
        case .ifYouDecline:
            return String(localized: "why.section.ifYouDecline", defaultValue: "If you decline")
        case .override:
            return String(localized: "why.section.override", defaultValue: "You decide")
        }
    }

    /// Emphasis is part of the vocabulary too. A caution-coloured "What this is
    /// based on" on one screen and a neutral one on another would read as two
    /// different concepts.
    var emphasis: WhyExplanationEmphasis {
        switch self {
        case .whatChanged, .effectOnHistory, .effectOnPlan, .ifYouAccept, .ifYouDecline:
            return .neutral
        case .evidenceUsed:
            return .positive
        case .blockers, .whatDiffers:
            return .caution
        case .confidence, .override:
            return .subdued
        }
    }

    /// Sections that only make sense where something is being decided.
    ///
    /// A prescription row explains provenance; nothing is accepted or declined
    /// there. Builders for non-decision surfaces omit these rather than
    /// fabricating a consequence, because an explanation padded with hollow
    /// sections teaches users to stop reading explanations.
    var requiresDecision: Bool {
        self == .ifYouAccept || self == .ifYouDecline || self == .override
    }
}

enum WhyExplanationEmphasis: Equatable, Sendable {
    case neutral
    case positive
    case caution
    /// For limitations and overrides — reads as a bound on what the app knows,
    /// not as a fault of the thing being explained.
    case subdued
}
