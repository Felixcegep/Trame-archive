//
//  GymTrackerExtensionBundle.swift
//  GymTrackerExtension
//
//  Created by Felix Lachapelle on 2026-07-05.
//

import WidgetKit
import SwiftUI

@main
struct GymTrackerExtensionBundle: WidgetBundle {
    var body: some Widget {
        GymTrackerExtensionLiveActivity()
        TodayWorkoutWidget()
        WeeklyVolumeWidget()
        CaffeineWidget()
        CreatineWidget()
    }
}
