import Foundation

/// User-controlled catalogue refinements. Empty selections mean "all" for
/// that facet; populated facets combine with AND while values within one facet
/// combine with OR.
struct ProgramDiscoveryFilters: Equatable {
    var disciplines: Set<TrainingDisciplinePreference> = []
    var goals: Set<PlanGoal> = []
    var experienceLevels: Set<PlanExperienceLevel> = []
    var daysPerWeek: Set<Int> = []
    var availableEquipment: Set<EquipmentType> = []
    var availableCapabilityIDs: Set<String> = []
    var durationWeeks: Set<Int> = []
    var scheduleModes: Set<PlanScheduleMode> = []

    var isEmpty: Bool {
        disciplines.isEmpty && goals.isEmpty && experienceLevels.isEmpty
            && daysPerWeek.isEmpty && availableEquipment.isEmpty
            && availableCapabilityIDs.isEmpty && durationWeeks.isEmpty
            && scheduleModes.isEmpty
    }

    var activeFacetCount: Int {
        [
            !disciplines.isEmpty, !goals.isEmpty, !experienceLevels.isEmpty,
            !daysPerWeek.isEmpty,
            !availableEquipment.isEmpty || !availableCapabilityIDs.isEmpty,
            !durationWeeks.isEmpty, !scheduleModes.isEmpty
        ].filter { $0 }.count
    }

    mutating func clear() { self = .init() }

    func matches(_ candidate: ProgramMatchCandidate) -> Bool {
        if !disciplines.isEmpty,
           !disciplines.contains(where: candidate.matchesDiscipline) { return false }
        if !goals.isEmpty, !goals.contains(candidate.goal) { return false }
        if !experienceLevels.isEmpty, !experienceLevels.contains(candidate.experienceLevel) { return false }
        if !daysPerWeek.isEmpty,
           daysPerWeek.isDisjoint(with: candidate.supportedDaysPerWeek) { return false }
        if !durationWeeks.isEmpty, !durationWeeks.contains(candidate.durationWeeks) { return false }
        if !scheduleModes.isEmpty, !scheduleModes.contains(candidate.scheduleMode) { return false }

        if !availableEquipment.isEmpty || !availableCapabilityIDs.isEmpty {
            let requirement = candidate.equipmentRequirement
            guard requirement.allOf.allSatisfy(availableEquipment.contains) else { return false }
            guard requirement.anyOf.allSatisfy({ group in group.contains(where: availableEquipment.contains) }) else {
                return false
            }
            guard requirement.requiredCapabilityIDs.allSatisfy(availableCapabilityIDs.contains) else {
                return false
            }
        }
        return true
    }
}
