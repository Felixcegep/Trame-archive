import Foundation
import SwiftData

/// One known candidate, with the evidence for *why it is known* attached.
struct SubstitutionCandidate: Equatable {
    let exercise: Exercise
    let provenance: SubstitutionProvenance
    let rationaleCode: String?

    static func == (lhs: SubstitutionCandidate, rhs: SubstitutionCandidate) -> Bool {
        lhs.exercise.id == rhs.exercise.id
            && lhs.provenance == rhs.provenance
            && lhs.rationaleCode == rhs.rationaleCode
    }
}

/// Collects the candidates the app is *allowed* to offer.
///
/// This is the feature's integrity boundary. A substitution may only come from
/// an explicit `ExerciseRelationship.substitution` link or a plan-authored
/// `PlannedExerciseAlternative`. Exercise metadata ranks and explains those
/// known candidates; it never manufactures one. Two exercises that merely look
/// similar — same muscles, same movement pattern, similar name, shared tags —
/// are **not** a substitution, and this type will not return one.
enum SubstitutionCandidateSource {
    /// Explicit substitution links in either direction, plus the plan's own
    /// authored alternatives. Archived exercises and the source exercise
    /// itself are excluded; duplicates resolve to the strongest provenance.
    static func candidates(
        for source: Exercise,
        relationships: [ExerciseRelationship],
        plannedAlternatives: [PlannedExerciseAlternative] = [],
        goal: PlanGoal? = nil,
        role: ExerciseRole? = nil
    ) -> [SubstitutionCandidate] {
        var byExerciseID: [UUID: SubstitutionCandidate] = [:]

        for relationship in relationships where relationship.type == .substitution {
            guard relationship.applies(goal: goal, role: role) else { continue }

            let matched: Exercise?
            if relationship.sourceExercise?.id == source.id {
                matched = relationship.targetExercise
            } else if relationship.targetExercise?.id == source.id {
                matched = relationship.sourceExercise
            } else {
                matched = nil
            }

            guard let candidate = matched, !candidate.isArchived, candidate.id != source.id else {
                continue
            }
            insert(
                SubstitutionCandidate(
                    exercise: candidate,
                    provenance: relationship.resolvedProvenance,
                    rationaleCode: relationship.rationaleCode
                ),
                into: &byExerciseID
            )
        }

        // A plan author choosing an alternative is a deliberate authoring act,
        // so it carries `userAuthored` provenance even without a library link.
        for alternative in plannedAlternatives.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            let candidate = alternative.exercise
            guard !candidate.isArchived, candidate.id != source.id else { continue }
            insert(
                SubstitutionCandidate(
                    exercise: candidate,
                    provenance: .userAuthored,
                    rationaleCode: nil
                ),
                into: &byExerciseID
            )
        }

        return Array(byExerciseID.values)
    }

    /// When the same exercise is reachable through more than one route, keep
    /// the better-evidenced one so a reviewed link is never downgraded by an
    /// unreviewed duplicate.
    private static func insert(
        _ candidate: SubstitutionCandidate,
        into store: inout [UUID: SubstitutionCandidate]
    ) {
        guard let existing = store[candidate.exercise.id] else {
            store[candidate.exercise.id] = candidate
            return
        }
        if provenanceRank(candidate.provenance) > provenanceRank(existing.provenance) {
            store[candidate.exercise.id] = SubstitutionCandidate(
                exercise: candidate.exercise,
                provenance: candidate.provenance,
                // Preserve any curated rationale we already had rather than
                // losing it to a route that carries none.
                rationaleCode: candidate.rationaleCode ?? existing.rationaleCode
            )
        } else if store[candidate.exercise.id]?.rationaleCode == nil,
                  let rationale = candidate.rationaleCode {
            store[candidate.exercise.id] = SubstitutionCandidate(
                exercise: existing.exercise,
                provenance: existing.provenance,
                rationaleCode: rationale
            )
        }
    }

    private static func provenanceRank(_ provenance: SubstitutionProvenance) -> Int {
        switch provenance {
        case .systemReviewed: return 3
        case .userAuthored: return 2
        case .importedProgram: return 1
        case .systemUnreviewed: return 0
        }
    }
}
