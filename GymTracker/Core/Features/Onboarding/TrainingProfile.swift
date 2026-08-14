import Foundation
import SwiftData

/// What the lifter told us about how they train.
///
/// Every field is optional and every enumerated value is stored as its raw
/// string. Both choices are for the same reason: a profile is a set of
/// preferences, and the honest representation of "not asked" and "declined to
/// answer" is nothing at all. An existing user who has never seen onboarding
/// gets a profile full of `nil` rather than a set of invented answers, and a
/// value written by a newer build reads back as unrecognised instead of
/// failing a restore.
///
/// This never participates in compiling a plan. It ranks and explains; the
/// prescription comes from the program definition and the activation inputs.
@Model
final class TrainingProfile {
    var id: UUID = UUID()
    /// The stored shape of this record. Distinct from the onboarding flow's
    /// own version, which describes the questions that were asked.
    var schemaVersion: Int = 1
    var onboardingVersion: Int = 1

    var preferredTrainingStructureRaw: String?

    var primaryDisciplineRaw: String?
    var secondaryDisciplineIDs: [String] = []

    var primaryGoalRaw: String?
    var experienceLevelRaw: String?

    var preferredDaysPerWeek: Int?
    var preferredWeekdays: [Int] = []
    var scheduleFlexibilityRaw: String?
    var rotationCadenceRaw: String?

    var sessionDurationRaw: String?

    var trainingLocationRaw: String?
    var equipmentCapabilityIDs: [String] = []
    var specializedEquipmentCapabilityIDs: [String] = []

    var focusAreaIDs: [String] = []

    /// Encoded `CompetitionProfileDraft`. Held as data rather than as columns
    /// because it is a rarely-populated cluster that will grow federation,
    /// division and weight-class fields, and none of those are worth querying.
    var competitionProfileData: Data?

    // MARK: Mobility
    //
    // Independent of the strength-training fields above — see
    // `OnboardingDraft`'s mobility section for why. Optional and additive:
    // an existing profile restores with these `nil` and simply contributes
    // nothing to mobility matching until answered, either in onboarding or in
    // Training profile settings.
    var mobilityGoalRaw: String?
    var mobilityExperienceRaw: String?
    var mobilityFrequencyRaw: String?

    var completedCoreOnboardingAt: Date?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(id: UUID = UUID()) {
        self.id = id
    }

    // MARK: Typed access

    var primaryDiscipline: TrainingDisciplinePreference? {
        primaryDisciplineRaw.flatMap(TrainingDisciplinePreference.init(rawValue:))
    }

    /// Typed secondary disciplines. Unknown identifiers remain in the raw
    /// backup field for forward compatibility but are intentionally absent
    /// from this projection until this build understands them.
    var secondaryDisciplines: [TrainingDisciplinePreference] {
        get { secondaryDisciplineIDs.compactMap(TrainingDisciplinePreference.init(rawValue:)) }
        set {
            let knownRawValues = Set(TrainingDisciplinePreference.allCases.map(\.rawValue))
            let unknownRawValues = secondaryDisciplineIDs.filter { !knownRawValues.contains($0) }
            secondaryDisciplineIDs = newValue.map(\.rawValue) + unknownRawValues
        }
    }

    /// Stored as a reserved forward-compatible secondary identifier instead
    /// of a new SwiftData column. Progress organization is presentation state,
    /// and does not justify changing the frozen historical store shape.
    var progressOrganizationModeRaw: String? {
        get {
            secondaryDisciplineIDs
                .first { $0.hasPrefix(Self.progressOrganizationPrefix) }
                .map { String($0.dropFirst(Self.progressOrganizationPrefix.count)) }
        }
        set {
            secondaryDisciplineIDs.removeAll { $0.hasPrefix(Self.progressOrganizationPrefix) }
            if let newValue {
                secondaryDisciplineIDs.append(Self.progressOrganizationPrefix + newValue)
            }
        }
    }

    var progressOrganizationMode: ProgressOrganizationMode? {
        progressOrganizationModeRaw.flatMap(ProgressOrganizationMode.init(rawValue:))
    }

    private static let progressOrganizationPrefix = "progressOrganization:"

    var primaryGoal: TrainingGoalPreference? {
        primaryGoalRaw.flatMap(TrainingGoalPreference.init(rawValue:))
    }

    var experienceLevel: ProfileExperienceLevel? {
        experienceLevelRaw.flatMap(ProfileExperienceLevel.init(rawValue:))
    }

    var scheduleFlexibility: ScheduleFlexibility? {
        scheduleFlexibilityRaw.flatMap(ScheduleFlexibility.init(rawValue:))
    }

    var rotationCadence: RotationCadencePreference? {
        rotationCadenceRaw.flatMap(RotationCadencePreference.init(rawValue:))
    }

    var sessionDuration: SessionDurationPreference? {
        sessionDurationRaw.flatMap(SessionDurationPreference.init(rawValue:))
    }

    var trainingLocation: TrainingLocationPreference? {
        trainingLocationRaw.flatMap(TrainingLocationPreference.init(rawValue:))
    }

    var trainingStructure: TrainingStructureChoice? {
        preferredTrainingStructureRaw.flatMap(TrainingStructureChoice.init(rawValue:))
    }

    var equipment: Set<EquipmentType> {
        Set(equipmentCapabilityIDs.compactMap(EquipmentType.init(rawValue:)))
    }

    var focusAreas: [FocusArea] {
        focusAreaIDs.compactMap(FocusArea.init(rawValue:))
    }

