using Toybox.Application;
using Toybox.Graphics;
using Toybox.Time;
using Toybox.Timer;
using Toybox.WatchUi;

class TramePingPongView extends WatchUi.View {
    var refreshTimer = null;

    function initialize() { View.initialize(); }

    function onShow() {
        refreshTimer = new Timer.Timer();
        (refreshTimer as Timer.Timer).start(method(:refresh), 1000, true);
    }

    function onHide() {
        if (refreshTimer != null) {
            (refreshTimer as Timer.Timer).stop();
            refreshTimer = null;
        }
    }

    function refresh() as Void { WatchUi.requestUpdate(); }

    function onUpdate(dc) {
        var app = Application.getApp() as TramePingPongApp;
        var centerX = dc.getWidth() / 2;
        var height = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(stateColor(app.syncState), Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 0.08, Graphics.FONT_TINY,
            app.syncState.toUpper(), Graphics.TEXT_JUSTIFY_CENTER);

        if (app.workoutId.length() == 0) {
            drawWaiting(dc, app, centerX, height);
            return;
        }

        var exercise = app.exerciseName.length() == 0 ? "Current exercise" : app.exerciseName;
        if (exercise.length() > 22) { exercise = exercise.substring(0, 22); }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 0.22, Graphics.FONT_MEDIUM, exercise, Graphics.TEXT_JUSTIFY_CENTER);

        var setText = app.currentSet >= 0 && app.totalSets >= 0
            ? "Set " + app.currentSet + " / " + app.totalSets
            : "No current set";
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 0.37, Graphics.FONT_SMALL, setText, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 0.45, Graphics.FONT_TINY,
            prescriptionLabel(app), Graphics.TEXT_JUSTIFY_CENTER);

        var restText = restLabel(app);
        dc.setColor(app.restPhase == "ready" ? Graphics.COLOR_GREEN : Graphics.COLOR_YELLOW,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 0.56, Graphics.FONT_LARGE, restText, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 0.70, Graphics.FONT_TINY,
            app.workoutCompleted ? "Finish on iPhone" : "SELECT  Complete set",
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(centerX, height * 0.77, Graphics.FONT_TINY,
            "UP pause/resume · DOWN skip",
            Graphics.TEXT_JUSTIFY_CENTER);

        var footer = app.diagnostic.length() > 0 ? app.diagnostic : app.status;
        if (footer.length() > 28) { footer = footer.substring(0, 28); }
        dc.setColor(stateColor(app.syncState), Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 0.87, Graphics.FONT_TINY, footer, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawWaiting(dc, app, centerX, height) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 0.28, Graphics.FONT_LARGE, "TRAME", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 0.47, Graphics.FONT_SMALL, app.status, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(centerX, height * 0.64, Graphics.FONT_TINY,
            "MENU requests snapshot", Graphics.TEXT_JUSTIFY_CENTER);
        if (app.lastPingId != null) {
            var shortId = app.lastPingId;
            if (shortId.length() > 8) { shortId = shortId.substring(0, 8); }
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height * 0.78, Graphics.FONT_TINY, "Ping " + shortId,
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function restLabel(app) {
        if (app.restPhase == "running" && app.restEndAtMs >= 0) {
            var remaining = ((app.restEndAtMs / 1000) - Time.now().value()).toNumber();
            if (remaining < 0) { remaining = 0; }
            return formatDuration(remaining);
        }
        if (app.restPhase == "paused" && app.pausedRemainingMs >= 0) {
            return formatDuration((app.pausedRemainingMs / 1000).toNumber());
        }
        if (app.restPhase == "ready") { return "READY"; }
        return "—";
    }

    function prescriptionLabel(app) {
        var load = app.prescribedLoad >= 0
            ? app.prescribedLoad.format("%.1f") + " " + app.prescribedLoadUnit
            : "";
        var reps = "";
        if (app.prescribedReps >= 0) { reps = app.prescribedReps + " reps"; }
        else if (app.prescribedRepMin >= 0 && app.prescribedRepMax >= 0) {
            reps = app.prescribedRepMin + "–" + app.prescribedRepMax + " reps";
        }
        if (load.length() > 0 && reps.length() > 0) { return load + " · " + reps; }
        if (load.length() > 0) { return load; }
        if (reps.length() > 0) { return reps; }
        return app.trackingType.length() > 0 ? app.trackingType : "Prescription on iPhone";
    }

    function formatDuration(seconds) {
        var minutes = (seconds / 60).toNumber();
        var remainder = seconds % 60;
        return minutes + ":" + (remainder < 10 ? "0" : "") + remainder;
    }

    function stateColor(state) {
        if (state == "applied") { return Graphics.COLOR_GREEN; }
        if (state == "conflict" || state == "handoff") { return Graphics.COLOR_RED; }
        if (state == "syncing") { return Graphics.COLOR_YELLOW; }
        return Graphics.COLOR_LT_GRAY;
    }
}
