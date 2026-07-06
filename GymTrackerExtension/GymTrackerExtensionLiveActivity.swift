//
//  GymTrackerExtensionLiveActivity.swift
//  GymTrackerExtension
//
//  Created by Felix Lachapelle on 2026-07-05.
//

import ActivityKit
import Foundation
import WidgetKit
import SwiftUI

struct GymTrackerAttributes: ActivityAttributes {
    let startTime: Date

    struct ContentState: Codable, Hashable, Sendable {
        var currentExerciseName: String?
        var currentSerie: Int?
        var totalSeries: Int?
        var restTimeActive: Bool?
        var RestTime: Int?
    }
}

struct GymTrackerExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GymTrackerAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text(context.state.currentExerciseName ?? "")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text("TEST")
                }
            } compactLeading: {
                Text(context.state.currentExerciseName ?? "doit etre le premier Exercice")
            } compactTrailing: {
                Text("E")
            } minimal: {
                Text("T")
            }
        }
    }
}

extension GymTrackerAttributes {
    fileprivate static var preview: GymTrackerAttributes {
        GymTrackerAttributes(startTime: .now)
    }
}

extension GymTrackerAttributes.ContentState {
    fileprivate static var preview: GymTrackerAttributes.ContentState {
        GymTrackerAttributes.ContentState(
            currentExerciseName: "TEST",
            currentSerie: nil,
            totalSeries: nil,
            restTimeActive: nil,
            RestTime: nil,

        )
     }
}
