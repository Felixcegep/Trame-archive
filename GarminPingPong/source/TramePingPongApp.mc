using Toybox.Application;
using Toybox.Application.Storage;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.System;
using Toybox.Time;
using Toybox.Timer;
using Toybox.WatchUi;

class TramePingPongApp extends Application.AppBase {
    const PROTOCOL_MARKER = "trame";
    const PROTOCOL_VERSION = 2;
    const MAX_OUTBOX_SIZE = 8;
    const MAX_COMMANDS = 6;
    const MAX_RECENT_IDS = 12;
    const MAX_ATTEMPTS = 6;
    const RETRY_DELAY_MS = 5000;
    const OUTBOX_KEY = "trame.outbox.v2";
    const RECENT_IDS_KEY = "trame.recent.v2";
    const COMMANDS_KEY = "trame.commands.v2";
    const SEQUENCE_KEY = "trame.sequence.v2";

    var status = "Ready v2";
    var lastPingId = null;
    var diagnostic = "";
    var outbox = [];
    var recentPingIds = [];
    var isTransmitting = false;
    var retryTimer = null;
    var messageSequence = 0;
    var commandOutbox = [];
    var commandSequence = 0;
    var workoutId = "";
    var snapshotId = "";
    var exerciseName = "";
    var currentSet = -1;
    var totalSets = -1;
    var exerciseIndex = -1;
    var setIndex = -1;
    var hasAnySets = false;
    var restPhase = "none";
    var restEndAtMs = -1;
    var pausedRemainingMs = -1;
    var workoutCompleted = false;
    var trackingType = "";
    var prescribedReps = -1;
    var prescribedRepMin = -1;
    var prescribedRepMax = -1;
    var prescribedLoad = -1.0;
    var prescribedLoadUnit = "";
    var performedReps = -1.0;
    var performedLoad = -1.0;
    var performedLoadUnit = "";
    var setCompleted = false;
    var syncState = "queued";

    function initialize() { AppBase.initialize(); }

    function onStart(state) {
        restoreState();
        Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
        System.println("TRAME protocol v2 started; pending=" + outbox.size());
        if (commandOutbox.size() == 0) { issueCommand("requestSnapshot"); }
        transmitNext();
    }

    function onStop(state) {
        Communications.registerForPhoneAppMessages(null);
        stopRetryTimer();
        persistState();
    }

    function getInitialView() { return [new TramePingPongView(), new TrameWorkoutDelegate()]; }

    function onPhoneMessage(message as Communications.PhoneAppMessage) as Void {
        var data = message.data;
        diagnostic = "";

        if (data instanceof Lang.Array) {
            var values = data as Lang.Array;
            if (values.size() > 0 && values[0] instanceof Lang.String && values[0] == PROTOCOL_MARKER) {
                handleVersionedMessage(values);
                return;
            }
            if (handleLegacyArray(values)) { return; }
        } else if (data instanceof Lang.String) {
            if (handleLegacyString(data as Lang.String)) { return; }
        } else if (data instanceof Lang.Dictionary) {
            if (handleLegacyDictionary(data as Lang.Dictionary)) { return; }
        }

        rejectMessage("malformed", "Unsupported envelope", "");
    }

    function isNumeric(value) {
        return value instanceof Lang.Number;
    }

    function handleVersionedMessage(values) {
        if (values.size() < 4) {
            rejectMessage("malformed", "Expected at least 4 fields", "");
            return;
        }
        if (!isNumeric(values[1]) ||
            !(values[2] instanceof Lang.String) ||
            !(values[3] instanceof Lang.String)) {
            rejectMessage("malformed", "Invalid field types", "");
            return;
        }
        var version = values[1] as Lang.Number;
        var type = values[2] as Lang.String;
        var messageId = values[3] as Lang.String;
        var correlationId = "";
        if (values.size() > 4 && values[4] instanceof Lang.String) {
            correlationId = values[4] as Lang.String;
        }
        if (messageId.length() == 0) {
            rejectMessage("missing_id", "messageID is required", "");
            return;
        }
        if (version.toNumber() != PROTOCOL_VERSION) {
            rejectMessage("unsupported_version", "Watch supports v2", messageId);
            return;
        }
        if (type == "ping") {
            acceptVersionedPing(messageId);
            return;
        }
        if (values.size() < 6 || !(values[5] instanceof Lang.Array)) {
            rejectMessage("malformed", "Invalid field types", messageId);
            return;
        }
        if (type == "snapshot") {
            handleSnapshot(values[5] as Lang.Array, messageId, correlationId);
            return;
        }
        if (type == "receipt") { handleReceipt(values[5] as Lang.Array, correlationId); return; }
        if (type == "error") { handleRemoteError(values[5] as Lang.Array, correlationId); return; }
        rejectMessage("unsupported_type", "Unsupported message", messageId);
    }

