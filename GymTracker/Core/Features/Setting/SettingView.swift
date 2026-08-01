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

struct SettingView: View {
    var currentScreen: AppScreen = .settings
    let activeLoggingMetrics: ActiveLoggingMetricsRecorder
    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current
    @State private var isShowingBetaFeedback = false
    @Environment(\.modelContext) private var modelContext
    @AppStorage(DefaultsKey.darkMode) private var darkMode: Bool = false
    /// Zero means automatic: rest is derived from the exercise. A positive
    /// value is an explicit override that applies everywhere.
    ///
    /// The declared default was 20, which is why every install that never
    /// opened Settings got a 20-second rest. Defaulting to 0 hands those
    /// installs the derived duration instead, while anyone who did set a value
    /// keeps it — an explicit choice is not overridden by a new feature.
    @AppStorage(DefaultsKey.restTimer) private var restTimer: Int = 0
    @AppStorage(DefaultsKey.useMetric) private var unitSystem: UnitSystem = .metric
    @AppStorage(DefaultsKey.bodyWeightPromptCadence) private var bodyWeightPromptCadence: BodyWeightPromptCadence = .off
    @AppStorage(DefaultsKey.caffeineBirthdateTimestamp) private var caffeineBirthdateTimestamp: Double?
    @AppStorage(DefaultsKey.lastBackupExportTimestamp) private var lastBackupExportTimestamp: Double?
    @AppStorage(DefaultsKey.lastBackupRestoreTimestamp) private var lastBackupRestoreTimestamp: Double?
    @Query(sort: \BodyWeightEntry.measuredAt, order: .reverse) private var bodyWeightEntries: [BodyWeightEntry]
    @State private var isShowingResetConfirmation = false
    @State private var isShowingFileImporter = false
    @State private var exportURL: URL?
    @State private var isPreparingExport = false
    @State private var importBackup: BackupDTO? = nil
    @State private var importErrorMessage: String? = nil
    @State private var isShowingImportError = false
    @State private var didHandleUITestImport = false
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
            Section("Appearance") {
                Toggle("Dark Mode", isOn: $darkMode)
                    .accessibilityIdentifier("settings-dark-mode-toggle")
            }

