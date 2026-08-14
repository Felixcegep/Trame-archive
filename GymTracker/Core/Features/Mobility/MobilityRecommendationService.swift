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
    static let recommendationsByAssessment: [String: (routineKey: String, title: String)] = [
        "mobility-assessment.knee-to-wall-dorsiflexion": (
            routineKey: "mobility-routine.ankle-foot-mobilization",
            title: "Ankle Dorsiflexion PNF Stretch"
        ),
        "mobility-assessment.90-90-hip-rotation": (
            routineKey: "mobility-routine.squat-preparation-v2",
            title: "90/90 Hip Rotation Preparation"
        ),
        "mobility-assessment.wall-slide-arm-elevation": (
            routineKey: "mobility-routine.overhead-shoulder-saver",
            title: "Overhead Shoulder Flexion Mobilization"
        ),
        "mobility-assessment.active-straight-leg-raise": (
            routineKey: "mobility-routine.deadlift-preparation-v2",
            title: "Posterior Chain Dynamic Hinge Routine"
        )
    ]

    /// Routine catalogue keys referenced by recommendation mappings.
    static var routineCatalogueKeys: Set<String> {
        Set(recommendationsByAssessment.values.map(\.routineKey))
    }

    static func recommendRoutines(for verdicts: [MovementCapacityVerdict]) -> [MobilityRecommendation] {
        var recommendations = [MobilityRecommendation]()

        for verdict in verdicts {
            if case .restrictionDetected(let gap, let requirement) = verdict {
                // Determine target assessment key from requirement message
                for (assessmentKey, recInfo) in recommendationsByAssessment {
                    if requirement.lowercased().contains(assessmentKey.replacingOccurrences(of: "_", with: " ")) ||
                        (assessmentKey == "mobility-assessment.knee-to-wall-dorsiflexion" && requirement.contains("dorsiflexion")) ||
                        (assessmentKey == "mobility-assessment.90-90-hip-rotation" && requirement.contains("hip flexion")) ||
                        (assessmentKey == "mobility-assessment.wall-slide-arm-elevation" && requirement.contains("shoulder flexion")) ||
                        (assessmentKey == "mobility-assessment.active-straight-leg-raise" && requirement.contains("straight leg raise")) {
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