    function acceptVersionedPing(messageId) {
        lastPingId = messageId;
        status = containsRecentId(messageId) ? "Duplicate ping" : "Ping received";
        syncState = "applied";
        diagnostic = "";
        // ACK confirms parsing. Pong remains the application result.
        enqueueEnvelope("ack", messageId, []);
        if (!containsRecentId(messageId)) { rememberPingId(messageId); }
        enqueueEnvelope("pong", messageId, []);
        WatchUi.requestUpdate();
        transmitNext();
    }

    function handleSnapshot(payload, messageId, correlationId) {
        if (payload.size() < 14 || !(payload[0] instanceof Lang.String) ||
            !(payload[1] instanceof Lang.String) || !(payload[4] instanceof Lang.String) ||
            !(payload[5] instanceof Lang.Number) || !(payload[6] instanceof Lang.Number) ||
            !(payload[7] instanceof Lang.Number) || !(payload[8] instanceof Lang.Number) ||
            !(payload[9] instanceof Lang.Boolean) || !(payload[10] instanceof Lang.String) ||
            !(payload[11] instanceof Lang.Number) || !(payload[12] instanceof Lang.Number) ||
            !(payload[13] instanceof Lang.Boolean)) {
            rejectMessage("malformed_snapshot", "Invalid snapshot payload", messageId);
            return;
        }
        snapshotId = payload[0] as Lang.String;
        workoutId = payload[1] as Lang.String;
        exerciseName = payload[4] as Lang.String;
        currentSet = payload[5] as Lang.Number;
        totalSets = payload[6] as Lang.Number;
        exerciseIndex = payload[7] as Lang.Number;
        setIndex = payload[8] as Lang.Number;
        hasAnySets = payload[9] as Lang.Boolean;
        restPhase = payload[10] as Lang.String;
        restEndAtMs = payload[11] as Lang.Number;
        pausedRemainingMs = payload[12] as Lang.Number;
        workoutCompleted = payload[13] as Lang.Boolean;
        // A legacy 14-field snapshot must clear rather than retain detail
        // projected by an earlier extended snapshot.
        trackingType = "";
        prescribedReps = -1;
        prescribedRepMin = -1;
        prescribedRepMax = -1;
        prescribedLoad = -1.0;
        prescribedLoadUnit = "";
        performedReps = -1.0;
        performedLoad = -1.0;
        performedLoadUnit = "";
        setCompleted = false;
        if (payload.size() >= 24 && payload[14] instanceof Lang.String &&
            payload[15] instanceof Lang.Number && payload[16] instanceof Lang.Number &&
            payload[17] instanceof Lang.Number && payload[18] instanceof Lang.Number &&
            payload[19] instanceof Lang.String && payload[20] instanceof Lang.Number &&
            payload[21] instanceof Lang.Number && payload[22] instanceof Lang.String &&
            payload[23] instanceof Lang.Boolean) {
            trackingType = payload[14] as Lang.String;
            prescribedReps = payload[15] as Lang.Number;
            prescribedRepMin = payload[16] as Lang.Number;
            prescribedRepMax = payload[17] as Lang.Number;
            prescribedLoad = payload[18] as Lang.Number;
            prescribedLoadUnit = payload[19] as Lang.String;
            performedReps = payload[20] as Lang.Number;
            performedLoad = payload[21] as Lang.Number;
            performedLoadUnit = payload[22] as Lang.String;
            setCompleted = payload[23] as Lang.Boolean;
        }
        status = workoutCompleted ? "Handoff iPhone" : "Workout synced";
        syncState = workoutCompleted ? "handoff" : "applied";
        diagnostic = "";
        if (correlationId.length() > 0) { removeCommand(correlationId); }
        WatchUi.requestUpdate();
    }

