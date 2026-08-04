import Foundation

/// Central registry mapping strength exercises to required joint range of motion thresholds.
enum MovementRequirementRegistry {
    /// Canonical requirements table indexed by exercise seed/catalogue key.
    static let requirementsByExercise: [String: [MovementRequirement]] = [
        "barbell_back_squat": [
            MovementRequirement(
                exerciseCatalogueKey: "barbell_back_squat",
                jointZone: .ankles,
                assessmentCatalogueKey: "knee_to_wall_dorsiflexion",
                minRequiredValue: 10.0,
                unit: .centimetres,
                requirementDescription: "Requires 10.0cm knee-to-wall dorsiflexion for depth without heel lift."
            ),
            MovementRequirement(
                exerciseCatalogueKey: "barbell_back_squat",
                jointZone: .hips,
                assessmentCatalogueKey: "hip_flexion_90_90",
                minRequiredValue: 110.0,
                unit: .degrees,
                requirementDescription: "Requires 110° passive hip flexion for a parallel squat position."
            )
        ],
        "overhead_press": [
            MovementRequirement(
                exerciseCatalogueKey: "overhead_press",
                jointZone: .shoulders,
                assessmentCatalogueKey: "shoulder_flexion_supine",
                minRequiredValue: 170.0,
                unit: .degrees,
                requirementDescription: "Requires 170° shoulder flexion for lock-out over midfoot."
            )
        ],
        "romanian_deadlift": [
            MovementRequirement(
                exerciseCatalogueKey: "romanian_deadlift",
                jointZone: .hips,
                assessmentCatalogueKey: "active_straight_leg_raise",
                minRequiredValue: 70.0,
                unit: .degrees,
                requirementDescription: "Requires 70° active straight leg raise for posterior chain hinge."
            )
        ]
    ]

    static func requirements(for exerciseKey: String) -> [MovementRequirement] {
        requirementsByExercise[exerciseKey] ?? []
    }
}

/// Evaluator that compares latest assessment results against movement requirements.
enum MovementRequirementEvaluator {
    static func evaluate(
        exerciseKey: String,
        latestResultsByAssessmentKey: [String: MobilityAssessmentResult]
    ) -> [MovementCapacityVerdict] {
        let requirements = MovementRequirementRegistry.requirements(for: exerciseKey)
        guard !requirements.isEmpty else { return [] }

        return requirements.map { req in
            guard let result = latestResultsByAssessmentKey[req.assessmentCatalogueKey],
                  let val = result.numericValue else {
                return .insufficientAssessmentData(missingAssessmentKey: req.assessmentCatalogueKey)
            }

            let delta = val - req.minRequiredValue
            if delta >= 0 {
                return .capacitySufficient(headroom: delta)
            } else {
                return .restrictionDetected(gap: abs(delta), requirement: req.requirementDescription)
            }
        }
    }
}
