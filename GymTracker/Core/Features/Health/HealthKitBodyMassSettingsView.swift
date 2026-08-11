import SwiftData
import SwiftUI

#if !GYMTRACKER_EXTENSION
struct HealthKitBodyMassSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var state: ImportState = .idle
    @State private var isImporting = false
    @AppStorage(DefaultsKey.healthKitWorkoutExportEnabled) private var exportsWorkouts = false

    private enum ImportState: Equatable {
        case idle
        case unavailable
        case imported(imported: Int, skipped: Int, duplicates: Int)
        case failed(String)
    }

    var body: some View {
        Form {
            Section {
                Text("Import body-mass measurements from Apple Health when you choose. Trame keeps them separate from your authored entries and never changes workouts or targets automatically.")

                Button {
                    importBodyMass()
                } label: {
                    Label(isImporting ? "Reading Apple Health…" : "Connect and import", systemImage: AppIcon.bodyWeight)
                }
                .disabled(isImporting)
                .accessibilityIdentifier("healthkit-body-mass-import")
            } header: {
                Text("Apple Health")
            }

            Section("Status") {
                switch state {
                case .idle:
                    Text("Nothing has been imported yet.")
                case .unavailable:
                    Label("Apple Health is unavailable on this device.", systemImage: AppIcon.warning)
                case let .imported(imported, skipped, duplicates):
                    Text("Imported \(imported) measurement\(imported == 1 ? "" : "s"); skipped \(skipped); already known \(duplicates).")
                case let .failed(message):
                    Label(message, systemImage: AppIcon.warning)
                }
            }

            Section {
                Toggle(isOn: $exportsWorkouts) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Export completed workouts")
                        Text("When enabled, Trame sends an aggregate workout summary after the local save succeeds. Exercise, set, note, and plan details stay in Trame.")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                .accessibilityIdentifier("healthkit-workout-export-toggle")
            } header: {
                Text("Workout export")
            } footer: {
                Text("This is optional. Turning it off never affects local workout saving or existing History.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("healthkit-body-mass-screen")
    }

    private func importBodyMass() {
        isImporting = true
        Task { @MainActor in
            defer { isImporting = false }
            do {
                let adapter = LiveHealthKitAdapter()
                try await HealthKitAuthorizationService.requestBodyMassAuthorization(using: adapter)
                let endDate = Date.now
                let startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate) ?? endDate
                let samples = try await adapter.readBodyMassSamples(from: startDate, through: endDate)
                let entries = try modelContext.fetch(FetchDescriptor<BodyWeightEntry>())
                let provenance = try modelContext.fetch(FetchDescriptor<HealthKitBodyMassProvenance>())
                let preview = HealthKitBodyMassImportService.preview(
                    samples: samples,
                    existingEntries: entries,
                    existingProvenance: provenance
                )
                _ = try HealthKitBodyMassImportService.apply(importPreview: preview, to: modelContext)
                let skipped = preview.items.filter {
                    if case .sameDayUserAuthored = $0.status { return true }
                    return false
                }.count
                let duplicates = preview.items.filter { $0.status == .duplicateSample || $0.status == .sameDayImported }.count
                state = .imported(imported: preview.importableItems.count, skipped: skipped, duplicates: duplicates)
            } catch let error as HealthKitIntegrationError {
                state = error == .unavailable ? .unavailable : .failed(error.localizedDescription)
            } catch {
                state = .failed("Apple Health could not be read right now.")
            }
        }
    }
}
#endif