    function handleReceipt(payload, correlationId) {
        if (payload.size() < 7 || !(payload[0] instanceof Lang.String) ||
            !(payload[2] instanceof Lang.String) || !(payload[3] instanceof Lang.String) ||
            !(payload[4] instanceof Lang.String)) {
            rejectMessage("malformed_receipt", "Invalid receipt payload", correlationId);
            return;
        }
        var commandId = payload[0] as Lang.String;
        var commandKind = payload[2] as Lang.String;
        var outcome = payload[3] as Lang.String;
        if (correlationId != commandId) {
            diagnostic = "receipt_correlation";
            status = "Receipt rejected";
            syncState = "conflict";
            WatchUi.requestUpdate();
            return;
        }
        removeCommand(commandId);
        if (outcome == "applied" || outcome == "duplicate") {
            syncState = "applied";
            status = outcome == "duplicate" ? "Already applied" : "Applied";
        } else if (outcome == "queuedOffline") {
            syncState = "queued";
            status = "Queued on iPhone";
        } else if (outcome == "handoffRequired") {
            syncState = "handoff";
            status = "Continue on iPhone";
        } else {
            syncState = "conflict";
            diagnostic = payload[4] as Lang.String;
            status = outcome == "stale" ? "Snapshot stale" : "Conflict";
        }
        WatchUi.requestUpdate();
        if ((outcome == "applied" || outcome == "duplicate") && commandKind != "requestSnapshot") {
            issueCommand("requestSnapshot");
        }
        transmitNext();
    }

    function handleRemoteError(payload, correlationId) {
        removeCommand(correlationId);
        syncState = "conflict";
        diagnostic = payload.size() > 0 ? payload[0].toString() : "remote_error";
        status = "Phone rejected";
        WatchUi.requestUpdate();
        transmitNext();
    }

    function issueCommand(kind) {
        if (kind == "requestSnapshot") {
            if (hasPendingCommand("requestSnapshot")) {
                status = "Snapshot already queued";
                syncState = "queued";
                WatchUi.requestUpdate();
                return;
            }
            if (commandOutbox.size() >= MAX_COMMANDS) {
                status = "Sync queue full";
                syncState = "conflict";
                WatchUi.requestUpdate();
                return;
            }
            var requestId = nextCommandId();
            commandOutbox.add([[
                PROTOCOL_MARKER, PROTOCOL_VERSION, "requestSnapshot", requestId, "", []
            ], 0]);
            syncState = "queued";
            status = "Snapshot queued";
            persistState();
            WatchUi.requestUpdate();
            transmitNext();
            return;
        }
        if (kind != "requestSnapshot" && workoutId.length() == 0) {
            status = "Waiting for workout";
            syncState = "queued";
            WatchUi.requestUpdate();
            return;
        }
        if (kind == "completeWorkout") {
            status = "Continue on iPhone";
            syncState = "handoff";
            WatchUi.requestUpdate();
            return;
        }
        // Coalesce snapshot refreshes and serialize mutations. Two quick taps
        // must never advance two sets before the first receipt is reconciled.
        if (hasPendingCommand(null)) {
            status = "Command already queued";
            syncState = "queued";
            WatchUi.requestUpdate();
            return;
        }
        if (commandOutbox.size() >= MAX_COMMANDS) {
            status = "Sync queue full";
            syncState = "conflict";
            WatchUi.requestUpdate();
            return;
        }
        var commandId = nextCommandId();
        var payload = [commandId, workoutId, kind, Time.now().value() * 1000,
            exerciseIndex, setIndex, restPhase, 0, snapshotId];
        var envelope = [PROTOCOL_MARKER, PROTOCOL_VERSION, "command", commandId, "", payload];
        commandOutbox.add([envelope, 0]);
        syncState = "queued";
        status = "Command queued";
        persistState();
        WatchUi.requestUpdate();
        transmitNext();
    }

