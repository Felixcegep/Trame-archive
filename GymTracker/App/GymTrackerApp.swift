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
                    .onOpenURL { url in
                        _ = GarminPingPongCoordinator.shared.handleOpenURL(url)
                    }
            case let .unavailable(message, storeURL):
                StorageUnavailableView(message: message, storeURL: storeURL)
            }
        }
    }
}

private struct StorageUnavailableView: View {
    let message: String
    let storeURL: URL

    @State private var exportDocument = StoreRecoveryBundleDocument.empty
    @State private var isExporting = false
    @State private var exportSucceeded = false
    @State private var isConfirmingRemoval = false
    @State private var didRemoveStore = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Label(
                    String(localized: "storage.recovery.title", defaultValue: "Your data couldn’t be opened"),
                    systemImage: "externaldrive.badge.exclamationmark"
                )
                .font(AppFont.titleMedium)
                .foregroundStyle(Color.gymText)

                Text(String(localized: "storage.recovery.explanation", defaultValue: "Trame has not changed your data. Export a complete copy of the local store before removing the broken copy."))
                    .font(AppFont.body)
                    .foregroundStyle(Color.gymText)

                Text(message)
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.gymSubduedText)
                    .textSelection(.enabled)

                VStack(alignment: .leading, spacing: Spacing.m) {
                    Button {
                        prepareExport()
                    } label: {
                        Label(
                            String(localized: "storage.recovery.export", defaultValue: "Export complete store bundle"),
                            systemImage: "square.and.arrow.up"
                        )
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.gymPrimaryDeep)
                    .disabled(isExporting || didRemoveStore)
                    .accessibilityIdentifier("storage-export")

                    if exportSucceeded && !didRemoveStore {
                        Text(String(localized: "storage.recovery.exportSucceeded", defaultValue: "Export complete. Keep this bundle in a safe place before continuing."))
                            .font(AppFont.subheadline)
                            .foregroundStyle(Color.gymSuccess)

                        Button(role: .destructive) {
                            isConfirmingRemoval = true
                        } label: {
                            Label(
                                String(localized: "storage.recovery.remove", defaultValue: "Remove broken local store"),
                                systemImage: "trash"
                            )
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.gymDestructive)
                        .accessibilityIdentifier("storage-remove")
                    }

                    if didRemoveStore {
                        Text(String(localized: "storage.recovery.removed", defaultValue: "The broken local store was removed. Reopen Trame to create a fresh store, then restore from your exported bundle."))
                            .font(AppFont.subheadline)
                            .foregroundStyle(Color.gymText)
                            .accessibilityIdentifier("storage-removed")
                    }
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 620, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(Color.gymText)
        .background(Color.gymBackground)
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: StoreRecoveryBundleDocument.contentType,
            defaultFilename: "TrameStoreRecovery.storebundle",
            onCompletion: handleExportCompletion
        )
        .alert(
            String(localized: "storage.recovery.removeConfirmationTitle", defaultValue: "Remove the broken local store?"),
            isPresented: $isConfirmingRemoval
        ) {
            Button(String(localized: "storage.recovery.removeConfirm", defaultValue: "Remove local store"), role: .destructive) {
                removeStore()
            }
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "storage.recovery.removeConfirmationMessage", defaultValue: "Only the local store and its SQLite sidecars will be removed. Your exported bundle and pre-migration safety copy will remain."))
        }
        .alert(
            String(localized: "storage.recovery.actionFailed", defaultValue: "Recovery action failed"),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? String(localized: "storage.recovery.unknownError", defaultValue: "The recovery action could not be completed."))
        }
        .accessibilityIdentifier("storage-unavailable")
    }

    private func prepareExport() {
        do {
            exportDocument = try GymTrackerStoreRecovery.makeBundleDocument(for: storeURL)
            exportSucceeded = false
            isExporting = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleExportCompletion(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            exportSucceeded = true
            errorMessage = nil
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func removeStore() {
        guard exportSucceeded else { return }
        do {
            try GymTrackerStoreRecovery.removeStore(at: storeURL)
            didRemoveStore = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