    var competition: CompetitionProfileDraft? {
        guard let competitionProfileData else { return nil }
        return try? JSONDecoder().decode(CompetitionProfileDraft.self, from: competitionProfileData)
    }

    var mobilityGoal: MobilityGoalPreference? {
        mobilityGoalRaw.flatMap(MobilityGoalPreference.init(rawValue:))
    }

    var mobilityExperience: MobilityExperiencePreference? {
        mobilityExperienceRaw.flatMap(MobilityExperiencePreference.init(rawValue:))
    }

    var mobilityFrequency: MobilityFrequencyPreference? {
        mobilityFrequencyRaw.flatMap(MobilityFrequencyPreference.init(rawValue:))
    }

    /// The matching input this profile represents. Extracted as a value type so
    /// ranking can be exercised without a store.
    var matchingCriteria: ProgramMatchCriteria {
        ProgramMatchCriteria(
            discipline: primaryDiscipline,
            goal: primaryGoal,
            experience: experienceLevel,
            preferredDaysPerWeek: preferredDaysPerWeek,
            rotationCadence: rotationCadence,
            scheduleFlexibility: scheduleFlexibility,
            sessionDuration: sessionDuration,
            availableEquipment: equipment,
            availableEquipmentCapabilityIDs: Set(specializedEquipmentCapabilityIDs),
            focusAreas: focusAreas,
            competitionDiscipline: competition?.discipline,
            competitionDate: competition?.eventDate
        )
    }

    /// The mobility matching input this profile represents, independent of
    /// `matchingCriteria` — mirrors it existing for the workout side.
    var mobilityMatchingCriteria: MobilityMatchCriteria {
        MobilityMatchCriteria(
            goal: mobilityGoal,
            experience: mobilityExperience,
            frequency: mobilityFrequency
        )
    }
}

/// Reads and writes the single profile record.
///
/// A service rather than free functions on the view, because "changing a
/// preference must never touch training history" is a property that has to hold
/// at exactly one place: this type only ever writes to `TrainingProfile`, and
/// nothing here can reach a `Workout`, a `PlanRun`, or a progression receipt.
@MainActor
enum TrainingProfileService {
    /// The current profile, or `nil` when the lifter has never answered
    /// anything. Callers must treat `nil` as "no preferences", never as a
    /// reason to prompt.
    static func current(using context: ModelContext) -> TrainingProfile? {
        var descriptor = FetchDescriptor<TrainingProfile>()
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Writes the answers from a finished onboarding run.
    ///
    /// Only fields the lifter actually answered are written. A skipped question
    /// leaves whatever was there before, so completing onboarding a second time
    /// and skipping a step does not silently erase the first answer.
    @discardableResult
    static func apply(_ draft: OnboardingDraft, using context: ModelContext) -> TrainingProfile {
        let profile = current(using: context) ?? {
            let created = TrainingProfile()
            context.insert(created)
            return created
        }()

        if let path = draft.selectedPath {
            profile.preferredTrainingStructureRaw = path.rawValue
        }
        if let discipline = draft.discipline {
            profile.primaryDisciplineRaw = discipline.rawValue
        }
        if let goal = draft.goal {
            profile.primaryGoalRaw = goal.rawValue
        }
        if let experience = draft.experience {
            profile.experienceLevelRaw = experience.rawValue
        }
        if let days = draft.preferredDaysPerWeek {
            profile.preferredDaysPerWeek = days
        }
        if let flexibility = draft.scheduleFlexibility {
            profile.scheduleFlexibilityRaw = flexibility.rawValue
        }
        if !draft.preferredWeekdays.isEmpty {
            profile.preferredWeekdays = draft.preferredWeekdays
        }
        if let cadence = draft.rotationCadence {
            profile.rotationCadenceRaw = cadence.rawValue
        }
        if let duration = draft.sessionDuration {
            profile.sessionDurationRaw = duration.rawValue
        }
        if let location = draft.location {
            profile.trainingLocationRaw = location.rawValue
        }
        if !draft.equipmentIDs.isEmpty {
            profile.equipmentCapabilityIDs = draft.equipmentIDs
        }
        if !draft.specializedEquipmentIDs.isEmpty {
            profile.specializedEquipmentCapabilityIDs = draft.specializedEquipmentIDs
        }
        if !draft.focusAreas.isEmpty {
            profile.focusAreaIDs = draft.focusAreas.map(\.rawValue)
        }
        if let competition = draft.competition, !competition.isEmpty {
            profile.competitionProfileData = try? JSONEncoder().encode(competition)
        }
        if let mobilityGoal = draft.mobilityGoal {
            profile.mobilityGoalRaw = mobilityGoal.rawValue
        }
        if let mobilityExperience = draft.mobilityExperience {
            profile.mobilityExperienceRaw = mobilityExperience.rawValue
        }
        if let mobilityFrequency = draft.mobilityFrequency {
            profile.mobilityFrequencyRaw = mobilityFrequency.rawValue
        }

        profile.completedCoreOnboardingAt = .now
        profile.updatedAt = .now

        do {
            try context.save()
        } catch {
            context.rollback()
        }
        return profile
    }

    /// Applies the unit system the lifter chose.
    ///
    /// Display only. Canonical stored loads are untouched, which is why this
    /// writes a preference key rather than converting anything.
    static func applyUnitSystem(_ unitSystem: UnitSystem, defaults: UserDefaults = .standard) {
        defaults.set(unitSystem.rawValue, forKey: DefaultsKey.useMetric)
    }
}