    function hasPendingCommand(requiredKind) {
        for (var index = 0; index < commandOutbox.size(); index += 1) {
            var entry = commandOutbox[index] as Lang.Array;
            var envelope = entry[0] as Lang.Array;
            var pendingKind = envelope[2] as Lang.String;
            if (pendingKind == "command") {
                var payload = envelope[5] as Lang.Array;
                pendingKind = payload[2] as Lang.String;
            }
            if (requiredKind == null || pendingKind == requiredKind) { return true; }
        }
        return false;
    }

    function nextCommandId() {
        commandSequence += 1;
        var suffix = (Time.now().value().toString() + commandSequence.toString());
        while (suffix.length() < 12) { suffix = "0" + suffix; }
        if (suffix.length() > 12) { suffix = suffix.substring(suffix.length() - 12, suffix.length()); }
        persistState();
        return "00000000-0000-4000-8000-" + suffix;
    }

    function removeCommand(commandId) {
        for (var index = commandOutbox.size() - 1; index >= 0; index -= 1) {
            var entry = commandOutbox[index] as Lang.Array;
            var envelope = entry[0] as Lang.Array;
            if (envelope[3] == commandId) { commandOutbox.remove(index); }
        }
        persistState();
    }

    function handleLegacyArray(values) {
        if (values.size() >= 2 && values[0] instanceof Lang.String &&
            values[1] instanceof Lang.String && values[0] == "ping") {
            acceptLegacyPing(values[1] as Lang.String);
            return true;
        }
        return false;
    }

    function handleLegacyString(envelope) {
        var prefix = "ping|";
        if (envelope.length() > prefix.length() && envelope.substring(0, prefix.length()) == prefix) {
            acceptLegacyPing(envelope.substring(prefix.length(), envelope.length()));
            return true;
        }
        return false;
    }

    function handleLegacyDictionary(dictionary) {
        if (dictionary["type"] == "ping" && dictionary["pingID"] instanceof Lang.String) {
            acceptLegacyPing(dictionary["pingID"] as Lang.String);
            return true;
        }
        return false;
    }

    function acceptLegacyPing(pingId) {
        if (pingId.length() == 0) {
            rejectMessage("missing_id", "pingID is required", "");
            return;
        }
        lastPingId = pingId;
        status = "Legacy ping";
        enqueue(["pong", pingId]);
        WatchUi.requestUpdate();
        transmitNext();
    }

    function rejectMessage(code, detail, correlationId) {
        diagnostic = code;
        status = "Message rejected";
        enqueueEnvelope("error", correlationId, [code, detail]);
        System.println("TRAME rejected " + code + ": " + detail);
        WatchUi.requestUpdate();
        transmitNext();
    }

    function enqueueEnvelope(type, correlationId, payload) {
        enqueue([PROTOCOL_MARKER, PROTOCOL_VERSION, type, nextMessageId(type), correlationId, payload]);
    }

    function nextMessageId(type) {
        // iOS validates every v2 envelope message ID as a canonical UUID.
        return nextCommandId();
    }

    // Entries are [payload, attemptCount]; only Connect IQ primitives persist.
    function enqueue(payload) {
        if (outbox.size() >= MAX_OUTBOX_SIZE) {
            // Never invalidate the listener's in-flight head entry. Under
            // pressure, discard the oldest waiting reply instead.
            outbox.remove(isTransmitting && outbox.size() > 1 ? 1 : 0);
        }
        outbox.add([payload, 0]);
        persistState();
    }

    function transmitNext() {
        if (isTransmitting) { return; }
        if (outbox.size() == 0 && commandOutbox.size() == 0) { return; }
        stopRetryTimer();
        var sendingReply = outbox.size() > 0;
        var entry = (sendingReply ? outbox[0] : commandOutbox[0]) as Lang.Array;
        var attempts = entry[1] as Lang.Number;
        if (attempts >= MAX_ATTEMPTS) {
            if (sendingReply) { outbox.remove(0); } else { commandOutbox.remove(0); }
            status = sendingReply ? "Reply expired" : "Command expired";
            syncState = "conflict";
            persistState();
            WatchUi.requestUpdate();
            transmitNext();
            return;
        }

        entry[1] = attempts + 1;
        isTransmitting = true;
        syncState = sendingReply ? syncState : "syncing";
        persistState();
        Communications.transmit(entry[0], null, new TrameTransmitListener(sendingReply));
    }

