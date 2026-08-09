//
//  SettingView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import AppIntents
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

/// A hub, not a wall.
///
/// Every preference used to live on one scroll — twelve sections deep, so the
/// two settings people actually change (appearance, units) sat above a queue of
/// things most lifters touch once and never again. The screen answered "what
/// can this app do?" when the user was asking "where is the thing I came for?".
///
/// So the root now carries only what is either changed often or must never be
/// missed, and everything else is one tap away behind a named destination. The
/// rows that lead somewhere show their current value, which is what makes the
/// grouping honest: collapsing a section is only acceptable if the user can
/// still tell, from the outside, what is inside it.
struct SettingView: View {
    var currentScreen: AppScreen = .settings
    let activeLoggingMetrics: ActiveLoggingMetricsRecorder
    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current
    @State private var isShowingBetaFeedback = false
    @AppStorage(DefaultsKey.appearance) private var appearance: AppAppearance = .system
    @AppStorage(DefaultsKey.darkMode) private var legacyDarkMode: Bool = false
    @AppStorage(DefaultsKey.useMetric) private var unitSystem: UnitSystem = .metric
    /// Zero means automatic: rest is derived from the exercise. A positive
    /// value is an explicit override that applies everywhere.
    @AppStorage(DefaultsKey.restTimer) private var restTimer: Int = 0
    @AppStorage(DefaultsKey.planRemindersEnabled) private var planRemindersEnabled: Bool = false
    @AppStorage(DefaultsKey.checkInRemindersEnabled) private var checkInRemindersEnabled: Bool = false
    @AppStorage(DefaultsKey.lastBackupExportTimestamp) private var lastBackupExportTimestamp: Double?
    @Query(sort: \BodyWeightEntry.measuredAt, order: .reverse) private var bodyWeightEntries: [BodyWeightEntry]

