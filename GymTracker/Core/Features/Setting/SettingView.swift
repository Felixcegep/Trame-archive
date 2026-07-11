//
//  SettingView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftData
import SwiftUI

struct SettingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(DefaultsKey.darkMode) private var darkMode: Bool = false
    @AppStorage(DefaultsKey.restTimer) private var restTimer: Int = 20
    @AppStorage(DefaultsKey.useMetric) private var unitSystem: UnitSystem = .metric
    @State private var isShowingResetConfirmation = false

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

            #if DEBUG
            Section {
                Button(role: .destructive) {
                    isShowingResetConfirmation = true
                } label: {
                    Label("Reset development data", systemImage: AppIcon.trash)
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
        } catch {
            print("Failed to reset development data: \(error)")
        }
    }
}
