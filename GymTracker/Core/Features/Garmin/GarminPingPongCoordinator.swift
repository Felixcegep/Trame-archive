import ConnectIQ
import Combine
import Foundation
import SwiftData

/// Phone-authoritative Connect IQ transport for diagnostics and workout commands.
/// Garmin receives projections; all accepted workout mutations remain owned by SwiftData on iPhone.
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

    private static let pendingPingsDefaultsKey = "garmin.pendingPings.v1"

    private let sdk = ConnectIQ.sharedInstance()!
    private var selectedDevice: IQDevice?
    private var watchApp: IQApp?
    private var didInitialize = false
    private var pendingPings: [GarminPingPongProtocol.PendingPing] = []
    private var retryTask: Task<Void, Never>?
    private var container: ModelContainer?
    private var workoutReceipts: [WatchCompanionCommandReceipt] = []
    private var isObservingWorkoutMutations = false

    private override init() { super.init() }

    func activate(container: ModelContainer) {
        self.container = container
        workoutReceipts = loadWorkoutReceipts()
        start()
        if !isObservingWorkoutMutations {
            isObservingWorkoutMutations = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(activeWorkoutDidMutate),
                name: .activeWorkoutMutated,
                object: nil
            )
        }
        publishWorkoutSnapshot()
    }

    @objc private func activeWorkoutDidMutate() {
        publishWorkoutSnapshot()
    }

    func start() {
        guard !didInitialize else { return }
        didInitialize = true
        restorePendingPings()
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
        guard watchApp != nil else {
            statusMessage = "Select a Garmin before sending a ping."
            return
        }
        guard connectionState == .connected else {
            statusMessage = "The selected Garmin is not connected."
            return
        }

        let pending = GarminPingPongProtocol.PendingPing()
        pendingPings.append(pending)
        persistPendingPings()
        let pingID = pending.id
        lastPingID = pingID
        lastPongAt = nil
        transmitNextPendingPing(force: true)
    }

    private func transmitNextPendingPing(force: Bool = false) {
        guard !isSending, let watchApp, connectionState == .connected else { return }
        let now = Date.now
        guard let index = pendingPings.firstIndex(where: {
            force || $0.nextAttemptAt <= now
        }) else {
            scheduleRetryIfNeeded()
            return
        }

        pendingPings[index].recordAttempt(at: now)
        let pending = pendingPings[index]
        persistPendingPings()
        lastPingID = pending.id
        isSending = true
        statusMessage = pending.attemptCount == 1 ? "Sending ping…" : "Retrying ping (attempt \(pending.attemptCount))…"
        let message = GarminPingPongProtocol.ping(id: pending.id, sentAt: pending.createdAt)

        sdk.sendMessage(message, to: watchApp, progress: nil) { result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSending = false
                self.statusMessage = result == .success
                    ? "Ping delivered. Waiting for the watch pong…"
                    : "Ping delivery failed (\(Self.sendResultDescription(result)))."
                self.scheduleRetryIfNeeded()
            }
        }
    }

    private func scheduleRetryIfNeeded() {
        retryTask?.cancel()
        guard connectionState == .connected,
              let next = pendingPings
                .map(\.nextAttemptAt)
                .min()
        else { return }
        let delay = max(0, next.timeIntervalSinceNow)
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.transmitNextPendingPing()
        }
    }

    private func restorePendingPings() {
        guard let data = UserDefaults.standard.data(forKey: Self.pendingPingsDefaultsKey),
              let restored = try? JSONDecoder().decode([GarminPingPongProtocol.PendingPing].self, from: data)
        else { return }
        pendingPings = restored
        lastPingID = restored.first?.id
    }

    private func persistPendingPings() {
        guard let data = try? JSONEncoder().encode(pendingPings) else { return }
        UserDefaults.standard.set(data, forKey: Self.pendingPingsDefaultsKey)
    }

    private func configure(device: IQDevice, persist: Bool) {
        if let selectedDevice { sdk.unregister(forDeviceEvents: selectedDevice, delegate: self) }
        if let watchApp { sdk.unregister(forAppMessages: watchApp, delegate: self) }

        selectedDevice = device
        selectedDeviceName = displayName(for: device)
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
            transmitNextPendingPing()
            publishWorkoutSnapshot()
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
        sdk.getAppStatus(watchApp) { appStatus in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isWatchAppInstalled = appStatus?.isInstalled
                if appStatus?.isInstalled == false {
                    self.statusMessage = "The Trame Ping Pong app is not installed on this Garmin."
                }
            }
        }
    }

    private func currentWorkoutSnapshot(now: Date = .now) -> WatchCompanionWorkoutSnapshot? {
        guard let container else { return nil }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        guard let workout = (try? context.fetch(descriptor))?
            .first(where: { $0.status == .active }) else { return nil }
        return .build(
            projection: LiveActivityProjection(workout: workout, now: now),
            isWorkoutCompleted: false,
            connection: connectionState == .connected ? .reachable : .offline,
            now: now
        )
    }

    private func publishWorkoutSnapshot(correlationID: String = "") {
        guard let snapshot = currentWorkoutSnapshot() else { return }
        sendWorkoutMessage(
            GarminWorkoutProtocol.snapshotEnvelope(
                snapshot,
                correlationID: correlationID,
                currentSet: currentSetProjection(for: snapshot)
            ),
            correlationID: correlationID
        )
    }

    private func currentSetProjection(
        for snapshot: WatchCompanionWorkoutSnapshot
    ) -> GarminWorkoutProtocol.CurrentSetProjection? {
        guard let container,
              let exerciseIndex = snapshot.currentExerciseOrderIndex,
              let setIndex = snapshot.currentSetOrderIndex
        else { return nil }
        let workoutID = snapshot.workoutID
        var descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == workoutID })
        descriptor.fetchLimit = 1
        guard let workout = (try? ModelContext(container).fetch(descriptor))?.first,
              let entry = workout.exercises.first(where: { $0.orderIndex == exerciseIndex }),
              let set = entry.sets.first(where: { $0.orderIndex == setIndex })
        else { return nil }
        return .init(
            trackingType: entry.trackingTypeSnapshot.rawValue,
            prescribedRepetitions: set.prescribedRepetitions,
            prescribedRepRangeMinimum: set.prescribedRepRangeMinimum,
            prescribedRepRangeMaximum: set.prescribedRepRangeMaximum,
            prescribedLoad: set.prescribedSuggestedLoad,
            prescribedLoadUnit: set.prescribedSuggestedLoadType?.rawValue,
            performedRepetitions: Double(set.repetitions),
            performedLoad: Double(set.weight),
            performedLoadUnit: set.weightType.rawValue,
            isCompleted: set.done
        )
    }

    private func processWorkoutCommand(_ command: WatchCompanionCommandEnvelope, correlationID: String) {
        guard let container else {
            sendWorkoutMessage(
                GarminWorkoutProtocol.errorEnvelope(code: "phoneUnavailable", detail: "Workout storage is unavailable.", correlationID: correlationID),
                correlationID: correlationID
            )
            return
        }
        let receipt = WatchCompanionCommandProcessor.process(
            command,
            existingReceipts: workoutReceipts,
            connection: .reachable,
            using: ModelContext(container)
        )
        if receipt.outcome != .queuedOffline {
            workoutReceipts.removeAll { $0.commandID == receipt.commandID }
            workoutReceipts.append(receipt)
            workoutReceipts = Array(workoutReceipts.suffix(200))
            saveWorkoutReceipts()
        }
        sendWorkoutMessage(
            GarminWorkoutProtocol.receiptEnvelope(receipt, correlationID: correlationID),
            correlationID: correlationID
        )
        publishWorkoutSnapshot(correlationID: correlationID)
    }

    private func sendWorkoutMessage(_ message: NSArray, correlationID _: String) {
        guard let watchApp, connectionState == .connected else { return }
        sdk.sendMessage(message, to: watchApp, progress: nil) { result in
            guard result != .success else { return }
            Task { @MainActor [weak self] in
                self?.statusMessage = "Garmin workout reply failed (\(Self.sendResultDescription(result))); the watch will retry."
            }
        }
    }

    private var workoutReceiptURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshotStore.appGroupIdentifier)?
            .appendingPathComponent("garmin-command-receipts.json")
    }

    private func loadWorkoutReceipts() -> [WatchCompanionCommandReceipt] {
        guard let workoutReceiptURL, let data = try? Data(contentsOf: workoutReceiptURL) else { return [] }
        return (try? JSONDecoder().decode([WatchCompanionCommandReceipt].self, from: data)) ?? []
    }

    private func saveWorkoutReceipts() {
        guard let workoutReceiptURL, let data = try? JSONEncoder().encode(workoutReceipts) else { return }
        try? data.write(to: workoutReceiptURL, options: [.atomic, .completeFileProtection])
    }

    private func displayName(for device: IQDevice) -> String {
        let candidates: [String?] = [device.friendlyName, device.modelName, device.partNumber]
        for name in candidates {
            let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty, trimmed.caseInsensitiveCompare("Unknown") != .orderedSame {
                return trimmed
            }
        }
        return "Garmin"
    }

    private func isMessageFromRegisteredWatchApp(_ app: IQApp) -> Bool {
        if app.uuid == Self.watchAppID { return true }
        if app.storeUuid == Self.watchAppID { return true }
        if let selectedDevice, app.device.uuid == selectedDevice.uuid {
            return true
        }
        return false
    }

    private static func sendResultDescription(_ result: IQSendMessageResult) -> String {
        if result == .success { return "success" }
        let label = NSStringFromSendMessageResult(result) as String
        if label.isEmpty || label.caseInsensitiveCompare("Unknown") == .orderedSame {
            return "Garmin transport error"
        }
        return label
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
            guard isMessageFromRegisteredWatchApp(app) else {
                statusMessage = "Rejected a message from a different Garmin app."
                return
            }
            if let envelope = GarminWorkoutProtocol.decodeEnvelope(message) {
                switch envelope.type {
                case "ack":
                    if pendingPings.contains(where: {
                        $0.id.caseInsensitiveCompare(envelope.correlationID) == .orderedSame
                    }) {
                        statusMessage = "Watch received the ping. Waiting for pong…"
                    }
                case "requestSnapshot":
                    guard envelope.correlationID.isEmpty, envelope.payload.isEmpty else {
                        sendWorkoutMessage(
                            GarminWorkoutProtocol.errorEnvelope(code: "invalidRequest", detail: "Malformed snapshot request.", correlationID: envelope.messageID),
                            correlationID: envelope.messageID
                        )
                        return
                    }
                    if currentWorkoutSnapshot() == nil {
                        sendWorkoutMessage(
                            GarminWorkoutProtocol.errorEnvelope(code: "noActiveWorkout", detail: "No active workout is available.", correlationID: envelope.messageID),
                            correlationID: envelope.messageID
                        )
                    } else {
                        publishWorkoutSnapshot(correlationID: envelope.messageID)
                    }
                case "command":
                    guard let command = GarminWorkoutProtocol.decodeCommand(from: envelope) else {
                        sendWorkoutMessage(
                            GarminWorkoutProtocol.errorEnvelope(code: "invalidCommand", detail: "Malformed workout command.", correlationID: envelope.messageID),
                            correlationID: envelope.messageID
                        )
                        return
                    }
                    processWorkoutCommand(command, correlationID: envelope.messageID)
                case "error":
                    let code = GarminPingPongProtocol.connectIQString(envelope.payload.first) ?? "error"
                    let detail = envelope.payload.count > 1
                        ? GarminPingPongProtocol.connectIQString(envelope.payload[1])
                        : nil
                    statusMessage = detail.map { "Garmin rejected the message (\($0))." }
                        ?? "Garmin rejected the message (\(code))."
                default:
                    break
                }
                if envelope.type != "pong" { return }
            }
            guard let matchedID = pendingPings.lazy.compactMap({
                GarminPingPongProtocol.matchingPongID(from: message, expectedPingID: $0.id)
            }).first else {
                statusMessage = "Received an invalid or stale Garmin reply."
                return
            }
            pendingPings.removeAll { $0.id == matchedID }
            persistPendingPings()
            retryTask?.cancel()
            lastPongAt = .now
            statusMessage = "Pong received locally from \(selectedDeviceName ?? "Garmin")."
            transmitNextPendingPing()
        }
    }
}
