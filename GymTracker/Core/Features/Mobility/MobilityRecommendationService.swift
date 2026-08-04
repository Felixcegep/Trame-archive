import Foundation

struct MobilityRecommendation: Equatable, Identifiable, Sendable {
    let id: UUID
    let targetAssessmentKey: String
    let routineCatalogueKey: String
    let title: String
    let reason: String
    let priority: Int

    init(
        id: UUID = UUID(),
        targetAssessmentKey: String,
        routineCatalogueKey: String,
        title: String,
        reason: String,
        priority: Int = 1
    ) {
        self.id = id
        self.targetAssessmentKey = targetAssessmentKey
        self.routineCatalogueKey = routineCatalogueKey
        self.title = title
        self.reason = reason
        self.priority = priority
    }
}

enum MobilityRecommendationService {
    /// Mapping from assessment keys to recommended corrective mobility routines.
    private static let recommendationsByAssessment: [String: (routineKey: String, title: String)] = [
        "knee_to_wall_dorsiflexion": (
            routineKey: "ankle_dorsiflexion_pnf",
            title: "Ankle Dorsiflexion PNF Stretch"
        ),
        "shoulder_flexion_supine": (
            routineKey: "overhead_shoulder_mobility",
            title: "Overhead Shoulder Flexion Mobilization"
        ),
        "active_straight_leg_raise": (
            routineKey: "posterior_chain_hinge_prep",
            title: "Posterior Chain Dynamic Hinge Routine"
        )
    ]

    static func recommendRoutines(for verdicts: [MovementCapacityVerdict]) -> [MobilityRecommendation] {
        var recommendations = [MobilityRecommendation]()

        for verdict in verdicts {
            if case .restrictionDetected(let gap, let requirement) = verdict {
                // Determine target assessment key from requirement message
                for (assessmentKey, recInfo) in recommendationsByAssessment {
                    if requirement.lowercased().contains(assessmentKey.replacingOccurrences(of: "_", with: " ")) ||
                        (assessmentKey == "knee_to_wall_dorsiflexion" && requirement.contains("dorsiflexion")) ||
                        (assessmentKey == "shoulder_flexion_supine" && requirement.contains("shoulder flexion")) ||
                        (assessmentKey == "active_straight_leg_raise" && requirement.contains("straight leg raise")) {
                        let rec = MobilityRecommendation(
                            targetAssessmentKey: assessmentKey,
                            routineCatalogueKey: recInfo.routineKey,
                            title: recInfo.title,
                            reason: "Restricted by \(String(format: "%.1f", gap)) — \(requirement)",
                            priority: 1
                        )
                        if !recommendations.contains(where: { $0.routineCatalogueKey == recInfo.routineKey }) {
                            recommendations.append(rec)
                        }
                    }
                }
            }
        }

        return recommendations.sorted(by: { $0.priority > $1.priority })
    }
}
