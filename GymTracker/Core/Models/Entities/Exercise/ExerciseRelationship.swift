import Foundation
import SwiftData

/// A deliberate, user-maintained connection between two library exercises.
/// Variation families remain descriptive; only a substitution relationship can
/// offer a replacement while a workout is in progress.
///
/// The curation fields below carry *provenance*, not judgment: they record how
/// much a link can be trusted, so the substitution evaluator can say "this is a
/// reviewed recommendation" versus "this link ships in seed data but has not
/// been through curation review" instead of presenting both with equal
/// confidence.
@Model
final class ExerciseRelationship {
    var id = UUID()
    var type: ExerciseRelationshipType
    var sourceExercise: Exercise?
    var targetExercise: Exercise?

    /// How the link came to exist. `nil` for rows persisted before this field
    /// existed; read `resolvedProvenance` instead of this raw value.
    var provenanceRaw: String?
    /// Stable localization key for the curated rationale ("why a coach
    /// considers this a valid substitute"). A **key**, never a sentence — a
    /// persisted English literal could never be localized afterwards.
    var rationaleCode: String?
    /// Optional constraints. Empty means "no constraint", which is different
    /// from a constraint that happens to match nothing.
    var appliesToGoalsRaw: [String] = []
    var appliesToRolesRaw: [String] = []
    /// The curation round that approved this link, so a later review pass can
    /// find everything it has not yet revisited.
    var reviewVersion: Int?

    init(
        sourceExercise: Exercise,
        targetExercise: Exercise,
        type: ExerciseRelationshipType,
        provenance: SubstitutionProvenance? = nil,
        rationaleCode: String? = nil,
        appliesToGoals: [PlanGoal] = [],
        appliesToRoles: [ExerciseRole] = [],
        reviewVersion: Int? = nil
    ) {
        self.sourceExercise = sourceExercise
        self.targetExercise = targetExercise
        self.type = type
        self.provenanceRaw = provenance?.rawValue
        self.rationaleCode = rationaleCode
        self.appliesToGoalsRaw = appliesToGoals.map(\.rawValue)
        self.appliesToRolesRaw = appliesToRoles.map(\.rawValue)
        self.reviewVersion = reviewVersion
    }

    /// Legacy and seeded rows read as `systemUnreviewed` rather than as
    /// reviewed. Absence of evidence is not evidence of curation.
    var resolvedProvenance: SubstitutionProvenance {
        provenanceRaw.flatMap(SubstitutionProvenance.init(rawValue:)) ?? .systemUnreviewed
    }

    var appliesToGoals: [PlanGoal] {
        appliesToGoalsRaw.compactMap(PlanGoal.init(rawValue:))
    }

    var appliesToRoles: [ExerciseRole] {
        appliesToRolesRaw.compactMap(ExerciseRole.init(rawValue:))
    }

    /// An empty constraint list means the link is unconstrained. A goal or role
    /// the app does not know about must not silently exclude the link either —
    /// only a populated list that excludes the value filters it out.
    func applies(goal: PlanGoal?, role: ExerciseRole?) -> Bool {
        if !appliesToGoalsRaw.isEmpty, let goal, !appliesToGoalsRaw.contains(goal.rawValue) {
            return false
        }
        if !appliesToRolesRaw.isEmpty, let role, !appliesToRolesRaw.contains(role.rawValue) {
            return false
        }
        return true
    }
}
