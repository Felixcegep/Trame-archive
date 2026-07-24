//
//  GymTrackerApp.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import SwiftUI
import SwiftData

@main
struct GymTrackerApp: App {
    @UIApplicationDelegateAdaptor(GymTrackerNotificationDelegate.self) private var appDelegate
    
    var body: some Scene {
        WindowGroup {
            switch GymTrackerModelContainer.bootstrapState {
            case let .ready(container):
                RootView()
                    .modelContainer(container)
            case let .unavailable(message):
                StorageUnavailableView(message: message)
            }
        }
    }
}

private struct StorageUnavailableView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Your data couldn’t be opened", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("GymTracker has not changed your data. Restart the app after freeing storage or updating the app. If this continues, contact support with your diagnostic report.")
        }
        .padding(Spacing.xl)
        .foregroundStyle(Color.gymText)
        .background(Color.gymBackground)
        .accessibilityIdentifier("storage-unavailable")
        .accessibilityHint(message)
    }
}
