import Foundation

struct PlanExerciseAlternativeCandidate {
    let exercise: Exercise
    let score: Int
    let reason: String
}

/// Orders explicit plan-alternative choices without selecting one on the
/// lifter's behalf. The ranking makes compatible options easier to find while
/// preserving an intentional final choice in the plan editor.
enum PlanExerciseAlternativeScoringService {
    static func rankedCandidates(
        for source: Exercise,
        from candidates: [Exercise]
    ) -> [PlanExerciseAlternativeCandidate] {
        candidates.map { candidate in
            let result = score(source: source, candidate: candidate)
            return PlanExerciseAlternativeCandidate(
                exercise: candidate,
                score: result.score,
                reason: result.reason
            )
        }
        .sorted {
            $0.score == $1.score
                ? $0.exercise.name.localizedCaseInsensitiveCompare($1.exercise.name) == .orderedAscending
                : $0.score > $1.score
        }
    }

    private static func score(source: Exercise, candidate: Exercise) -> (score: Int, reason: String) {
        if source.variationFamilyID?.isEmpty == false,
           source.variationFamilyID == candidate.variationFamilyID {
            return (100, "Same movement family")
        }
        if source.movementPattern != nil, source.movementPattern == candidate.movementPattern,
           source.primaryMuscles.contains(where: candidate.primaryMuscles.contains) {
            return (80, "Same movement pattern and primary muscle")
        }
        if source.primaryMuscles.contains(where: candidate.primaryMuscles.contains) {
            return (60, "Shares a primary muscle")
        }
        if source.trackingType == candidate.trackingType {
            return (40, "Same logging style")
        }
        return (0, "Other library exercise")
    }
}