    var body: some View {
        Form {
            Section("General") {
                Picker("Appearance", selection: appearanceBinding) {
                    ForEach(AppAppearance.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings-appearance-picker")
                .accessibilityValue(selectedAppearance.title)

                Picker("Units", selection: $unitSystem) {
                    ForEach(UnitSystem.allCases, id: \.self) { system in
                        Text(system == .metric ? String(localized: "Metric") : String(localized: "Imperial"))
                            .tag(system)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings-units-picker")
                .accessibilityValue(unitSystem == .metric ? String(localized: "Metric") : String(localized: "Imperial"))

                SettingsLinkRow(
                    title: "Personal details",
                    systemImage: AppIcon.bodyWeight,
                    detail: latestBodyWeightText
                ) {
                    PersonalDetailsSettingsView()
                }
                .accessibilityIdentifier("settings-personal-details")
            }

            Section {
                SettingsLinkRow(title: "Training profile", systemImage: AppIcon.muscles) {
                    TrainingProfileSettingsView()
                }
                .accessibilityIdentifier("settings-training-profile")

                SettingsLinkRow(
                    title: "Workout & rest",
                    systemImage: AppIcon.timer,
                    detail: restSummary
                ) {
                    WorkoutSettingsView()
                }
                .accessibilityIdentifier("settings-workout")

                SettingsLinkRow(
                    title: "Reminders",
                    systemImage: AppIcon.reminders,
                    detail: remindersSummary
                ) {
                    RemindersSettingsView()
                }
                .accessibilityIdentifier("settings-reminders")
            } header: {
                Text("Training")
            } footer: {
                Text("Your profile ranks plans and suggests exercises. It never changes a plan you are already following.")
            }

            Section {
                SettingsLinkRow(
                    title: "Data & backup",
                    systemImage: AppIcon.backup,
                    detail: backupSummary,
                    detailTint: lastBackupExportTimestamp == nil ? Color.gymAccent : Color.gymSubduedText
                ) {
                    DataSettingsView()
                }
                .accessibilityIdentifier("settings-data")
            } header: {
                Text("Data")
            } footer: {
                Text("Your training history is saved on this iPhone and works offline. Use Data & backup to protect or move it to a new device.")
            }

            Section {
                SettingsLinkRow(title: "Advanced", systemImage: AppIcon.advanced) {
                    AdvancedSettingsView()
                }
                .accessibilityIdentifier("settings-advanced")

                if featureFlags.isEnabled(.betaFeedback) {
                    Button {
                        isShowingBetaFeedback = true
                    } label: {
                        Label("Send Beta Feedback", systemImage: AppIcon.feedback)
                    }
                    .accessibilityIdentifier("settings-beta-feedback")
                }
            } footer: {
                if featureFlags.isEnabled(.betaFeedback) {
                    Text("Share what's working or broken. Technical details like app version and enabled features are attached by default; your workouts, meals, and health data are never included.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Settings")
        .sheet(isPresented: $isShowingBetaFeedback) {
            BetaFeedbackScreen(
                context: BetaFeedbackContextProvider.makeContext(
                    screen: currentScreen,
                    activeLoggingMetrics: activeLoggingMetrics.snapshot
                )
            )
        }
        .accessibilityIdentifier("settings-screen")
    }

    private var latestBodyWeightText: String {
        guard let latest = bodyWeightEntries.first else { return String(localized: "Not recorded") }
        return "\(Formatters.formatFloat(latest.value)) \(latest.unit.rawValue)"
    }

    private var restSummary: String {
        restTimer > 0 ? RestTimerFormat.duration(restTimer) : String(localized: "Automatic")
    }

    /// One word for two toggles. "Partly" is not a state the user set, so the
    /// summary reports whether anything will fire at all and leaves the detail
    /// to the screen that owns it.
    private var remindersSummary: String {
        planRemindersEnabled || checkInRemindersEnabled
            ? String(localized: "On")
            : String(localized: "Off")
    }

    /// The one status worth surfacing before the user opens the group: a
    /// device-only app with no export is one lost phone away from losing
    /// everything, and that fact should not require a tap to discover.
    private var backupSummary: String {
        guard let lastBackupExportTimestamp else { return String(localized: "Never exported") }
        return Date(timeIntervalSince1970: lastBackupExportTimestamp)
            .formatted(.dateTime.year().month(.abbreviated).day())
    }

    private var selectedAppearance: AppAppearance {
        guard UserDefaults.standard.object(forKey: DefaultsKey.appearance) != nil else {
            return legacyDarkMode ? .dark : .system
        }
        return appearance
    }

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { selectedAppearance },
            set: { newValue in
                appearance = newValue
                // Backup v24 stores the former Boolean preference. Keep it
                // synchronized until the backup format can add all three
                // appearance states without breaking older imports.
                legacyDarkMode = newValue == .dark
            }
        )
    }
}

// MARK: - Hub row

/// A destination row that states what is behind it.
///
/// The trailing value is the whole argument for grouping: a row reading
/// "Workout & rest — Automatic" costs the same glance as the inline toggle it
/// replaced, while a bare disclosure would have hidden the answer and charged
/// a tap to get it back.
private struct SettingsLinkRow<Destination: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    var detail: String?
    var detailTint: Color = .gymSubduedText
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            LabeledContent {
                if let detail {
                    Text(detail).foregroundStyle(detailTint)
                }
            } label: {
                Label(title, systemImage: systemImage)
            }
        }
    }
}

// MARK: - Personal details

private struct PersonalDetailsSettingsView: View {
    @AppStorage(DefaultsKey.bodyWeightPromptCadence) private var bodyWeightPromptCadence: BodyWeightPromptCadence = .off
    @AppStorage(DefaultsKey.caffeineBirthdateTimestamp) private var caffeineBirthdateTimestamp: Double?
    @Query(sort: \BodyWeightEntry.measuredAt, order: .reverse) private var bodyWeightEntries: [BodyWeightEntry]

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    BodyWeightHistoryView()
                } label: {
                    LabeledContent("Current weight", value: latestBodyWeightText)
                }
                .accessibilityIdentifier("settings-body-weight")

                Picker("Ask in check-in", selection: $bodyWeightPromptCadence) {
                    Text("Off").tag(BodyWeightPromptCadence.off)
                    Text("Weekly").tag(BodyWeightPromptCadence.weekly)
                    Text("Monthly").tag(BodyWeightPromptCadence.monthly)
                }
            } header: {
                Text("Body Weight")
            } footer: {
                Text("Optional measurements stay private and never change workouts or nutrition targets automatically.")
            }

