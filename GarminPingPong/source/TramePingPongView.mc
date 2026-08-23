using Toybox.Application;
using Toybox.Graphics;
using Toybox.WatchUi;

class TramePingPongView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) {
        var app = Application.getApp() as TramePingPongApp;
        var centerX = dc.getWidth() / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, dc.getHeight() * 0.28, Graphics.FONT_LARGE, "TRAME", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, dc.getHeight() * 0.47, Graphics.FONT_MEDIUM, app.status, Graphics.TEXT_JUSTIFY_CENTER);

        if (app.lastPingId != null) {
            var shortId = app.lastPingId.substring(0, 8);
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, dc.getHeight() * 0.63, Graphics.FONT_SMALL, shortId, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, dc.getHeight() * 0.79, Graphics.FONT_TINY, "Local Bluetooth test", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
