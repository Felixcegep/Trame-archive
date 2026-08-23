import SwiftUI

struct GarminPingPongView: View {
    @StateObject private var coordinator = GarminPingPongCoordinator.shared

    var body: some View {
        Form {
            Section {
                LabeledContent("Device", value: coordinator.selectedDeviceName ?? "Not selected")
                LabeledContent("Connection", value: coordinator.connectionState.title)
                LabeledContent("Watch app", value: watchAppStatus)
            } header: {
                Text("Garmin Connect IQ")
            } footer: {
                Text("Garmin Connect selects the paired device. Ping and pong then travel locally over Bluetooth.")
            }

            Section("Physical-device test") {
                Button {
                    coordinator.selectDevice()
                } label: {
                    Label("Select Garmin", systemImage: "applewatch.radiowaves.left.and.right")
                }
                .accessibilityIdentifier("garmin-select-device")

                Button {
                    coordinator.sendPing()
                } label: {
                    Label("Send ping", systemImage: "dot.radiowaves.left.and.right")
                }
                .disabled(coordinator.connectionState != .connected || coordinator.isSending)
                .accessibilityIdentifier("garmin-send-ping")
            }

            Section("Result") {
                Text(coordinator.statusMessage)
                    .foregroundStyle(coordinator.lastPongAt == nil ? Color.trameText : Color.trameCompleted)
                    .accessibilityIdentifier("garmin-ping-status")
                if let pingID = coordinator.lastPingID {
                    LabeledContent("Ping ID", value: pingID)
                        .font(AppFont.micro.monospaced())
                }
                if let lastPongAt = coordinator.lastPongAt {
                    LabeledContent("Pong received", value: lastPongAt.formatted(date: .omitted, time: .standard))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Garmin test")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { coordinator.start() }
        .accessibilityIdentifier("garmin-ping-pong-screen")
    }

    private var watchAppStatus: String {
        switch coordinator.isWatchAppInstalled {
        case true: "Installed"
        case false: "Not installed"
        case nil: "Not checked"
        }
    }
}