            Section {
                Toggle("Use birthdate", isOn: Binding(
                    get: { caffeineBirthdateTimestamp != nil },
                    set: { enabled in
                        caffeineBirthdateTimestamp = enabled
                            ? (caffeineBirthdateTimestamp ?? Calendar.current.date(byAdding: .year, value: -25, to: .now)?.timeIntervalSince1970)
                            : nil
                    }
                ))
                .accessibilityIdentifier("settings-caffeine-birthdate-toggle")

                if let caffeineBirthdateTimestamp {
                    DatePicker("Birthdate", selection: Binding(
                        get: { Date(timeIntervalSince1970: caffeineBirthdateTimestamp) },
                        set: { self.caffeineBirthdateTimestamp = $0.timeIntervalSince1970 }
                    ), displayedComponents: .date)
                    .accessibilityIdentifier("settings-caffeine-birthdate-picker")
                }
            } header: {
                Text("Caffeine Reference")
            } footer: {
                Text("Used only to personalize the daily caffeine reference amount shown in Nutrition. Never required, and never shared.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Personal details")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings-personal-details-screen")
    }

    private var latestBodyWeightText: String {
        guard let latest = bodyWeightEntries.first else { return String(localized: "Not recorded") }
        return "\(Formatters.formatFloat(latest.value)) \(latest.unit.rawValue)"
    }
}

// MARK: - Workout & rest

/// Rest and effort on one screen.
///
/// Both answer "how is a set recorded", and they were previously separated by
/// four unrelated sections plus a second push. Merging them removes a level of
/// navigation rather than adding one.
private struct WorkoutSettingsView: View {
    @AppStorage(DefaultsKey.restTimer) private var restTimer: Int = 0
    @AppStorage(DefaultsKey.effortMeasure) private var effortMeasure: EffortMeasure = .rir

