using Toybox.Application;
using Toybox.Communications;
using Toybox.System;
using Toybox.WatchUi;

class TramePingPongApp extends Application.AppBase {
    var status = "Waiting for iPhone";
    var lastPingId = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
    }

    function onStop(state) {
        Communications.registerForPhoneAppMessages(null);
    }

    function getInitialView() {
        return [new TramePingPongView()];
    }

    function onPhoneMessage(message) {
        var data = message.data;
        if (data == null || data["type"] != "ping") {
            status = "Unknown message";
            WatchUi.requestUpdate();
            return;
        }

        lastPingId = data["pingID"];
        status = "Ping received";
        WatchUi.requestUpdate();

        var pong = {
            "type" => "pong",
            "protocolVersion" => 1,
            "pingID" => lastPingId
        };
        Communications.transmit(pong, null, new TrameTransmitListener());
    }
}
class TrameTransmitListener extends Communications.ConnectionListener {
    function initialize() {
        ConnectionListener.initialize();
    }

    function onComplete() {
        var app = Application.getApp() as TramePingPongApp;
        app.status = "Pong sent";
        WatchUi.requestUpdate();
    }

    function onError() {
        var app = Application.getApp() as TramePingPongApp;
        app.status = "Pong queued";
        WatchUi.requestUpdate();
    }
}
