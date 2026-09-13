import SwiftData
import SwiftUI

/// Cloud-file status and actions on Data & backup. The working copy stays on
/// this iPhone; the linked file is the copy other devices open.
struct CloudFileSettingsSection: View {
    var service: CloudFileSyncService
    let isBusy: Bool
    let onCreate: () -> Void
    let onOpen: () -> Void
    let onLinkGoogleDrive: () -> Void
    let onSyncNow: () -> Void
    let onUnlink: () -> Void
    let onKeepThisIPhone: () -> Void
    let onUseCloudFile: () -> Void
    let onSyncModeChange: (CloudFileSyncMode) -> Void

    @State private var isConfirmingUnlink = false
    @State private var isShowingConflict = false

    var body: some View {
        Group {
            if let record = service.linkedRecord {
                LabeledContent {
                    Text(record.locationKind.title)
                } label: {
                    Label(
                        String(localized: "Location"),
                        systemImage: icon(for: record.locationKind)
                    )
                }
                .accessibilityIdentifier("settings-cloud-file-location")

                LabeledContent {
                    Text(record.displayName)
                } label: {
                    Label(
                        String(localized: "File"),
                        systemImage: AppIcon.backup
                    )
                }
                .accessibilityIdentifier("settings-cloud-file-name")

                if let email = record.googleDriveAccountEmail, email.isEmpty == false {
                    LabeledContent {
                        Text(email)
                    } label: {
                        Label(
                            String(localized: "Account"),
                            systemImage: AppIcon.backup
                        )
                    }
                    .accessibilityIdentifier("settings-cloud-file-account")
                }

                LabeledContent {
                    Text(statusText)
                } label: {
                    Label(
                        String(localized: "Status"),
                        systemImage: AppIcon.cloudFile
                    )
                }
                .accessibilityIdentifier("settings-cloud-file-status")

                Picker(selection: Binding(
                    get: { record.syncMode },
                    set: onSyncModeChange
                )) {
                    ForEach(CloudFileSyncMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                } label: {
                    Label(
                        String(localized: "Sync"),
                        systemImage: AppIcon.cloudFile
                    )
                }
                .pickerStyle(.menu)
                .disabled(isBusy || service.isSyncing)
                .accessibilityIdentifier("settings-cloud-file-sync-mode")

                Button {
                    onSyncNow()
                } label: {
                    Label(
                        String(localized: "Sync now"),
                        systemImage: AppIcon.cloudFile
                    )
                }
                .disabled(isBusy || service.isSyncing)
                .accessibilityIdentifier("settings-cloud-file-sync")

                Button(role: .destructive) {
                    isConfirmingUnlink = true
                } label: {
                    Label(
                        String(localized: "Unlink"),
                        systemImage: AppIcon.remove
                    )
                }
                .disabled(isBusy || service.isSyncing)
                .accessibilityIdentifier("settings-cloud-file-unlink")
            } else {
                Button {
                    onCreate()
                } label: {
                    Label(
                        String(localized: "Create cloud file"),
                        systemImage: AppIcon.cloudFile
                    )
                }
                .disabled(isBusy || service.isSyncing)
                .accessibilityIdentifier("settings-cloud-file-create")

                Button {
                    onOpen()
                } label: {
                    Label(
                        String(localized: "Open cloud file"),
                        systemImage: AppIcon.folders
                    )
                }
                .disabled(isBusy || service.isSyncing)
                .accessibilityIdentifier("settings-cloud-file-open")

                Button {
                    onLinkGoogleDrive()
                } label: {
                    Label(
                        String(localized: "Google Drive"),
                        systemImage: AppIcon.backup
                    )
                }
                .disabled(isBusy || service.isSyncing)
                .accessibilityIdentifier("settings-cloud-file-google-drive")
            }
        }
        .confirmationDialog(
            String(localized: "Unlink this file?"),
            isPresented: $isConfirmingUnlink,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Unlink"), role: .destructive, action: onUnlink)
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text("This iPhone keeps its training data. Other devices stop receiving updates from this file.")
        }
        .confirmationDialog(
            String(localized: "This iPhone and the cloud file both changed."),
            isPresented: $isShowingConflict,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Keep this iPhone"), action: onKeepThisIPhone)
            Button(String(localized: "Use cloud file"), role: .destructive, action: onUseCloudFile)
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text("Using the cloud file replaces what is on this iPhone after a local recovery copy is written.")
        }
        .onChange(of: service.lastOutcome) { _, outcome in
            isShowingConflict = outcome == .conflict
        }
        .onAppear {
            isShowingConflict = service.lastOutcome == .conflict
        }
    }

    private var statusText: String {
        if service.isSyncing {
            return String(localized: "Syncing")
        }
        if let message = service.lastErrorMessage, message.isEmpty == false {
            return message
        }
        switch service.lastOutcome {
        case .unlinked:
            return String(localized: "Not linked")
        case .inSync:
            return syncedTimestampText
        case .pushed:
            return String(localized: "Updated the cloud file")
        case .pulled:
            return String(localized: "Updated this iPhone")
        case .conflict:
            return String(localized: "Both changed")
        case .skippedActiveWorkout:
            return String(localized: "Waiting — workout in progress")
        case .failed(let message):
            return message
        }
    }

    private var syncedTimestampText: String {
        guard let date = service.linkedRecord?.lastSyncedAt else {
            return String(localized: "Linked")
        }
        return date.formatted(.relative(presentation: .named))
    }

    private func icon(for kind: CloudFileLocationKind) -> String {
        switch kind {
        case .iCloudDrive: AppIcon.cloudFile
        case .googleDrive: AppIcon.backup
        case .otherFiles: AppIcon.folders
        }
    }
}
