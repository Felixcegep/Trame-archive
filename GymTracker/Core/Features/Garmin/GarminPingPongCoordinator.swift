import ConnectIQ
import Combine
import Foundation

/// Narrow physical-device proof for the local Connect IQ transport.
/// It intentionally does not touch workouts or SwiftData.
@MainActor
final class GarminPingPongCoordinator: NSObject, ObservableObject {
    static let shared = GarminPingPongCoordinator()
    static let callbackScheme = "trame-garmin"
    static let watchAppID = UUID(uuidString: "9180C51D-14BE-4F7D-8917-095FFB62F46D")!

    enum ConnectionState: Equatable {
        case noDevice, connecting, connected, disconnected, bluetoothUnavailable

        var title: String {
            switch self {
            case .noDevice: "No Garmin selected"
            case .connecting: "Connecting"
            case .connected: "Connected"
            case .disconnected: "Disconnected"
            case .bluetoothUnavailable: "Bluetooth unavailable"
            }
        }
    }

    @Published private(set) var selectedDeviceName: String?
    @Published private(set) var connectionState: ConnectionState = .noDevice
    @Published private(set) var lastPingID: String?
    @Published private(set) var lastPongAt: Date?
    @Published private(set) var isWatchAppInstalled: Bool?
    @Published private(set) var statusMessage = "Select a Garmin to begin the local BLE test."
    @Published private(set) var isSending = false

    private let sdk = ConnectIQ.sharedInstance()!
    private var selectedDevice: IQDevice?
    private var watchApp: IQApp?
    private var didInitialize = false

    private override init() { super.init() }

    func start() {
        guard !didInitialize else { return }
        didInitialize = true
        sdk.initialize(withUrlScheme: Self.callbackScheme, uiOverrideDelegate: nil)
        restoreSelectedDevice()
    }

    func selectDevice() {
        start()
        sdk.showDeviceSelection()
    }

    @discardableResult
    func handleOpenURL(_ url: URL) -> Bool {
        guard url.scheme == Self.callbackScheme else { return false }
        start()
        let devices = sdk.parseDeviceSelectionResponse(from: url).compactMap { $0 as? IQDevice }
        guard let device = devices.first else {
            statusMessage = "Garmin Connect did not return a compatible device."
            return true
        }
        configure(device: device, persist: true)
        return true
    }

    func sendPing() {
        guard let watchApp else {
            statusMessage = "Select a Garmin before sending a ping."
            return
        }
        guard connectionState == .connected else {
            statusMessage = "The selected Garmin is not connected."
            return
        }

        let pingID = UUID().uuidString.lowercased()
        lastPingID = pingID
        lastPongAt = nil
        isSending = true
        statusMessage = "Sending ping…"
        let message = GarminPingPongProtocol.ping(id: pingID, sentAt: .now)

        sdk.sendMessage(message, to: watchApp, progress: nil) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isSending = false
                self.statusMessage = result == .success
                    ? "Ping delivered. Waiting for the watch pong…"
                    : "Ping delivery failed (code \(result.rawValue))."
            }
        }
    }

    private func configure(device: IQDevice, persist: Bool) {
        if let selectedDevice { sdk.unregister(forDeviceEvents: selectedDevice, delegate: self) }
        if let watchApp { sdk.unregister(forAppMessages: watchApp, delegate: self) }

        selectedDevice = device
        selectedDeviceName = device.friendlyName ?? device.modelName ?? "Garmin"
        connectionState = .connecting
        statusMessage = "Waiting for \(selectedDeviceName ?? "Garmin")…"
        watchApp = IQApp(uuid: Self.watchAppID, store: nil, device: device)

        if persist, let data = try? NSKeyedArchiver.archivedData(withRootObject: device, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: DefaultsKey.garminSelectedDevice)
        }

        sdk.register(forDeviceEvents: device, delegate: self)
        if let watchApp { sdk.register(forAppMessages: watchApp, delegate: self) }
        updateConnectionState(sdk.getDeviceStatus(device))
        refreshWatchAppStatus()
    }

    private func restoreSelectedDevice() {
        guard
            let data = UserDefaults.standard.data(forKey: DefaultsKey.garminSelectedDevice),
            let device = try? NSKeyedUnarchiver.unarchivedObject(ofClass: IQDevice.self, from: data)
        else { return }
        configure(device: device, persist: false)
    }

    private func updateConnectionState(_ status: IQDeviceStatus) {
        switch status {
        case .connected:
            connectionState = .connected
            statusMessage = "Ready for a local BLE ping."
        case .bluetoothNotReady:
            connectionState = .bluetoothUnavailable
            statusMessage = "Turn on Bluetooth to reach the Garmin."
        case .invalidDevice, .notFound, .notConnected:
            connectionState = .disconnected
            statusMessage = "The Garmin is selected but not currently reachable."
        @unknown default:
            connectionState = .disconnected
            statusMessage = "Unknown Garmin connection state."
        }
    }

    private func refreshWatchAppStatus() {
        guard let watchApp else { return }
        sdk.getAppStatus(watchApp) { [weak self] appStatus in
            Task { @MainActor in
                guard let self else { return }
                self.isWatchAppInstalled = appStatus?.isInstalled
                if appStatus?.isInstalled == false {
                    self.statusMessage = "The Trame Ping Pong app is not installed on this Garmin."
                }
            }
        }
    }
}

extension GarminPingPongCoordinator: IQDeviceEventDelegate {
    nonisolated func deviceStatusChanged(_ device: IQDevice, status: IQDeviceStatus) {
        Task { @MainActor in updateConnectionState(status) }
    }

    nonisolated func deviceCharacteristicsDiscovered(_ device: IQDevice) {
        Task { @MainActor in
            updateConnectionState(sdk.getDeviceStatus(device))
            refreshWatchAppStatus()
        }
    }
}

extension GarminPingPongCoordinator: IQAppMessageDelegate {
    nonisolated func receivedMessage(_ message: Any, from app: IQApp) {
        Task { @MainActor in
            guard GarminPingPongProtocol.matchingPongID(from: message, expectedPingID: lastPingID) != nil else {
                statusMessage = "Received an invalid or stale Garmin reply."
                return
            }
            lastPongAt = .now
            statusMessage = "Pong received locally from \(selectedDeviceName ?? "Garmin")."
        }
    }
}
