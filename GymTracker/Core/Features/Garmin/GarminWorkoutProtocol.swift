import Foundation

nonisolated enum GarminWorkoutProtocol {
    struct CurrentSetProjection: Equatable, Sendable {
        let trackingType: String
        let prescribedRepetitions: Int?
        let prescribedRepRangeMinimum: Int?
        let prescribedRepRangeMaximum: Int?
        let prescribedLoad: Double?
        let prescribedLoadUnit: String?
        let performedRepetitions: Double
        let performedLoad: Double
        let performedLoadUnit: String
        let isCompleted: Bool
    }

    struct Envelope {
        let type: String
        let messageID: String
        let correlationID: String
        let payload: [Any]
    }

    static func decodeEnvelope(_ value: Any) -> Envelope? {
        guard let values = GarminPingPongProtocol.connectIQArray(from: value), values.count == 6,
              GarminPingPongProtocol.connectIQString(values[0]) == "trame",
              GarminPingPongProtocol.connectIQInt(values[1]) == GarminPingPongProtocol.version,
              let type = GarminPingPongProtocol.connectIQString(values[2]),
              let messageID = GarminPingPongProtocol.connectIQString(values[3]),
              UUID(uuidString: messageID) != nil,
              let correlationID = GarminPingPongProtocol.connectIQString(values[4]),
              let payload = GarminPingPongProtocol.connectIQArray(from: values[5])
        else { return nil }
        return Envelope(type: type, messageID: messageID.lowercased(), correlationID: correlationID, payload: payload)
    }

    static func decodeCommand(from envelope: Envelope) -> WatchCompanionCommandEnvelope? {
        guard envelope.type == "command", envelope.correlationID.isEmpty,
              envelope.payload.count == 9,
              let commandIDString = envelope.payload[0] as? String,
              commandIDString.caseInsensitiveCompare(envelope.messageID) == .orderedSame,
              let commandID = UUID(uuidString: commandIDString),
              let workoutIDString = envelope.payload[1] as? String,
              let workoutID = UUID(uuidString: workoutIDString),
              let kindString = envelope.payload[2] as? String,
              let kind = WatchCompanionCommandKind(rawValue: kindString),
              let issuedAtMilliseconds = (envelope.payload[3] as? NSNumber)?.int64Value,
              let exerciseIndex = (envelope.payload[4] as? NSNumber)?.intValue,
              let setIndex = (envelope.payload[5] as? NSNumber)?.intValue,
              let restPhaseString = envelope.payload[6] as? String,
              let extensionSeconds = (envelope.payload[7] as? NSNumber)?.intValue,
              let snapshotID = envelope.payload[8] as? String
        else { return nil }
        guard restPhaseString.isEmpty || LiveActivityRestPhase(rawValue: restPhaseString) != nil else { return nil }
        let issuedAt = Date(timeIntervalSince1970: Double(issuedAtMilliseconds) / 1_000)
        guard issuedAt <= Date.now.addingTimeInterval(5 * 60),
              issuedAt >= Date.now.addingTimeInterval(-24 * 60 * 60),
              kind == .requestSnapshot || !snapshotID.isEmpty
        else { return nil }
        return WatchCompanionCommandEnvelope(
            commandID: commandID,
            workoutID: workoutID,
            kind: kind,
            issuedAt: issuedAt,
            expectedExerciseOrderIndex: exerciseIndex >= 0 ? exerciseIndex : nil,
            expectedSetOrderIndex: setIndex >= 0 ? setIndex : nil,
            expectedRestPhase: restPhaseString.isEmpty ? nil : LiveActivityRestPhase(rawValue: restPhaseString),
            restExtensionSeconds: extensionSeconds > 0 ? extensionSeconds : nil,
            expectedSnapshotID: snapshotID.isEmpty ? nil : snapshotID
        )
    }

    static func snapshotEnvelope(
        _ snapshot: WatchCompanionWorkoutSnapshot,
        messageID: UUID = UUID(),
        correlationID: String = "",
        currentSet: CurrentSetProjection? = nil
    ) -> NSArray {
        GarminPingPongProtocol.envelope(
            type: "snapshot",
            messageID: messageID.uuidString.lowercased(),
            correlationID: correlationID,
            payload: [
                snapshot.snapshotID as NSString,
                snapshot.workoutID.uuidString.lowercased() as NSString,
                milliseconds(snapshot.generatedAt),
                milliseconds(snapshot.startTime),
                (snapshot.currentExerciseName ?? "") as NSString,
                NSNumber(value: snapshot.currentSet ?? -1),
                NSNumber(value: snapshot.totalSets ?? -1),
                NSNumber(value: snapshot.currentExerciseOrderIndex ?? -1),
                NSNumber(value: snapshot.currentSetOrderIndex ?? -1),
                NSNumber(value: snapshot.hasAnySets),
                snapshot.restPhase.rawValue as NSString,
                snapshot.restEndDate.map(milliseconds) ?? NSNumber(value: -1),
                snapshot.pausedRemainingTime.map { NSNumber(value: Int64($0 * 1_000)) } ?? NSNumber(value: -1),
                NSNumber(value: snapshot.isWorkoutCompleted),
                (currentSet?.trackingType ?? "") as NSString,
                NSNumber(value: currentSet?.prescribedRepetitions ?? -1),
                NSNumber(value: currentSet?.prescribedRepRangeMinimum ?? -1),
                NSNumber(value: currentSet?.prescribedRepRangeMaximum ?? -1),
                NSNumber(value: currentSet?.prescribedLoad ?? -1),
                (currentSet?.prescribedLoadUnit ?? "") as NSString,
                NSNumber(value: currentSet?.performedRepetitions ?? -1),
                NSNumber(value: currentSet?.performedLoad ?? -1),
                (currentSet?.performedLoadUnit ?? "") as NSString,
                NSNumber(value: currentSet?.isCompleted ?? false)
            ]
        )
    }

    static func receiptEnvelope(
        _ receipt: WatchCompanionCommandReceipt,
        messageID: UUID = UUID(),
        correlationID: String
    ) -> NSArray {
        GarminPingPongProtocol.envelope(
            type: "receipt",
            messageID: messageID.uuidString.lowercased(),
            correlationID: correlationID,
            payload: [
                receipt.commandID.uuidString.lowercased() as NSString,
                receipt.workoutID.uuidString.lowercased() as NSString,
                receipt.kind.rawValue as NSString,
                receipt.outcome.rawValue as NSString,
                (receipt.reason?.rawValue ?? "") as NSString,
                milliseconds(receipt.recordedAt),
                (receipt.snapshotID ?? "") as NSString
            ]
        )
    }

    static func errorEnvelope(code: String, detail: String, correlationID: String) -> NSArray {
        GarminPingPongProtocol.envelope(
            type: "error",
            messageID: UUID().uuidString.lowercased(),
            correlationID: correlationID,
            payload: [code as NSString, detail as NSString]
        )
    }

    private static func milliseconds(_ date: Date) -> NSNumber {
        NSNumber(value: Int64(date.timeIntervalSince1970 * 1_000))
    }
}