    var body: some View {
        Form {
            Section {
                Toggle("Automatic", isOn: isAutomaticRestBinding)
                    .accessibilityIdentifier("settings-rest-automatic")
                    .accessibilityHint("Chooses rest length from the exercise instead of using one duration everywhere.")

                if restTimer > 0 {
                    Stepper(value: $restTimer, in: 10...300, step: 5) {
                        LabeledContent("Duration", value: RestTimerFormat.duration(restTimer))
                    }
                    .accessibilityIdentifier("settings-rest-duration")
                }
            } header: {
                Text("Rest Timer")
            } footer: {
                Text(restTimerFooter)
            }

            Section {
                Picker("Effort measure", selection: $effortMeasure) {
                    ForEach(EffortMeasure.allCases, id: \.self) { measure in
                        Text(measure.title).tag(measure)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings-effort-measure")
            } header: {
                Text("Effort")
            } footer: {
                Text("Record either RIR or RPE for each performed set. Changing this preference never changes existing workout history.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Workout & rest")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings-workout-screen")
    }

    private var isAutomaticRestBinding: Binding<Bool> {
        Binding(
            get: { restTimer == 0 },
            // 90 is the general-purpose middle of the derived tiers, so turning
            // automatic off lands somewhere sensible rather than at a bound.
            set: { restTimer = $0 ? 0 : 90 }
        )
    }

    private var restTimerFooter: String {
        restTimer > 0
            ? String(localized: "Every exercise rests for this long unless its plan says otherwise.")
            : String(localized: "Rest length is chosen from the exercise — longest for heavy compound lifts, shortest for core work. A plan's own rest always takes priority.")
    }
}

enum RestTimerFormat {
    static func duration(_ seconds: Int) -> String {
        if seconds < 60 {
            return String(localized: "\(seconds) sec")
        }

        let minutes = seconds / 60
        let remainder = seconds % 60

        if remainder == 0 {
            return String(localized: "\(minutes) min")
        }

        return String(localized: "\(minutes) min \(remainder) sec")
    }
}

// MARK: - Reminders

/// Both notification preferences in one place, with a single permission notice.
///
/// The denied-authorization row appeared twice on the old screen, once per
/// toggle, which read as two separate problems when it is one system setting.
private struct RemindersSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var reminderAuthorization: UNAuthorizationStatus = .notDetermined
    @State private var reminderErrorMessage: String?
    @State private var remindersEnabled = UserDefaults.standard.bool(forKey: DefaultsKey.planRemindersEnabled)
    @State private var checkInRemindersEnabled = UserDefaults.standard.bool(forKey: DefaultsKey.checkInRemindersEnabled)
    @State private var reminderTime = Calendar.current.date(
        bySettingHour: UserDefaults.standard.object(forKey: DefaultsKey.planReminderHour) == nil
            ? 9
            : UserDefaults.standard.integer(forKey: DefaultsKey.planReminderHour),
        minute: UserDefaults.standard.integer(forKey: DefaultsKey.planReminderMinute),
        second: 0,
        of: .now
    ) ?? .now
    @State private var checkInReminderTime = Calendar.current.date(
        bySettingHour: UserDefaults.standard.object(forKey: DefaultsKey.checkInReminderHour) == nil
            ? 20
            : UserDefaults.standard.integer(forKey: DefaultsKey.checkInReminderHour),
        minute: UserDefaults.standard.integer(forKey: DefaultsKey.checkInReminderMinute),
        second: 0,
        of: .now
    ) ?? .now

    var body: some View {
        Form {
            if reminderAuthorization == .denied {
                Section {
                    Label("Notifications are disabled in System Settings.", systemImage: AppIcon.warning)
                        .foregroundStyle(Color.gymSubduedText)
                    Button("Open System Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .accessibilityIdentifier("settings-open-system-settings")
                }
            }

            Section {
                Toggle("Scheduled workout reminders", isOn: Binding(
                    get: { remindersEnabled },
                    set: { enabled in
                        remindersEnabled = enabled
                        Task { await setPlanRemindersEnabled(enabled) }
                    }
                ))
                .accessibilityIdentifier("settings-workout-reminder")

                if remindersEnabled {
                    DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .onChange(of: reminderTime) { _, newValue in
                            PlanNotificationScheduler.shared.setReminderTime(newValue)
                        }
                }
            } header: {
                Text("Workout Reminders")
            } footer: {
                Text("Trame schedules reminders only for future workouts in your active plan.")
            }

            Section {
                Toggle("Daily check-in reminder", isOn: Binding(
                    get: { checkInRemindersEnabled },
                    set: { enabled in
                        checkInRemindersEnabled = enabled
                        Task { await setCheckInRemindersEnabled(enabled) }
                    }
                ))
                .accessibilityIdentifier("settings-check-in-reminder")

                if checkInRemindersEnabled {
                    DatePicker("Reminder time", selection: $checkInReminderTime, displayedComponents: .hourAndMinute)
                        .onChange(of: checkInReminderTime) { _, newValue in
                            CheckInNotificationScheduler.shared.setReminderTime(newValue)
                            Task { await CheckInNotificationScheduler.shared.reconcile(using: modelContext) }
                        }
                }
            } header: {
                Text("Daily check-in")
            } footer: {
                Text("One optional reminder is scheduled for the selected evening time. Saving or skipping today’s check-in removes it.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings-reminders-screen")
        .task {
            reminderAuthorization = await PlanNotificationScheduler.shared.authorizationStatus()
        }
        .alert("Reminder Error", isPresented: Binding(
            get: { reminderErrorMessage != nil },
            set: { if !$0 { reminderErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reminderErrorMessage ?? "Workout reminders could not be enabled.")
        }
    }

    @MainActor
    private func setPlanRemindersEnabled(_ enabled: Bool) async {
        if enabled {
            guard await PlanNotificationScheduler.shared.enable() else {
                remindersEnabled = false
                reminderAuthorization = await PlanNotificationScheduler.shared.authorizationStatus()
                reminderErrorMessage = reminderAuthorization == .denied
                    ? "Allow notifications in System Settings to receive workout reminders."
                    : "Workout reminders could not be enabled."
                return
            }
            reminderAuthorization = await PlanNotificationScheduler.shared.authorizationStatus()
            await PlanNotificationScheduler.shared.reconcile(using: modelContext)
        } else {
            remindersEnabled = false
            PlanNotificationScheduler.shared.disable()
        }
    }

    @MainActor
    private func setCheckInRemindersEnabled(_ enabled: Bool) async {
        if enabled {
            guard await CheckInNotificationScheduler.shared.enable() else {
                checkInRemindersEnabled = false
                reminderAuthorization = await CheckInNotificationScheduler.shared.authorizationStatus()
                reminderErrorMessage = reminderAuthorization == .denied
                    ? "Allow notifications in System Settings to receive daily check-in reminders."
                    : "Daily check-in reminders could not be enabled."
                return
            }
            reminderAuthorization = await CheckInNotificationScheduler.shared.authorizationStatus()
            await CheckInNotificationScheduler.shared.reconcile(using: modelContext)
        } else {
            checkInRemindersEnabled = false
            CheckInNotificationScheduler.shared.disable()
        }
    }
}

// MARK: - Data & backup

/// What the user actually risks, stated plainly, plus the two actions that
/// change it.
///
/// "Local-first" only reassures someone who can see their own exposure: where
/// the data lives, whether a copy exists, how old it is, and whether restoring
/// one has ever been proven to work on this device. Without sync, that last
/// question is the difference between a promise and a guarantee — so it is
/// answered honestly, including when the answer is "not yet". Export and import
/// sit directly beneath the report they answer.
struct DataSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(DefaultsKey.appearance) private var appearance: AppAppearance = .system
    @AppStorage(DefaultsKey.darkMode) private var legacyDarkMode: Bool = false
    @AppStorage(DefaultsKey.restTimer) private var restTimer: Int = 0
    @AppStorage(DefaultsKey.useMetric) private var unitSystem: UnitSystem = .metric
    @AppStorage(DefaultsKey.bodyWeightPromptCadence) private var bodyWeightPromptCadence: BodyWeightPromptCadence = .off
    @AppStorage(DefaultsKey.caffeineBirthdateTimestamp) private var caffeineBirthdateTimestamp: Double?
    @AppStorage(DefaultsKey.lastBackupExportTimestamp) private var lastBackupExportTimestamp: Double?
    @AppStorage(DefaultsKey.lastBackupRestoreTimestamp) private var lastBackupRestoreTimestamp: Double?
    @State private var isShowingFileImporter = false
    @State private var exportURL: URL?
    @State private var isPreparingExport = false
    @State private var importBackup: BackupDTO? = nil
    @State private var importErrorMessage: String? = nil
    @State private var isShowingImportError = false
    @State private var didHandleUITestImport = false

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text(dataSafetyMetadata.storageLocationDescription)
                } label: {
                    Label("Stored", systemImage: AppIcon.lock)
                }
                .accessibilityIdentifier("settings-data-safety-storage")

                LabeledContent {
                    Text(dataSafetyMetadata.formattedLastExportDate())
                } label: {
                    Label("Last export", systemImage: AppIcon.export)
                }
                .accessibilityIdentifier("settings-data-safety-last-export")

                LabeledContent {
                    Text(dataSafetyMetadata.restoreTestedDescription())
                } label: {
                    Label("Restore tested", systemImage: AppIcon.restore)
                }
                .accessibilityIdentifier("settings-data-safety-restore-tested")

                LabeledContent {
                    Text(verbatim: dataSafetyMetadata.backupFormatVersion)
                } label: {
                    Label("Backup format", systemImage: AppIcon.import)
                }
                .accessibilityIdentifier("settings-data-safety-backup-format")
            } header: {
                Text("Data Safety")
            } footer: {
                Text("Your training history is saved on this iPhone and stays fully functional offline. Exporting a backup is currently the only way to move your history to another device.")
            }

            Section("Backup & Restore") {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share Export", systemImage: AppIcon.export)
                    }
                }

                Button {
                    prepareExport()
                } label: {
                    if isPreparingExport {
                        Label("Preparing export", systemImage: AppIcon.export)
                    } else {
                        Label("Export Data", systemImage: AppIcon.export)
                    }
                }
                .disabled(isPreparingExport)
                .accessibilityIdentifier("settings-export-data")

                Button {
                    isShowingFileImporter = true
                } label: {
                    Label("Import Data", systemImage: AppIcon.import)
                }
                .accessibilityIdentifier("settings-import-data")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Data & backup")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings-data-screen")
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                loadImportBackup(from: url)
            case .failure(let error):
                showImportError(error.localizedDescription)
            }
        }
        .sheet(isPresented: Binding(
            get: { importBackup != nil },
            set: { if !$0 { importBackup = nil } }
        )) {
            if let backup = importBackup {
                ImportPreviewView(backup: backup) {
                    restoreBackup(backup)
                }
            }
        }
        .alert("Import Error", isPresented: $isShowingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let importErrorMessage {
                Text(importErrorMessage)
            }
        }
        .onAppear {
            guard !didHandleUITestImport else { return }
            didHandleUITestImport = true

            if AppLaunchArguments.current.contains("-ui-testing-import-error") {
                showImportError("This file is not a valid Trame backup. Choose a backup exported from Trame.")
            } else if AppLaunchArguments.current.contains("-ui-testing-import-corrupt") {
                do {
                    _ = try BackupImportService.decodeAndValidate(Data("not-json".utf8))
                } catch {
                    showImportError("This backup could not be read. \(error.localizedDescription)")
                }
            } else if AppLaunchArguments.current.contains("-ui-testing-import-valid"),
                      let data = UITestFixture.UITestImportPayload.validData {
                do {
                    importBackup = try BackupImportService.decodeAndValidate(data)
                } catch {
                    showImportError("This backup could not be read. \(error.localizedDescription)")
                }
            }
        }
    }