    function onTransmitComplete(wasReply) {
        isTransmitting = false;
        if (wasReply && outbox.size() > 0) { outbox.remove(0); }
        status = wasReply ? "Reply sent" : "Waiting for iPhone";
        persistState();
        WatchUi.requestUpdate();
        if (!wasReply) { scheduleRetry(); return; }
        transmitNext();
    }

    function onTransmitError() {
        isTransmitting = false;
        status = "Reply queued";
        persistState();
        WatchUi.requestUpdate();
        scheduleRetry();
    }

    function scheduleRetry() {
        stopRetryTimer();
        retryTimer = new Timer.Timer();
        (retryTimer as Timer.Timer).start(method(:retryPending), RETRY_DELAY_MS, false);
    }

    function retryPending() as Void {
        retryTimer = null;
        transmitNext();
    }

    function stopRetryTimer() {
        if (retryTimer != null) {
            (retryTimer as Timer.Timer).stop();
            retryTimer = null;
        }
    }

    function containsRecentId(pingId) {
        for (var index = 0; index < recentPingIds.size(); index += 1) {
            if (recentPingIds[index] == pingId) { return true; }
        }
        return false;
    }

    function rememberPingId(pingId) {
        recentPingIds.add(pingId);
        if (recentPingIds.size() > MAX_RECENT_IDS) { recentPingIds.remove(0); }
        persistState();
    }

    function restoreState() {
        var savedOutbox = Storage.getValue(OUTBOX_KEY);
        var savedIds = Storage.getValue(RECENT_IDS_KEY);
        var savedCommands = Storage.getValue(COMMANDS_KEY);
        var savedSequence = Storage.getValue(SEQUENCE_KEY);
        if (savedOutbox instanceof Lang.Array) { outbox = savedOutbox as Lang.Array; }
        if (savedIds instanceof Lang.Array) { recentPingIds = savedIds as Lang.Array; }
        if (savedCommands instanceof Lang.Array) { commandOutbox = savedCommands as Lang.Array; }
        if (savedSequence instanceof Lang.Number) { commandSequence = savedSequence as Lang.Number; }
        // A stopped in-flight entry remains pending and retries next launch.
        isTransmitting = false;
    }

    function persistState() {
        Storage.setValue(OUTBOX_KEY, outbox);
        Storage.setValue(RECENT_IDS_KEY, recentPingIds);
        Storage.setValue(COMMANDS_KEY, commandOutbox);
        Storage.setValue(SEQUENCE_KEY, commandSequence);
    }
}

class TrameTransmitListener extends Communications.ConnectionListener {
    var wasReply = true;
    function initialize(reply) { ConnectionListener.initialize(); wasReply = reply; }
    function onComplete() { (Application.getApp() as TramePingPongApp).onTransmitComplete(wasReply); }
    function onError() { (Application.getApp() as TramePingPongApp).onTransmitError(); }
}

class TrameWorkoutDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }

    function onSelect() as Lang.Boolean {
        var app = Application.getApp() as TramePingPongApp;
        if (app.workoutCompleted || !app.hasAnySets) { app.issueCommand("completeWorkout"); }
        else if (app.setCompleted) {
            app.status = "Set already completed";
            WatchUi.requestUpdate();
        }
        else { app.issueCommand("completeCurrentSet"); }
        return true;
    }

    function onNextPage() as Lang.Boolean {
        var app = Application.getApp() as TramePingPongApp;
        if (app.restPhase == "paused") { app.issueCommand("resumeRest"); }
        else if (app.restPhase == "running") { app.issueCommand("pauseRest"); }
        else { app.status = "No active rest"; WatchUi.requestUpdate(); }
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        var app = Application.getApp() as TramePingPongApp;
        if (app.restPhase == "running" || app.restPhase == "paused") { app.issueCommand("skipRest"); }
        else { app.status = "No active rest"; WatchUi.requestUpdate(); }
        return true;
    }

    function onMenu() as Lang.Boolean {
        (Application.getApp() as TramePingPongApp).issueCommand("requestSnapshot");
        return true;
    }
}
