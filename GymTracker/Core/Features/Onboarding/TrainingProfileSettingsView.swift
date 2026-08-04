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
                trainingSection(profile)
                scheduleSection(profile)
                equipmentSection(profile)
                emphasisSection(profile)
                if isMobilityMatchingEnabled {
                    mobilitySection(profile)
                }
            }
        }
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

    private func trainingSection(_ profile: TrainingProfile) -> some View {
        Section("Training") {
            optionalPicker(
                label: String(localized: "Discipline"),
                identifier: "training-profile-discipline",
                selection: rawBinding(profile, \.primaryDisciplineRaw),
                options: TrainingDisciplinePreference.allCases,
                titleKeyPath: \.title
            )

            optionalPicker(
                label: String(localized: "Goal"),
                identifier: "training-profile-goal",
                selection: rawBinding(profile, \.primaryGoalRaw),
                options: TrainingGoalPreference.allCases,
                titleKeyPath: \.title
            )

            optionalPicker(
                label: String(localized: "Experience"),
                identifier: "training-profile-experience",
                selection: rawBinding(profile, \.experienceLevelRaw),
                options: ProfileExperienceLevel.allCases,
                titleKeyPath: \.title
            )
        }
    }

    private func scheduleSection(_ profile: TrainingProfile) -> some View {
        Section {
            Stepper(
                value: Binding(
                    get: { profile.preferredDaysPerWeek ?? 0 },
                    set: { newValue in
                        // Zero is how "not answered" is expressed, so the
                        // stepper can return to unset rather than trapping the
                        // lifter into having named a number.
                        profile.preferredDaysPerWeek = newValue == 0 ? nil : newValue
                        touch(profile)
                    }
                ),
                in: 0...7
            ) {
                LabeledContent("Days per week", value: daysPerWeekText(profile))
            }
            .accessibilityIdentifier("training-profile-days")

            optionalPicker(
                label: String(localized: "Week shape"),
                identifier: "training-profile-flexibility",
                selection: rawBinding(profile, \.scheduleFlexibilityRaw),
                options: ScheduleFlexibility.allCases,
                titleKeyPath: \.title
            )

            optionalPicker(
                label: String(localized: "Session length"),
                identifier: "training-profile-duration",
                selection: rawBinding(profile, \.sessionDurationRaw),
                options: SessionDurationPreference.allCases,
                titleKeyPath: \.summaryTitle
            )

            // Onboarding no longer asks which weekdays work — it never reached
            // the ranking, so it was a screen charged to every lifter before
            // they had a plan for those days to belong to. It lives here
            // instead, where it can be set once there is something to schedule.
            NavigationLink {
                TrainingProfileWeekdaysView(profile: profile)
            } label: {
                LabeledContent("Usual training days", value: weekdaySummary(profile))
            }
            .accessibilityIdentifier("training-profile-weekdays")
        } header: {
            Text("Schedule")
        } footer: {
            Text("A preference for ranking, not a commitment. Sessions you have already scheduled keep their dates.")
        }
    }

    private func equipmentSection(_ profile: TrainingProfile) -> some View {
        Section {
            optionalPicker(
                label: String(localized: "Usual location"),
                identifier: "training-profile-location",
                selection: rawBinding(profile, \.trainingLocationRaw),
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
                                .foregroundStyle(Color.gymPrimary)
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
                selection: rawBinding(profile, \.mobilityGoalRaw),
                options: MobilityGoalPreference.allCases,
                titleKeyPath: \.title
            )

            optionalPicker(
                label: String(localized: "Mobility experience"),
                identifier: "training-profile-mobility-experience",
                selection: rawBinding(profile, \.mobilityExperienceRaw),
                options: MobilityExperiencePreference.allCases,
                titleKeyPath: \.title
            )

            optionalPicker(
                label: String(localized: "Mobility frequency"),
                identifier: "training-profile-mobility-frequency",
                selection: rawBinding(profile, \.mobilityFrequencyRaw),
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

    /// A picker whose first row is "Not set".
    ///
    /// Every preference has to be un-answerable. A settings screen that can
    /// only move between answers turns a question the lifter skipped on purpose
    /// into one they are now forced to answer.
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

    private func rawBinding(
        _ profile: TrainingProfile,
        _ keyPath: ReferenceWritableKeyPath<TrainingProfile, String?>
    ) -> Binding<String?> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { newValue in
                profile[keyPath: keyPath] = newValue
                touch(profile)
            }
        )
    }

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

    private func daysPerWeekText(_ profile: TrainingProfile) -> String {
        guard let days = profile.preferredDaysPerWeek else { return String(localized: "Not set") }
        return CountPhrase.days(days)
    }

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

    private func weekdaySummary(_ profile: TrainingProfile) -> String {
        let days = profile.preferredWeekdays.sorted()
        guard !days.isEmpty else { return String(localized: "Not set") }
        let symbols = Calendar.current.shortWeekdaySymbols
        return days
            .compactMap { symbols.indices.contains($0 - 1) ? symbols[$0 - 1] : nil }
            .formatted(.list(type: .and, width: .narrow))
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
        .background(Color.gymBackground)
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
        .background(Color.gymBackground)
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
        .background(Color.gymBackground)
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
