//
//  SettingView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI
import Foundation
import SwiftData

struct SettingView : View {
    @AppStorage("darkMode") var darkMode: Bool = false
    @AppStorage("restTimer") private var restTimer: Int = 20
    @AppStorage("useMetric") private var unitSystem: UnitSystem = .metric
    var body: some View {
        Picker("Units", selection: $unitSystem) {
            ForEach(UnitSystem.allCases, id: \.self) { system in
                Text(system.rawValue)
                    .tag(system.rawValue)
                
            }
        }
        .pickerStyle(.menu)
    }
}
