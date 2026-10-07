import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Glance (API 3.1.0): destination and the next departure.
//! On fenix 6 the glance is redrawn by the system, not live (Glances docs),
//! so it only reads Storage and draws.
(:glance)
class TrainsGlanceView extends WatchUi.GlanceView {

    public function initialize() {
        GlanceView.initialize();
    }

    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var h = dc.getHeight();

        if (!Schedule.isConfigured()) {
            drawLine(dc, h / 2, Graphics.FONT_TINY, WatchUi.loadResource($.Rez.Strings.NoStations) as String);
            return;
        }

        var toWork = Departures.towardWork(false);
        var dest = Departures.titles(toWork)[1];
        var trains = Departures.upcoming(toWork, 1);
        var line;
        if (trains == null) {
            line = WatchUi.loadResource($.Rez.Strings.NoData) as String;
        } else if (trains.size() == 0) {
            line = WatchUi.loadResource($.Rez.Strings.NoTrains) as String;
        } else {
            var dep = trains[0][0];
            line = Departures.hhmm(dep) + " · " + (dep - Departures.nowMinutes()) + " "
                + WatchUi.loadResource($.Rez.Strings.Min);
        }
        drawLine(dc, h / 4, Graphics.FONT_TINY, "→ " + dest);
        drawLine(dc, 3 * h / 4, Graphics.FONT_SMALL, line);
    }

    private function drawLine(dc as Dc, y as Number, font as FontType, text as String) as Void {
        dc.drawText(0, y, font, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
