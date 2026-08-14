import Foundation

/// What the lifter said about mobility, reduced to the facts ranking uses.
/// Mirrors `ProgramMatchCriteria`'s role on the workout side.
nonisolated struct MobilityMatchCriteria: Equatable, Sendable {
    var goal: MobilityGoalPreference?
    var experience: MobilityExperiencePreference?
    var frequency: MobilityFrequencyPreference?

    init(
        goal: MobilityGoalPreference? = nil,
        experience: MobilityExperiencePreference? = nil,
        frequency: MobilityFrequencyPreference? = nil
    ) {
        self.goal = goal
        self.experience = experience
        self.frequency = frequency
    }

    @MainActor
    init(draft: OnboardingDraft) {
        self.init(
            goal: draft.mobilityGoal,
            experience: draft.mobilityExperience,
            frequency: draft.mobilityFrequency
        )
    }

    /// No mobility goal means the lifter never expressed interest in a
    /// mobility plan — matching degrades to nothing, exactly like an empty
    /// `ProgramMatchCriteria`, rather than showing a ranked mobility section
    /// nobody asked for.
    var isEmpty: Bool { goal == nil }
}

struct MobilityMatchReason: Identifiable, Equatable, Sendable {
    var id: String { text }
    let text: String
}

struct MobilityMatchWarning: Identifiable, Equatable, Sendable {
    var id: String { text }
    let text: String
}

/// A free-text, author-written condition the intake cannot verify — mirrors
/// `ProgramMatchPrerequisite`'s role on the workout side. Disclosed
/// unconditionally (see the comment at the evaluation call site) but never a
/// `MobilityMatchWarning`: nothing here compares what the lifter said against
/// what the plan declared, so a prerequisite must never downgrade
/// `compatibilityTitle` or count against a plan in the warnings-count
/// tie-break.
struct MobilityMatchPrerequisite: Identifiable, Equatable, Sendable {
    var id: String { text }
    let text: String
}

struct MobilityMatchResult: Identifiable, Equatable, Sendable {
    var id: UUID { programID }
    let programID: UUID
    let name: String
    let summary: String?
    let experienceLevel: MobilityMatchExperienceLevel
    let supportedDaysPerWeek: [Int]
    let durationWeeks: Int
    let isRunnable: Bool
    let score: Double
    let reasons: [MobilityMatchReason]
    let warnings: [MobilityMatchWarning]
    let prerequisites: [MobilityMatchPrerequisite]

    var compatibilityTitle: String? {
        guard isRunnable else { return String(localized: "Not supported") }
        return warnings.isEmpty ? nil : String(localized: "Needs changes")
    }
}

/// Ranks the seven bundled mobility plans against what the lifter said.
/// Mirrors `ProgramMatchService`'s structure and honesty rules exactly —
/// matching only ever suggests, and a factor the plan never declared is never
/// scored as a mismatch.
enum MobilityMatchService {
    private enum Weight {
        static let goal = 30.0
        static let experience = 15.0
        static let frequency = 15.0
    }

    static func rank(
        programs: [MobilityMatchCandidate],
        criteria: MobilityMatchCriteria
    ) -> [MobilityMatchResult] {
        programs
            .map { evaluate($0, criteria: criteria) }
            .sorted { lhs, rhs in
                if lhs.isRunnable != rhs.isRunnable { return lhs.isRunnable }
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                if lhs.warnings.count != rhs.warnings.count {
                    return lhs.warnings.count < rhs.warnings.count
                }
                return lhs.name < rhs.name
            }
    }

    static func evaluate(
        _ candidate: MobilityMatchCandidate,
        criteria: MobilityMatchCriteria
    ) -> MobilityMatchResult {
        var score = 0.0
        var reasons: [MobilityMatchReason] = []
        var warnings: [MobilityMatchWarning] = []

        let missingCapabilities = EngineCapabilities.missing(from: candidate.requiredCapabilities)
        let isUnsupported = !missingCapabilities.isEmpty

        if let goal = criteria.goal {
            if candidate.goalIDs.contains(goal.rawValue) {
                score += Weight.goal
                reasons.append(.init(text: String(localized: "Matches your mobility goal")))
            }
        }

        // Experience mismatch is a warning, never a filter — the same rule
        // `ProgramMatchService` applies to `PlanExperienceLevel`. An advanced
        // plan stays visible to a mobility beginner with its demands stated.
        if let experience = criteria.experience, let level = experience.mobilityMatchLevel {
            if level == candidate.experienceLevel {
                score += Weight.experience
                reasons.append(.init(text: String(localized: "Written for your mobility experience")))
            } else if candidate.experienceLevel > level {
                warnings.append(.init(
                    text: String(localized: "Assumes \(candidate.experienceLevel.title.lowercased()) mobility experience")
                ))
            }
        }

        if let desired = criteria.frequency?.impliedDaysPerWeek {
            if candidate.supportedDaysPerWeek.contains(where: desired.contains) {
                score += Weight.frequency
                reasons.append(.init(text: String(localized: "Fits how often you want to do mobility work")))
            } else if let nearest = candidate.supportedDaysPerWeek.min(by: {
                abs($0 - desired.lowerBound) < abs($1 - desired.lowerBound)
            }) {
                warnings.append(.init(
                    text: String(localized: "Written for \(CountPhrase.days(nearest)) a week")
                ))
            }
        }

        // Prerequisites are free text and cannot be verified from the
        // intake, so they are always disclosed rather than assumed met — a
        // plan that lists one never earns a clean, caveat-free result. Kept
        // out of `warnings` for the same reason `ProgramMatchService` keeps
        // them out on the workout side: a prerequisite is the app disclosing
        // something it cannot check, not the app comparing an answer against
        // a declaration, so it must not drive `compatibilityTitle` or the
        // warnings-count tie-break.
        let prerequisites = candidate.prerequisites.map { MobilityMatchPrerequisite(text: $0) }

        if isUnsupported {
            warnings.insert(
                .init(text: String(localized: "This version of Trame can’t run this plan yet.")),
                at: 0
            )
        }

        return MobilityMatchResult(
            programID: candidate.id,
            name: candidate.name,
            summary: candidate.summary,
            experienceLevel: candidate.experienceLevel,
            supportedDaysPerWeek: candidate.supportedDaysPerWeek,
            durationWeeks: candidate.durationWeeks,
            isRunnable: !isUnsupported,
            score: score,
            reasons: reasons,
            warnings: warnings,
            prerequisites: prerequisites
        )
    }
}
