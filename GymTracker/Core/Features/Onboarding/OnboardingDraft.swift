import Foundation

/// Everything the lifter has answered so far, and where they were when they
/// left. Held separately from `TrainingProfile` because an abandoned onboarding
/// must not write a profile: a half-answered questionnaire is not a statement
/// about how someone trains, and the app should not start ranking programs from
/// one.
///
/// The draft is the only thing that survives a relaunch mid-flow. It is written
/// to `UserDefaults` rather than to the store because it is preference-shaped,
/// because it must be readable before the SwiftData container is known to have
/// opened, and because throwing it away on a schema change is harmless.
struct OnboardingDraft: Codable, Equatable, Sendable {
    /// Bumped only when a field changes meaning. A draft from an older version
    /// is discarded rather than migrated — it is at most a few minutes of
    /// answers, and migrating it is more risk than it is worth.
    static let currentVersion = 1

    var version: Int = OnboardingDraft.currentVersion

    var selectedPath: TrainingStructureChoice?
    /// The step the user was last looking at, by stable id. Resolved against
    /// the *recomputed* step list on restore, so a step that no longer applies
    /// (or no longer exists) falls back rather than stranding the flow.
    var currentStepID: String?
    var completedStepIDs: [String] = []
    /// Whether the questions are behind us.
    ///
    /// Without this, leaving the app on the results screen resumed at the last
    /// *question* instead: `currentStepID` is nil once the questions are done,
    /// and "no current step" is indistinguishable from "never started one" if
    /// the phase itself is not recorded. Answering everything and then being
    /// handed the final question back reads as the flow restarting.
    var hasReachedRecommendations: Bool = false

    var discipline: TrainingDisciplinePreference?
    var goal: TrainingGoalPreference?
    var experience: ProfileExperienceLevel?

    var preferredDaysPerWeek: Int?
    var scheduleFlexibility: ScheduleFlexibility?
    /// `Calendar` weekday numbers (1 = Sunday), kept as a sorted array rather
    /// than a `Set` so the encoded form is stable and diffable.
    var preferredWeekdays: [Int] = []
    var rotationCadence: RotationCadencePreference?

    var sessionDuration: SessionDurationPreference?

    var location: TrainingLocationPreference?
    /// `EquipmentType.rawValue`s. Strings rather than the enum so a value a
    /// future build adds survives a round trip through this one.
    var equipmentIDs: [String] = []
    var specializedEquipmentIDs: [String] = []

    var unitSystem: UnitSystem?

    var focusAreas: [FocusArea] = []
    var competition: CompetitionProfileDraft?

    // MARK: Derived

    var equipment: Set<EquipmentType> {
        get { Set(equipmentIDs.compactMap(EquipmentType.init(rawValue:))) }
        set { equipmentIDs = newValue.map(\.rawValue).sorted() }
    }

    var weekdays: Set<Int> {
        get { Set(preferredWeekdays) }
        set { preferredWeekdays = newValue.sorted() }
    }

    var specializedEquipment: Set<String> {
        get { Set(specializedEquipmentIDs) }
        set { specializedEquipmentIDs = newValue.sorted() }
    }

    /// Whether anything has been answered beyond the routing choice. Used to
    /// decide whether abandoning the flow is worth confirming.
    var hasAnswers: Bool {
        discipline != nil
            || goal != nil
            || experience != nil
            || preferredDaysPerWeek != nil
            || rotationCadence != nil
            || sessionDuration != nil
            || location != nil
            || !equipmentIDs.isEmpty
            || !focusAreas.isEmpty
            || competition?.isEmpty == false
    }

    /// Applies a location's equipment suggestion.
    ///
    /// Only ever *adds*, and only when the user has not already curated the
    /// list. Someone who unticked "Cardio machines" and then went back to
    /// change their location should not find it ticked again — that is the app
    /// overruling an explicit answer with an inferred one.
    mutating func applyLocationSuggestion(replacingExisting: Bool) {
        guard let location else { return }
        let suggestion = location.suggestedEquipment
        guard !suggestion.isEmpty else { return }
        if replacingExisting || equipmentIDs.isEmpty {
            equipment = suggestion
        }
    }
}

/// Reads and writes the in-progress draft.
///
/// Deliberately not `@Observable`: the coordinator owns the live draft and this
/// only persists it, so there is exactly one source of truth on screen.
struct OnboardingDraftStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = DefaultsKey.onboardingDraft) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> OnboardingDraft? {
        guard let data = defaults.data(forKey: key),
              let draft = try? JSONDecoder().decode(OnboardingDraft.self, from: data),
              draft.version == OnboardingDraft.currentVersion
        else { return nil }
        return draft
    }

    func save(_ draft: OnboardingDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
