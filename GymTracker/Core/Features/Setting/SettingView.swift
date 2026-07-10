//
//  SettingView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI

struct SettingView: View {
    @AppStorage("darkMode") private var darkMode: Bool = false
    @AppStorage("restTimer") private var restTimer: Int = 20
    @AppStorage("useMetric") private var unitSystem: UnitSystem = .metric

    var body: some View {
        Form {
            Section("Units") {
                Picker("Units", selection: $unitSystem) {
                    ForEach(UnitSystem.allCases, id: \.self) { system in
                        Text(system.rawValue)
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
        }
        .navigationTitle("Settings")
    }

    private var formattedRestTimer: String {
        if restTimer < 60 {
            return "\(restTimer) sec"
        }

        let minutes = restTimer / 60
        let seconds = restTimer % 60

        if seconds == 0 {
            return "\(minutes) min"
        }

        return "\(minutes) min \(seconds) sec"
    }
}
