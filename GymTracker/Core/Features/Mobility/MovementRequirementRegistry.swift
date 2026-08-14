import Foundation

/// Central registry mapping strength exercises to required joint range of motion thresholds.
enum MovementRequirementRegistry {
    /// Canonical requirements table indexed by exercise seed/catalogue key.
    static let requirementsByExercise: [String: [MovementRequirement]] = [
        "barbell_back_squat": [
            MovementRequirement(
                exerciseCatalogueKey: "barbell_back_squat",
                jointZone: .ankles,
                assessmentCatalogueKey: "mobility-assessment.knee-to-wall-dorsiflexion",
                minRequiredValue: 10.0,
                unit: .centimetres,
                requirementDescription: "Requires 10.0cm knee-to-wall dorsiflexion for depth without heel lift."
            ),
            MovementRequirement(
                exerciseCatalogueKey: "barbell_back_squat",
                jointZone: .hips,
                assessmentCatalogueKey: "mobility-assessment.90-90-hip-rotation",
                minRequiredValue: 110.0,
                unit: .degrees,
                requirementDescription: "Requires 110° passive hip flexion for a parallel squat position."
            )
        ],
        "overhead_press": [
            MovementRequirement(
                exerciseCatalogueKey: "overhead_press",
                jointZone: .shoulders,
                assessmentCatalogueKey: "mobility-assessment.wall-slide-arm-elevation",
                minRequiredValue: 170.0,
                unit: .degrees,
                requirementDescription: "Requires 170° shoulder flexion for lock-out over midfoot."
            )
        ],
        "romanian_deadlift": [
            MovementRequirement(
                exerciseCatalogueKey: "romanian_deadlift",
                jointZone: .hips,
                assessmentCatalogueKey: "mobility-assessment.active-straight-leg-raise",
                minRequiredValue: 70.0,
                unit: .degrees,
                requirementDescription: "Requires 70° active straight leg raise for posterior chain hinge."
            )
        ]
    ]

    /// Assessment catalogue keys referenced by the requirements table.
    /// Keeping this derived from the table prevents the test-facing inventory
    /// from drifting away from the evaluator's actual lookup keys.
    static var assessmentCatalogueKeys: Set<String> {
        Set(requirementsByExercise.values.flatMap { requirements in
            requirements.map(\.assessmentCatalogueKey)
        })
    }

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
