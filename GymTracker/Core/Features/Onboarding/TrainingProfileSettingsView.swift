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
