import Foundation
import SwiftData

/// One program, reduced to what ranking needs.
///
/// The ranking deliberately does not see a `ProgramDefinitionRecord`: it should
/// not be able to reach a payload's blocks, its progression rules, or the store
/// at all. Everything it can read is here, which is also what makes every
/// reason it produces reproducible from a fixture.
struct ProgramMatchCandidate: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let summary: String?
    let goal: PlanGoal
    let experienceLevel: PlanExperienceLevel
    let supportedDaysPerWeek: [Int]
    let durationWeeks: Int
    let scheduleMode: PlanScheduleMode
    let requiredEquipment: [EquipmentType]
    /// Free-text, author-written conditions ("Known one-repetition maximums
    /// for squat, bench press, and deadlift"). Nothing in the intake can
    /// verify these, so `ProgramMatchService` always discloses them rather
    /// than assuming they are met.
    let prerequisites: [String]
    let requiredCapabilities: [String]
    let authorWarnings: [String]
    let isExperimental: Bool

    // Optional matching metadata. Absent means "this program never said",
    // which must never be scored as a mismatch.
    let supportedDisciplineIDs: [String]
    let focusAreaIDs: [String]
    let estimatedSessionMinutes: ClosedRange<Int>?
    let competitionDisciplineID: String?

    /// Whether this program is written for the lifter's discipline.
    ///
    /// An explicit declaration wins. Where a program has not declared one —
    /// which is the entire catalogue as it stands — the discipline is inferred
    /// from its `PlanGoal`, so the question still contributes something on day
    /// one instead of waiting for every definition to be re-authored.
    func matchesDiscipline(_ discipline: TrainingDisciplinePreference) -> Bool {
        if !supportedDisciplineIDs.isEmpty {
            return supportedDisciplineIDs.contains(discipline.rawValue)
        }
        return discipline.associatedPlanGoals.contains(goal)
    }
}

extension ProgramMatchCandidate {
    init(payload: ProgramDefinitionPayload) {
        let minimumMinutes = payload.estimatedSessionMinutesMinimum
        let maximumMinutes = payload.estimatedSessionMinutesMaximum
        let minutes: ClosedRange<Int>? = {
            switch (minimumMinutes, maximumMinutes) {
            case let (lower?, upper?) where lower <= upper: lower...upper
            case let (lower?, nil): lower...lower
            case let (nil, upper?): upper...upper
            default: nil
            }
        }()

        self.init(
            id: payload.id,
            name: payload.name,
            summary: payload.description,
            goal: payload.goal,
            experienceLevel: payload.experienceLevel,
            supportedDaysPerWeek: payload.supportedDaysPerWeek,
            durationWeeks: payload.durationWeeks,
            scheduleMode: payload.scheduleMode,
            requiredEquipment: payload.requiredEquipment,
            prerequisites: payload.prerequisites,
            requiredCapabilities: payload.requiredCapabilities,
            authorWarnings: payload.warnings,
            isExperimental: payload.isExperimental,
            supportedDisciplineIDs: payload.supportedDisciplineIDs ?? [],
            focusAreaIDs: payload.focusAreaIDs ?? [],
            estimatedSessionMinutes: minutes,
            competitionDisciplineID: payload.competitionDisciplineID
        )
    }

    /// Every catalogue entry the lifter could start today.
    ///
    /// A record whose payload will not decode is skipped rather than surfaced
    /// as a broken card: a program the app cannot read is not a recommendation
    /// it can stand behind.
    @MainActor
    static func candidates(using context: ModelContext) -> [ProgramMatchCandidate] {
        let records = (try? context.fetch(FetchDescriptor<ProgramDefinitionRecord>())) ?? []
        return records
            .filter { !$0.isArchived }
            .compactMap { record in
                guard let payload = try? record.payload() else { return nil }
                return ProgramMatchCandidate(payload: payload)
            }
    }
}