    private var dataSafetyMetadata: DataSafetyMetadata {
        DataSafetyService.fetchMetadata()
    }

    private func relativeBackupDate(_ timestamp: Double?) -> String {
        guard let timestamp else { return String(localized: "Never") }
        return Date(timeIntervalSince1970: timestamp)
            .formatted(.dateTime.year().month(.abbreviated).day())
    }

    private func prepareExport() {
        guard isPreparingExport == false else { return }
        isPreparingExport = true
        Task {
            do {
                let result = try await DataSafetyService.exportData(
                    from: modelContext,
                    restTimer: restTimer,
                    darkMode: selectedAppearance == .dark,
                    unitSystem: unitSystem
                )
                exportURL = result.fileURL
                lastBackupExportTimestamp = result.exportDate.timeIntervalSince1970
            } catch {
                showImportError("The backup could not be exported. \(error.localizedDescription)")
            }
            isPreparingExport = false
        }
    }

    private func loadImportBackup(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            showImportError("Cannot access the selected file.")
            return
        }
        Task {
            do {
                let backup = try await Task.detached(priority: .utility) {
                    defer { url.stopAccessingSecurityScopedResource() }
                    let data = try Data(contentsOf: url)
                    return try BackupImportService.decodeAndValidate(data)
                }.value
                importBackup = backup
            } catch {
                showImportError("This backup could not be read. \(error.localizedDescription)")
            }
        }
    }

    private func showImportError(_ message: String) {
        importErrorMessage = message
        isShowingImportError = true
    }

    private func restoreBackup(_ backup: BackupDTO) {
        do {
            let preferences = try BackupImportService.restore(backup, to: modelContext)
            self.appearance = preferences.darkMode ? .dark : .system
            self.legacyDarkMode = preferences.darkMode
            self.restTimer = preferences.restTimer
            self.unitSystem = UnitSystem(rawValue: preferences.unitSystem) ?? .metric
            self.bodyWeightPromptCadence = preferences.bodyWeightPromptCadence.flatMap(BodyWeightPromptCadence.init(rawValue:)) ?? .off
            self.caffeineBirthdateTimestamp = preferences.birthdateTimestamp
            // Set after the restore transaction commits, so "restore tested" can
            // never claim a restore that rolled back. Written locally rather than
            // carried in the backup: it records that *this* installation has been
            // proven recoverable, which is the question the user is asking.
            lastBackupRestoreTimestamp = Date.now.timeIntervalSince1970
            NotificationCenter.default.post(name: .gymDataRestored, object: nil)
        } catch {
            showImportError("Failed to restore backup: \(error.localizedDescription)")
        }
    }

    private var selectedAppearance: AppAppearance {
        guard UserDefaults.standard.object(forKey: DefaultsKey.appearance) != nil else {
            return legacyDarkMode ? .dark : .system
        }
        return appearance
    }
}

