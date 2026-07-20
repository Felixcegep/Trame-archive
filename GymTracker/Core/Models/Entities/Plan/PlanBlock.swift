import Foundation
import SwiftData

@Model
final class PlanBlock {
    var id = UUID()
    var name: String
    var phaseType: PlanPhaseType
    var goal: String?
    var notes: String?
    var deloadVolumeReductionPercent: Int?
    var deloadIntensityReductionPercent: Int?
    var orderIndex: Int
    var plan: WorkoutPlan?
    @Relationship(deleteRule: .cascade, inverse: \PlanWeek.block)
    var weeks: [PlanWeek] = []

    init(
        name: String,
        phaseType: PlanPhaseType,
        orderIndex: Int,
        goal: String? = nil,
        notes: String? = nil,
        deloadVolumeReductionPercent: Int? = nil,
        deloadIntensityReductionPercent: Int? = nil,
        weeks: [PlanWeek] = []
    ) {
        self.name = name
        self.phaseType = phaseType
        self.orderIndex = orderIndex
        self.goal = goal
        self.notes = notes
        self.deloadVolumeReductionPercent = deloadVolumeReductionPercent
        self.deloadIntensityReductionPercent = deloadIntensityReductionPercent
        self.weeks = weeks
    }

    var orderedWeeks: [PlanWeek] {
        weeks.sorted { $0.weekIndex < $1.weekIndex }
    }

    var isDeload: Bool {
        phaseType == .deload
    }

    var effectiveDeloadVolumeReductionPercent: Int {
        guard isDeload else { return 0 }
        return min(90, max(0, deloadVolumeReductionPercent ?? 50))
    }

    var effectiveDeloadIntensityReductionPercent: Int {
        guard isDeload else { return 0 }
        return min(90, max(0, deloadIntensityReductionPercent ?? 10))
    }
}

enum PlanDeloadService {
    static func apply(to entry: ExerciseEntry, for block: PlanBlock?) {
        guard let block, block.isDeload else { return }

        let volumeMultiplier = 1 - Double(block.effectiveDeloadVolumeReductionPercent) / 100
        let intensityMultiplier = 1 - Double(block.effectiveDeloadIntensityReductionPercent) / 100

        if let prescribedSets = entry.prescribedSets {
            let adjustedSets = max(1, Int((Double(prescribedSets) * volumeMultiplier).rounded(.up)))
            entry.prescribedSets = adjustedSets
            entry.sets = Array(entry.orderedSets.prefix(adjustedSets))
        }

        if let prescribedLoad = entry.prescribedSuggestedLoad {
            let adjustedLoad = prescribedLoad * intensityMultiplier
            entry.prescribedSuggestedLoad = adjustedLoad
            if entry.exercise.trackingType.usesWeight {
                for set in entry.sets {
                    set.weight = Float(adjustedLoad)
                }
            }
        }
    }
}
