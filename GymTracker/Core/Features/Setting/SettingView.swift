//
//  SettingView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(DefaultsKey.darkMode) private var darkMode: Bool = false
    @AppStorage(DefaultsKey.restTimer) private var restTimer: Int = 20
    @AppStorage(DefaultsKey.useMetric) private var unitSystem: UnitSystem = .metric
    @State private var isShowingResetConfirmation = false
    @State private var isShowingFileImporter = false
    @State private var importBackup: BackupDTO? = nil
    @State private var importErrorMessage: String? = nil
    @State private var isShowingImportError = false

    var body: some View {
        Form {
            Section("Units") {
                Picker("Units", selection: $unitSystem) {
                    ForEach(UnitSystem.allCases, id: \.self) { system in
                        Text(system == .metric ? String(localized: "Metric") : String(localized: "Imperial"))
                            .tag(system)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Rest Timer") {
                Stepper(value: $restTimer, in: 10...300, step: 5) {
                    LabeledContent("Duration", value: formattedRestTimer)
                }
            }

            Section("Backup & Restore") {
                if let url = exportURL() {
                    ShareLink(item: url) {
                        Label("Export Data", systemImage: AppIcon.export)
                    }
                }

                Button {
                    isShowingFileImporter = true
                } label: {
                    Label("Import Data", systemImage: AppIcon.import)
                }
            }

            #if DEBUG
            Section {
                Button(role: .destructive) {
                    isShowingResetConfirmation = true
                } label: {
                    Label("Reset development data", systemImage: AppIcon.trash)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Development")
            } footer: {
                Text("Removes all local workouts, templates, plans, and custom exercises, then restores the built-in exercise catalogue.")
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
        .sheet(item: $importBackup) { backup in
            ImportPreviewView(backup: backup) {
                restoreBackup(backup)
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
            guard CommandLine.arguments.contains("-ui-testing-import-error") else { return }
            showImportError("Invalid backup file: The selected file is not a GymTracker backup.")
        }
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

    private func resetDevelopmentData() {
        do {
            try modelContext.clearAllGymData()

            for template in ExerciseSeedData.templates() {
                modelContext.insert(template)
            }
            try modelContext.save()

            let exercises = try modelContext.fetch(FetchDescriptor<ExerciceTemplate>())
            for template in WorkoutTemplateSeedData.templates(using: exercises) {
                modelContext.insert(template)
            }
            try modelContext.save()

            let templates = try modelContext.fetch(FetchDescriptor<WorkoutTemplate>())
            let programTemplates = templates.filter { $0.name.starts(with: "Jour ") }
            if !programTemplates.isEmpty {
                let sortedTemplates = programTemplates.sorted { $0.name < $1.name }
                let collection = WorkoutCollection(name: "Programme Haut/Bas - 4 Jours", workoutTemplates: sortedTemplates)
                modelContext.insert(collection)
                try modelContext.save()
            }
        } catch {
            print("Failed to reset development data: \(error)")
        }
    }

    private func exportURL() -> URL? {
        do {
            let backup = try BackupDTO.create(from: modelContext, restTimer: restTimer, darkMode: darkMode, unitSystem: unitSystem)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(backup)

            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("GymTrackerBackup.json")
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to export data: \(error)")
            return nil
        }
    }

    private func loadImportBackup(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            showImportError("Cannot access the selected file.")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backup = try decoder.decode(BackupDTO.self, from: data)
            try backup.validate()
            self.importBackup = backup
        } catch {
            showImportError("Invalid backup file: \(error.localizedDescription)")
        }
    }

    private func showImportError(_ message: String) {
        importErrorMessage = message
        isShowingImportError = true
    }

    private func restoreBackup(_ backup: BackupDTO) {
        do {
            try backup.restore(to: modelContext)
            self.darkMode = backup.preferences.darkMode
            self.restTimer = backup.preferences.restTimer
            self.unitSystem = UnitSystem(rawValue: backup.preferences.unitSystem) ?? .metric
            NotificationCenter.default.post(name: .gymDataRestored, object: nil)
        } catch {
            showImportError("Failed to restore backup: \(error.localizedDescription)")
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
                    LabeledContent("Default Rest", value: "\(backup.preferences.restTimer)s")
                }

                Section("Contents to Restore") {
                    LabeledContent("Custom Exercises", value: "\(backup.exercises.filter(\.isCustom).count)")
                    LabeledContent("Workout Templates", value: "\(backup.templates.count)")
                    LabeledContent("Collections", value: "\(backup.collections.count)")
                    LabeledContent("Plans", value: "\(backup.plans.count)")
                    LabeledContent("Plan Runs", value: "\(backup.planRuns.count)")
                    LabeledContent("Workout History", value: "\(backup.workouts.count)")
                }
            }
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
            } message: {
                Text("This will delete all your current workouts, templates, collections, plans, plan runs, and custom exercises. This cannot be undone.")
            }
        }
    }
}