            Section("Units") {
                Picker("Units", selection: $unitSystem) {
                    ForEach(UnitSystem.allCases, id: \.self) { system in
                        Text(system == .metric ? String(localized: "Metric") : String(localized: "Imperial"))
                            .tag(system)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings-units-picker")
                .accessibilityValue(unitSystem == .metric ? String(localized: "Metric") : String(localized: "Imperial"))
            }

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

            Section {
                Toggle("Automatic", isOn: isAutomaticRestBinding)
                    .accessibilityIdentifier("settings-rest-automatic")
                    .accessibilityHint("Chooses rest length from the exercise instead of using one duration everywhere.")

                if restTimer > 0 {
                    Stepper(value: $restTimer, in: 10...300, step: 5) {
                        LabeledContent("Duration", value: formattedRestTimer)
                    }
                    .accessibilityIdentifier("settings-rest-duration")
                }
            } header: {
                Text("Rest Timer")
            } footer: {
                Text(restTimerFooter)
            }

            Section("Workout") {
                NavigationLink("Logging preferences") {
                    WorkoutLoggingSettingsView()
                }
                .accessibilityIdentifier("settings-workout-logging")
            }

            Section {
                ShortcutsLink()
                    .accessibilityIdentifier("settings-shortcuts-link")
            } header: {
                Text("Siri & Shortcuts")
            } footer: {
                Text("Show today’s plan, start a workout, log the current set, control rest, or review performance and volume from Shortcuts and Siri.")
            }

            workoutRemindersSection
            checkInRemindersSection

            dataSafetySection

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

            if featureFlags.isEnabled(.betaFeedback) {
                Section {
                    Button {
                        isShowingBetaFeedback = true
                    } label: {
                        Label("Send Beta Feedback", systemImage: AppIcon.feedback)
                    }
                    .accessibilityIdentifier("settings-beta-feedback")
                } header: {
                    Text("Beta")
                } footer: {
                    Text("Share what's working or broken. Technical details like app version and enabled features are attached by default; your workouts, meals, and health data are never included.")
                }
            }

            #if DEBUG
            Section {
                Button(role: .destructive) {
                    isShowingResetConfirmation = true
                } label: {
                    Label("Reset development data", systemImage: AppIcon.trash)
                        .foregroundStyle(Color.gymDestructive)
                }
            } header: {
                Text("Development")
            } footer: {
                Text("Removes workout history, saved workouts, training plans, and custom exercises, then restores the built-in exercise catalogue.")
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Settings")
        .confirmationDialog("Reset development data?", isPresented: $isShowingResetConfirmation, titleVisibility: .visible) {
            Button("Reset data", role: .destructive) {
                resetDevelopmentData()
            }
        } message: {
            Text("This cannot be undone.")
        }
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
        .sheet(isPresented: $isShowingBetaFeedback) {
            BetaFeedbackScreen(
                context: BetaFeedbackContextProvider.makeContext(
                    screen: currentScreen,
                    activeLoggingMetrics: activeLoggingMetrics.snapshot
                )
            )
        }
        .alert("Import Error", isPresented: $isShowingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let importErrorMessage {
                Text(importErrorMessage)
            }
        }
        .accessibilityIdentifier("settings-screen")
        .onAppear {
            guard !didHandleUITestImport else { return }
            didHandleUITestImport = true

            if CommandLine.arguments.contains("-ui-testing-import-error") {
                showImportError("This file is not a valid Trame backup. Choose a backup exported from Trame.")
            } else if CommandLine.arguments.contains("-ui-testing-import-corrupt") {
                do {
                    _ = try BackupImportService.decodeAndValidate(Data("not-json".utf8))
                } catch {
                    showImportError("This backup could not be read. \(error.localizedDescription)")
                }
            } else if CommandLine.arguments.contains("-ui-testing-import-valid"),
                      let data = UITestFixture.UITestImportPayload.validData {
                do {
                    importBackup = try BackupImportService.decodeAndValidate(data)
                } catch {
                    showImportError("This backup could not be read. \(error.localizedDescription)")
                }
            }
        }
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

    private var workoutRemindersSection: some View {
        Section {
            Toggle("Scheduled workout reminders", isOn: Binding(
                get: { remindersEnabled },
                set: { enabled in
                    remindersEnabled = enabled
                    Task { await setPlanRemindersEnabled(enabled) }
                }
            ))

            if remindersEnabled {
                DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .onChange(of: reminderTime) { _, newValue in
                        PlanNotificationScheduler.shared.setReminderTime(newValue)
                    }
            }

            if reminderAuthorization == .denied {
                Text("Notifications are disabled in System Settings.")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                Button("Open System Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            }
        } header: {
            Text("Workout Reminders")
        } footer: {
            Text("Trame schedules reminders only for future workouts in your active plan.")
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

    private var checkInRemindersSection: some View {
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

            if reminderAuthorization == .denied {
                Text("Notifications are disabled in System Settings.")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        } header: {
            Text("Daily check-in")
        } footer: {
            Text("One optional reminder is scheduled for the selected evening time. Saving or skipping today’s check-in removes it.")
        }
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

    private var formattedRestTimer: String {
        if restTimer < 60 {
            return String(localized: "\(restTimer) sec")
        }

        let minutes = restTimer / 60
        let seconds = restTimer % 60

        if seconds == 0 {
            return String(localized: "\(minutes) min")
        }

        return String(localized: "\(minutes) min \(seconds) sec")
    }

    private var latestBodyWeightText: String {
        guard let latest = bodyWeightEntries.first else { return String(localized: "Not recorded") }
        return "\(Formatters.formatFloat(latest.value)) \(latest.unit.rawValue)"
    }

    private func resetDevelopmentData() {
        do {
            try modelContext.clearAllGymData()
            _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: modelContext)
        } catch {
            print("Failed to reset development data: \(error)")
        }
    }

    /// What the user actually risks, stated plainly.
    ///
    /// "Local-first" only reassures someone who can see their own exposure: where
    /// the data lives, whether a copy exists, how old it is, and whether restoring
    /// one has ever been proven to work on this device. Without sync, that last
    /// question is the difference between a promise and a guarantee — so it is
    /// answered honestly, including when the answer is "not yet".
    private var dataSafetySection: some View {
        Section {
            LabeledContent {
                Text("This iPhone")
            } label: {
                Label("Stored", systemImage: AppIcon.lock)
            }
            .accessibilityIdentifier("settings-data-safety-storage")

            LabeledContent {
                Text(relativeBackupDate(lastBackupExportTimestamp))
            } label: {
                Label("Last export", systemImage: AppIcon.export)
            }
            .accessibilityIdentifier("settings-data-safety-last-export")

            LabeledContent {
                Text(lastBackupRestoreTimestamp == nil ? "Not yet" : relativeBackupDate(lastBackupRestoreTimestamp))
            } label: {
                Label("Restore tested", systemImage: AppIcon.restore)
            }
            .accessibilityIdentifier("settings-data-safety-restore-tested")

            LabeledContent {
                Text(verbatim: "v\(BackupDTO.currentVersion)")
            } label: {
                Label("Backup format", systemImage: AppIcon.import)
            }
            .accessibilityIdentifier("settings-data-safety-backup-format")
        } header: {
            Text("Data Safety")
        } footer: {
            if lastBackupExportTimestamp == nil {
                Text("Your training history lives only on this iPhone. There is no cloud copy, so an export is the only way to survive losing or replacing the device.")
            } else {
                Text("Your training history lives only on this iPhone. Anything logged since your last export is not in that copy.")
            }
        }
    }

    private func relativeBackupDate(_ timestamp: Double?) -> String {
        guard let timestamp else { return String(localized: "Never") }
        return Date(timeIntervalSince1970: timestamp)
            .formatted(.dateTime.year().month(.abbreviated).day())
    }

    private func prepareExport() {
        guard isPreparingExport == false else { return }
        isPreparingExport = true
        do {
            let backup = try BackupDTO.create(from: modelContext, restTimer: restTimer, darkMode: darkMode, unitSystem: unitSystem)
            Task {
                do {
                    let fileURL = try await Task.detached(priority: .utility) {
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = .prettyPrinted
                        encoder.dateEncodingStrategy = .iso8601
                        let data = try encoder.encode(backup)
                        let fileURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent("TrameBackup.json")
                        try data.write(to: fileURL, options: .atomic)
                        return fileURL
                    }.value
                    exportURL = fileURL
                    // Recorded when the file exists, not when the share sheet is
                    // dismissed: the user may share it anywhere, or nowhere, and
                    // the fact this section reports is that a backup was produced.
                    lastBackupExportTimestamp = Date.now.timeIntervalSince1970
                } catch {
                    showImportError("The backup could not be exported. \(error.localizedDescription)")
                }
                isPreparingExport = false
            }
        } catch {
            isPreparingExport = false
            showImportError("The backup could not be exported. \(error.localizedDescription)")
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
            self.darkMode = preferences.darkMode
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
}

private struct WorkoutLoggingSettingsView: View {
    @AppStorage(DefaultsKey.effortMeasure) private var effortMeasure: EffortMeasure = .rir

    var body: some View {
        Form {
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
        .navigationTitle("Workout Logging")
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
