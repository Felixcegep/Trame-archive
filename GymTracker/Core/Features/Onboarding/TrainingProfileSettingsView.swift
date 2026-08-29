import SwiftData
import SwiftUI

/// Everything onboarding asked, editable for good.
///
/// A form rather than a second run of the wizard. A wizard is for a person who
/// does not yet know what the app will ask; someone opening this screen knows
/// exactly which answer they came to change, and making them walk past six
/// others to reach it would be the app charging them for its own sequencing.
///
/// Nothing on this screen can reach a workout, a plan run, or a progression
/// receipt. Changing an answer here changes what gets *recommended* from now
/// on; the plan already running keeps prescribing exactly what it prescribed
/// yesterday, which is the promise the first screen of onboarding made.
struct TrainingProfileSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [TrainingProfile]

    @State private var hasEnsuredProfile = false

    private var profile: TrainingProfile? { profiles.first }

    init() {
        var descriptor = FetchDescriptor<TrainingProfile>()
        descriptor.fetchLimit = 1
        _profiles = Query(descriptor)
    }

    /// Independent of every other section on this screen: a mobility answer
    /// changed here only ever affects mobility matching, never the workout
    /// plan currently ranked or running. Only shown when a mobility plan is
    /// actually reachable — see `OnboardingRecommendationsView`'s own gate.
    private var isMobilityMatchingEnabled: Bool {
        FeatureFlags.current.isEnabled(.mobilityProgram)
    }

    var body: some View {
        Form {
            Section {
                Text("Used to rank plans and suggest exercises. Changing anything here never alters a plan you are already following, or anything you have already trained.")
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.gymSubduedText)
            }

            if let profile {
                trainingLinkSection(profile)
                progressOrganizationSection(profile)
                if profile.primaryDiscipline == .powerlifting
                    || profile.secondaryDisciplines.contains(.powerlifting)
                    || profile.competition?.discipline == .powerlifting {
                    competitionLiftsLinkSection(profile)
                }
                scheduleLinkSection(profile)
                equipmentSection(profile)
                emphasisSection(profile)
                if isMobilityMatchingEnabled {
                    mobilitySection(profile)
                }
            }
        }
        // `Form` paints its own opaque system background underneath its
        // content — a `.background()` alone doesn't reach it the way it does
        // on a `ScrollView`, which is why this screen's own sub-screens
        // (Equipment, Weekdays, Specialised equipment — all plain
        // `ScrollView`s) were themed correctly while this one, the screen
        // people actually land on, rendered in the system's default grey.
        // Same fix `SettingView` already uses for its own `Form`.
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
        .navigationTitle("Training profile")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("training-profile-settings")
        .onAppear(perform: ensureProfile)
    }

    /// A lifter who skipped onboarding entirely still gets a screen they can
    /// fill in, rather than an empty state telling them to reinstall the app.
    private func ensureProfile() {
        guard !hasEnsuredProfile, profiles.isEmpty else {
            hasEnsuredProfile = true
            return
        }
        hasEnsuredProfile = true
        let created = TrainingProfile()
        modelContext.insert(created)
        save()
    }

    // MARK: Sections

    /// Discipline, Goal, and Experience used to sit here as three always-open
    /// pickers, immediately followed by a fourth section — a toggle list for
    /// secondary disciplines — that answers the closely related question "what
    /// *else* do you train." Three picker rows plus a toggle list is most of
    /// what made this screen read as a wall of menus before a single answer
    /// was even in view. They are one identity, asked in one place now,
    /// exactly the way Equipment and Weekdays already worked below.
    private func trainingLinkSection(_ profile: TrainingProfile) -> some View {
        Section {
            NavigationLink {
                TrainingProfileIdentityView(profile: profile)
            } label: {
                LabeledContent("Training", value: trainingSummary(profile))
            }
            .accessibilityIdentifier("training-profile-training-link")
        }
    }

    private func trainingSummary(_ profile: TrainingProfile) -> String {
        var parts: [String] = []
        if let discipline = profile.primaryDiscipline { parts.append(discipline.title) }
        if let goal = profile.primaryGoal { parts.append(goal.title) }
        if let experience = profile.experienceLevel { parts.append(experience.title) }
        return parts.isEmpty ? String(localized: "Not set") : parts.joined(separator: " · ")
    }

    private func progressOrganizationSection(_ profile: TrainingProfile) -> some View {
        Section {
            optionalPicker(
                label: String(localized: "Progress organization"),
                identifier: "training-profile-progress-organization",
                selection: rawBinding(profile, \.progressOrganizationModeRaw, onChange: { touch(profile) }),
                options: ProgressOrganizationMode.allCases,
                titleKeyPath: \.title
            )

            if let mode = profile.progressOrganizationMode {
                Text(mode.detail)
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("Progress")
        } footer: {
            Text("This controls which training lenses Progress puts first. It never changes your completed history.")
        }
    }

    /// Three exercise pickers, previously always visible the moment a
    /// powerlifter's discipline was set — now the same one-tap-away pattern
    /// as everything else that isn't the first thing someone opens this
    /// screen to change.
    private func competitionLiftsLinkSection(_ profile: TrainingProfile) -> some View {
        Section {
            NavigationLink {
                TrainingProfileCompetitionLiftsView(profile: profile)
            } label: {
                LabeledContent("Competition lifts", value: competitionLiftsSummary(profile))
            }
            .accessibilityIdentifier("training-profile-competition-lifts-link")
        } footer: {
            Text("Choose the exact exercise identities used for Estimated SBD. Trame never guesses these roles from exercise names.")
        }
    }

    private func competitionLiftsSummary(_ profile: TrainingProfile) -> String {
        let setCount = [
            profile.competition?.squatExerciseID,
            profile.competition?.benchExerciseID,
            profile.competition?.deadliftExerciseID
        ].compactMap { $0 }.count
        guard setCount > 0 else { return String(localized: "Not set") }
        return String(localized: "\(setCount) of 3 set")
    }

    private func scheduleLinkSection(_ profile: TrainingProfile) -> some View {
        Section {
            NavigationLink {
                TrainingProfileScheduleView(profile: profile)
            } label: {
                LabeledContent("Schedule", value: scheduleSummary(profile))
            }
            .accessibilityIdentifier("training-profile-schedule-link")
        } footer: {
            Text("A preference for ranking, not a commitment. Sessions you have already scheduled keep their dates.")
        }
    }

    private func scheduleSummary(_ profile: TrainingProfile) -> String {
        var parts: [String] = []
        if let days = profile.preferredDaysPerWeek { parts.append(CountPhrase.daysPerWeekAbbreviated(days)) }
        if let flexibility = profile.scheduleFlexibility { parts.append(flexibility.title) }
        if let duration = profile.sessionDuration { parts.append(duration.summaryTitle) }
        return parts.isEmpty ? String(localized: "Not set") : parts.joined(separator: " · ")
    }

    private func equipmentSection(_ profile: TrainingProfile) -> some View {
        Section {
            optionalPicker(
                label: String(localized: "Usual location"),
                identifier: "training-profile-location",
                selection: rawBinding(profile, \.trainingLocationRaw, onChange: { touch(profile) }),
                options: TrainingLocationPreference.allCases,
                titleKeyPath: \.title
            )

            NavigationLink {
                TrainingProfileEquipmentView(profile: profile)
            } label: {
                LabeledContent("Equipment", value: equipmentSummary(profile))
            }
            .accessibilityIdentifier("training-profile-equipment")

            // Shown only when the chosen discipline has specialised kit worth
            // asking about, which is the same condition onboarding used before
            // the question moved here. Nothing in the ranking reads it — it
            // describes what the lifter can do, for exercise suggestions — so
            // it has no business gating a first recommendation.
            if let group = profile.primaryDiscipline?.specializedEquipmentGroup {
                NavigationLink {
                    TrainingProfileSpecializedEquipmentView(profile: profile, group: group)
                } label: {
                    LabeledContent("Specialised equipment", value: specializedEquipmentSummary(profile))
                }
                .accessibilityIdentifier("training-profile-specialized-equipment")
            }
        } header: {
            Text("Equipment")
        }
    }

    @ViewBuilder
    private func emphasisSection(_ profile: TrainingProfile) -> some View {
        Section {
            ForEach(FocusArea.allCases, id: \.self) { area in
                Button {
                    toggleFocusArea(area, on: profile)
                } label: {
                    HStack {
                        Text(area.title)
                            .foregroundStyle(Color.gymText)
                        Spacer()
                        if profile.focusAreaIDs.contains(area.rawValue) {
                            Image(systemName: AppIcon.checkmark)
                                .foregroundStyle(Color.trameAction)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("training-profile-focus-\(area.rawValue)")
                .accessibilityAddTraits(profile.focusAreaIDs.contains(area.rawValue) ? .isSelected : [])
            }
        } header: {
            Text("Emphasis")
        } footer: {
            Text("Up to two. Emphasis ranks plans and suggests accessories — it never adds sets to a plan you are following.")
        }
    }

    private func mobilitySection(_ profile: TrainingProfile) -> some View {
        Section {
            optionalPicker(
                label: String(localized: "Mobility goal"),
                identifier: "training-profile-mobility-goal",
                selection: rawBinding(profile, \.mobilityGoalRaw, onChange: { touch(profile) }),
                options: MobilityGoalPreference.allCases,
                titleKeyPath: \.title
            )

            optionalPicker(
                label: String(localized: "Mobility experience"),
                identifier: "training-profile-mobility-experience",
                selection: rawBinding(profile, \.mobilityExperienceRaw, onChange: { touch(profile) }),
                options: MobilityExperiencePreference.allCases,
                titleKeyPath: \.title
            )

            optionalPicker(
                label: String(localized: "Mobility frequency"),
                identifier: "training-profile-mobility-frequency",
                selection: rawBinding(profile, \.mobilityFrequencyRaw, onChange: { touch(profile) }),
                options: MobilityFrequencyPreference.allCases,
                titleKeyPath: \.title
            )
        } header: {
            Text("Mobility")
        } footer: {
            Text("Ranks mobility plans separately from your training plan. You can want either, both, or neither.")
        }
    }

    // MARK: Controls

    private func toggleFocusArea(_ area: FocusArea, on profile: TrainingProfile) {
        var selection = profile.focusAreaIDs
        if let index = selection.firstIndex(of: area.rawValue) {
            selection.remove(at: index)
        } else if area == .balanced {
            selection = [area.rawValue]
        } else {
            selection.removeAll { $0 == FocusArea.balanced.rawValue }
            if selection.count >= FocusArea.maximumSelections {
                selection.removeFirst()
            }
            selection.append(area.rawValue)
        }
        profile.focusAreaIDs = selection
        touch(profile)
    }

    // MARK: Summaries

    private func equipmentSummary(_ profile: TrainingProfile) -> String {
        let count = profile.equipmentCapabilityIDs.count
        guard count > 0 else { return String(localized: "Not set") }
        return CountPhrase.items(count)
    }

    private func specializedEquipmentSummary(_ profile: TrainingProfile) -> String {
        let count = profile.specializedEquipmentCapabilityIDs.count
        guard count > 0 else { return String(localized: "Not set") }
        return CountPhrase.items(count)
    }

    private func touch(_ profile: TrainingProfile) {
        profile.updatedAt = .now
        save()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }
}

/// A picker whose first row is "Not set".
///
/// Every preference has to be un-answerable. A settings screen that can only
/// move between answers turns a question the lifter skipped on purpose into
/// one they are now forced to answer.
///
/// Free-standing rather than a method on one view: every training-profile
/// screen in this file — the main one and every sub-screen below — asks a
/// version of this same question, using this exact control every time.
private func optionalPicker<Option: RawRepresentable & Hashable>(
    label: String,
    identifier: String,
    selection: Binding<String?>,
    options: [Option],
    titleKeyPath: KeyPath<Option, String>
) -> some View where Option.RawValue == String {
    Picker(label, selection: selection) {
        Text("Not set").tag(String?.none)
        ForEach(options, id: \.self) { option in
            Text(option[keyPath: titleKeyPath]).tag(String?.some(option.rawValue))
        }
    }
    .pickerStyle(.menu)
    .accessibilityIdentifier(identifier)
}

/// `onChange` rather than a shared `touch(profile:)` because persistence is
/// each screen's own responsibility here — every sub-screen below already
/// owns its own `modelContext` and its own save/rollback, matching
/// `TrainingProfileEquipmentView`'s established pattern rather than routing
/// every edit back through the main view.
private func rawBinding(
    _ profile: TrainingProfile,
    _ keyPath: ReferenceWritableKeyPath<TrainingProfile, String?>,
    onChange: @escaping () -> Void
) -> Binding<String?> {
    Binding(
        get: { profile[keyPath: keyPath] },
        set: { newValue in
            profile[keyPath: keyPath] = newValue
            onChange()
        }
    )
}

/// Discipline, Goal, Experience, and secondary disciplines — one identity,
/// asked in one place. These four questions used to render as three always-
/// open pickers immediately followed by a fourth section (a toggle list for
/// "what else do you train"), which was most of what made the main screen
/// read as a wall of menus before a single answer was even in view.
struct TrainingProfileIdentityView: View {
    @Bindable var profile: TrainingProfile

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Form {
            Section {
                optionalPicker(
                    label: String(localized: "Discipline"),
                    identifier: "training-profile-discipline",
                    selection: rawBinding(profile, \.primaryDisciplineRaw, onChange: touch),
                    options: TrainingDisciplinePreference.allCases,
                    titleKeyPath: \.title
                )
                optionalPicker(
                    label: String(localized: "Goal"),
                    identifier: "training-profile-goal",
                    selection: rawBinding(profile, \.primaryGoalRaw, onChange: touch),
                    options: TrainingGoalPreference.allCases,
                    titleKeyPath: \.title
                )
                optionalPicker(
                    label: String(localized: "Experience"),
                    identifier: "training-profile-experience",
                    selection: rawBinding(profile, \.experienceLevelRaw, onChange: touch),
                    options: ProfileExperienceLevel.allCases,
                    titleKeyPath: \.title
                )
            }

            if secondaryDisciplineOptions.isEmpty == false {
                Section {
                    ForEach(secondaryDisciplineOptions, id: \.self) { discipline in
                        Button {
                            toggleSecondaryDiscipline(discipline)
                        } label: {
                            HStack {
                                Text(discipline.title)
                                    .foregroundStyle(Color.gymText)
                                Spacer()
                                if profile.secondaryDisciplines.contains(discipline) {
                                    Image(systemName: AppIcon.checkmark)
                                        .foregroundStyle(Color.trameAction)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("training-profile-secondary-\(discipline.rawValue)")
                        .accessibilityAddTraits(profile.secondaryDisciplines.contains(discipline) ? .isSelected : [])
                    }
                } header: {
                    Text("Other training")
                } footer: {
                    Text("Add other sports you train. Progress uses them as context without replacing your primary sport.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("training-profile-identity")
    }

    private var secondaryDisciplineOptions: [TrainingDisciplinePreference] {
        TrainingDisciplinePreference.allCases.filter { discipline in
            discipline != profile.primaryDiscipline
                && discipline != .mixed
                && discipline != .unspecified
        }
    }

    private func toggleSecondaryDiscipline(_ discipline: TrainingDisciplinePreference) {
        var selection = profile.secondaryDisciplines
        if let index = selection.firstIndex(of: discipline) {
            selection.remove(at: index)
        } else {
            selection.append(discipline)
        }
        profile.secondaryDisciplines = selection
        touch()
    }

    private func touch() {
        profile.updatedAt = .now
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }
}

/// The three competition-lift identities behind Estimated SBD — its own
/// screen because it is a specialised, powerlifting-only question, reachable
/// only once a powerlifting discipline is already in play.
struct TrainingProfileCompetitionLiftsView: View {
    @Bindable var profile: TrainingProfile

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }, sort: \Exercise.name)
    private var availableExercises: [Exercise]

    var body: some View {
        Form {
            Section {
                exercisePicker(
                    label: String(localized: "Competition squat"),
                    identifier: "training-profile-powerlifting-squat",
                    selection: exerciseBinding(\.squatExerciseID)
                )
                exercisePicker(
                    label: String(localized: "Competition bench"),
                    identifier: "training-profile-powerlifting-bench",
                    selection: exerciseBinding(\.benchExerciseID)
                )
                exercisePicker(
                    label: String(localized: "Competition deadlift"),
                    identifier: "training-profile-powerlifting-deadlift",
                    selection: exerciseBinding(\.deadliftExerciseID)
                )
            } footer: {
                Text("Choose the exact exercise identities used for Estimated SBD. Trame never guesses these roles from exercise names, and this does not create a competition total.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
        .navigationTitle("Competition lifts")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("training-profile-competition-lifts")
    }

    private func exercisePicker(label: String, identifier: String, selection: Binding<UUID?>) -> some View {
        Picker(label, selection: selection) {
            Text("Not set").tag(UUID?.none)
            ForEach(availableExercises) { exercise in
                Text(exercise.name).tag(Optional(exercise.id))
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private func exerciseBinding(_ keyPath: WritableKeyPath<CompetitionProfileDraft, UUID?>) -> Binding<UUID?> {
        Binding(
            get: { profile.competition?[keyPath: keyPath] },
            set: { newValue in
                var competition = profile.competition ?? CompetitionProfileDraft()
                competition[keyPath: keyPath] = newValue
                profile.competitionProfileData = competition.isEmpty ? nil : try? JSONEncoder().encode(competition)
                profile.updatedAt = .now
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                }
            }
        )
    }
}

/// Days per week, week shape, session length, and usual training days — every
/// question about *when* training happens, in one place, with the existing
/// weekdays screen nested one level deeper since it is its own multi-select
/// rather than a single answer.
struct TrainingProfileScheduleView: View {
    @Bindable var profile: TrainingProfile

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Form {
            Section {
                Stepper(
                    value: Binding(
                        get: { profile.preferredDaysPerWeek ?? 0 },
                        set: { newValue in
                            // Zero is how "not answered" is expressed, so the
                            // stepper can return to unset rather than
                            // trapping the lifter into having named a number.
                            profile.preferredDaysPerWeek = newValue == 0 ? nil : newValue
                            touch()
                        }
                    ),
                    in: 0...7
                ) {
                    LabeledContent("Days per week", value: daysPerWeekText)
                }
                .accessibilityIdentifier("training-profile-days")

                optionalPicker(
                    label: String(localized: "Week shape"),
                    identifier: "training-profile-flexibility",
                    selection: rawBinding(profile, \.scheduleFlexibilityRaw, onChange: touch),
                    options: ScheduleFlexibility.allCases,
                    titleKeyPath: \.title
                )

                optionalPicker(
                    label: String(localized: "Session length"),
                    identifier: "training-profile-duration",
                    selection: rawBinding(profile, \.sessionDurationRaw, onChange: touch),
                    options: SessionDurationPreference.allCases,
                    titleKeyPath: \.summaryTitle
                )

                // Onboarding no longer asks which weekdays work — it never
                // reached the ranking, so it was a screen charged to every
                // lifter before they had a plan for those days to belong to.
                // It lives here instead, where it can be set once there is
                // something to schedule.
                NavigationLink {
                    TrainingProfileWeekdaysView(profile: profile)
                } label: {
                    LabeledContent("Usual training days", value: weekdaySummary)
                }
                .accessibilityIdentifier("training-profile-weekdays")
            } footer: {
                Text("A preference for ranking, not a commitment. Sessions you have already scheduled keep their dates.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("training-profile-schedule")
    }

    private var daysPerWeekText: String {
        guard let days = profile.preferredDaysPerWeek else { return String(localized: "Not set") }
        return CountPhrase.days(days)
    }

    private var weekdaySummary: String {
        let days = profile.preferredWeekdays.sorted()
        guard !days.isEmpty else { return String(localized: "Not set") }
        let symbols = Calendar.current.shortWeekdaySymbols
        return days
            .compactMap { symbols.indices.contains($0 - 1) ? symbols[$0 - 1] : nil }
            .formatted(.list(type: .and, width: .narrow))
    }

    private func touch() {
        profile.updatedAt = .now
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }
}

/// The equipment checklist, reusing the onboarding tiles so the same question
/// looks the same wherever it is asked.
struct TrainingProfileEquipmentView: View {
    @Bindable var profile: TrainingProfile

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            OnboardingTileGrid {
                ForEach(EquipmentType.onboardingOrder, id: \.self) { equipment in
                    OnboardingMultiChoiceTile(
                        title: equipment.onboardingTitle,
                        icon: equipment.onboardingIcon,
                        isSelected: profile.equipmentCapabilityIDs.contains(equipment.rawValue)
                    ) {
                        toggle(equipment)
                    }
                    .accessibilityIdentifier("training-profile-equipment-\(equipment.identifierSlug)")
                }
            }
            .padding(Spacing.l)
        }
        .background(Color.trameCanvas)
        .navigationTitle("Equipment")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("training-profile-equipment-list")
    }

    private func toggle(_ equipment: EquipmentType) {
        var selection = profile.equipmentCapabilityIDs
        if let index = selection.firstIndex(of: equipment.rawValue) {
            selection.remove(at: index)
        } else {
            selection.append(equipment.rawValue)
        }
        profile.equipmentCapabilityIDs = selection.sorted()
        profile.updatedAt = .now
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }
}

/// The weekdays that usually work, reusing onboarding's chips.
///
/// Nothing here reaches a scheduled session. A plan already running keeps every
/// date it has already placed — this is a statement about a normal week, which
/// is why it can live in settings without a warning attached.
struct TrainingProfileWeekdaysView: View {
    @Bindable var profile: TrainingProfile

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                // Wraps rather than fitting one row, for the same reason the
                // onboarding version does: seven chips at an accessibility text
                // size either clip or drop below the minimum touch target.
                ChipFlowLayout(spacing: Spacing.xs) {
                    ForEach(orderedWeekdays, id: \.self) { weekday in
                        OnboardingChip(
                            title: shortSymbol(weekday),
                            accessibilityTitle: symbol(weekday),
                            isSelected: profile.preferredWeekdays.contains(weekday)
                        ) {
                            toggle(weekday)
                        }
                        .accessibilityIdentifier("training-profile-weekday-\(weekday)")
                    }
                }

                Text("Used to rank plans that expect a regular week. Sessions you have already scheduled keep their dates.")
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.trameCanvas)
        .navigationTitle("Usual training days")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("training-profile-weekday-list")
    }

    /// Starts at the locale's first weekday, so the row reads the way the
    /// lifter's own calendar does.
    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    private func shortSymbol(_ weekday: Int) -> String {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : "\(weekday)"
    }

    private func symbol(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : "\(weekday)"
    }

    private func toggle(_ weekday: Int) {
        var selection = profile.preferredWeekdays
        if let index = selection.firstIndex(of: weekday) {
            selection.remove(at: index)
        } else {
            selection.append(weekday)
        }
        profile.preferredWeekdays = selection.sorted()
        profile.updatedAt = .now
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }
}

/// The specialised kit a discipline cares about — a competition bench, a log,
/// bumper plates. Reached only when the chosen discipline declares a group.
struct TrainingProfileSpecializedEquipmentView: View {
    @Bindable var profile: TrainingProfile
    let group: SpecializedEquipmentGroup

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Text(group.question)
                    .font(AppFont.headlineSemibold)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                OnboardingTileGrid {
                    ForEach(group.capabilities) { capability in
                        OnboardingMultiChoiceTile(
                            title: capability.title,
                            isSelected: profile.specializedEquipmentCapabilityIDs.contains(capability.id)
                        ) {
                            toggle(capability.id)
                        }
                        .accessibilityIdentifier("training-profile-specialized-\(capability.id)")
                    }
                }

                Text("Suggests exercises you can actually perform. It never changes a plan you are following.")
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.trameCanvas)
        .navigationTitle("Specialised equipment")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("training-profile-specialized-list")
    }

    private func toggle(_ id: String) {
        var selection = profile.specializedEquipmentCapabilityIDs
        if let index = selection.firstIndex(of: id) {
            selection.remove(at: index)
        } else {
            selection.append(id)
        }
        profile.specializedEquipmentCapabilityIDs = selection.sorted()
        profile.updatedAt = .now
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }
}