// MARK: - Advanced

/// The things a lifter configures once, or never.
///
/// Shortcuts are powerful and rarely revisited; the development reset is not
/// shipped at all. Neither earns a place above the settings people change
/// weekly, and neither is hidden — the group is named for what it holds.
private struct AdvancedSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isShowingResetConfirmation = false

    var body: some View {
        Form {
            Section {
                ShortcutsLink()
                    .accessibilityIdentifier("settings-shortcuts-link")
            } header: {
                Text("Siri & Shortcuts")
            } footer: {
                Text("Show today’s plan, start a workout, log the current set, control rest, or review performance and volume from Shortcuts and Siri.")
            }

            #if DEBUG
            Section {
                Button(role: .destructive) {
                    isShowingResetConfirmation = true
                } label: {
                    Label("Reset development data", systemImage: AppIcon.trash)
                        .foregroundStyle(Color.gymDestructive)
                }
                .accessibilityIdentifier("settings-reset-development-data")
            } header: {
                Text("Development")
            } footer: {
                Text("Removes workout history, saved workouts, training plans, and custom exercises, then restores the built-in exercise catalogue.")
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings-advanced-screen")
        .confirmationDialog("Reset development data?", isPresented: $isShowingResetConfirmation, titleVisibility: .visible) {
            Button("Reset data", role: .destructive) {
                resetDevelopmentData()
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func resetDevelopmentData() {
        do {
            try modelContext.clearAllGymData()
            _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: modelContext)
        } catch {
            print("Failed to reset development data: \(error)")
        }
    }
}

extension Notification.Name {
    static let gymDataRestored = Notification.Name("gymDataRestored")
}

struct ImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let backup: BackupDTO
    let onConfirm: () -> Void
    @State private var isShowingConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section("Backup Details") {
                    LabeledContent("Version", value: "\(backup.version)")
                    LabeledContent("Units", value: backup.preferences.unitSystem.capitalized)
                    // Zero is the automatic sentinel, not a zero-second rest.
                    LabeledContent(
                        "Default Rest",
                        value: backup.preferences.restTimer > 0
                            ? "\(backup.preferences.restTimer)s"
                            : String(localized: "Automatic")
                    )
                }

                Section("Contents to Restore") {
                    LabeledContent("Custom Exercises", value: "\(backup.exercises.filter(\.isCustom).count)")
                    LabeledContent("Saved Workouts", value: "\(backup.templates.count)")
                    LabeledContent("Workout Folders", value: "\(backup.collections.count)")
                    LabeledContent("Training plans", value: "\(backup.plans.count)")
                    LabeledContent("Plan runs", value: "\(backup.planRuns.count)")
                    LabeledContent("Workout History", value: "\(backup.workouts.count)")
                    LabeledContent("Daily Check-ins", value: "\(backup.dailyLogEntries.count)")
                    LabeledContent("Creatine Confirmations", value: "\(backup.supplementOccurrences.filter { $0.status == SupplementOccurrenceStatus.completed.rawValue }.count)")
                    LabeledContent("Mobility Routines", value: "\(backup.mobilityRoutines.count)")
                    LabeledContent("Mobility Sessions", value: "\(backup.mobilitySessions.count)")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gymBackground)
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Restore") {
                        isShowingConfirmation = true
                    }
                    .font(AppFont.headline)
                    .accessibilityIdentifier("confirm-backup-restore")
                }
            }
            .confirmationDialog(
                "Restore Backup?",
                isPresented: $isShowingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Restore & Replace All Data", role: .destructive) {
                    onConfirm()
                    dismiss()
                }
                .accessibilityIdentifier("restore-replace-all-data")
            } message: {
                Text("This will delete your workout history, saved workouts, workout folders, training plans, plan runs, and custom exercises. This cannot be undone.")
            }
        }
        .accessibilityIdentifier("import-preview")
    }
}
