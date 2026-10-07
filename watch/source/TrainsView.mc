import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

//! Main widget view: route header and the next departures.
//!   08:42   7 мин  → 09:05
//! Light-on-dark, system fonts, numbers first (UX guidelines for MIP).
class TrainsView extends WatchUi.View {
    private const ROWS = 4;

    private var _flipped as Boolean = false;
    private var _status as String = "";
    private var _timer as Timer.Timer = new Timer.Timer();

    public function initialize() {
        View.initialize();
    }

    public function onShow() as Void {
        // Minutes-to-departure change once a minute; 30 s keeps them current.
        _timer.start(method(:tick), 30000, true);
    }

    public function onHide() as Void {
        _timer.stop();
    }

    public function tick() as Void {
        WatchUi.requestUpdate();
    }

    public function flip() as Void {
        _flipped = !_flipped;
        WatchUi.requestUpdate();
    }

    public function setStatus(status as String) as Void {
        _status = status;
        WatchUi.requestUpdate();
    }

    public function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        if (!Schedule.isConfigured()) {
            drawCentered(dc, cx, h / 2, Graphics.FONT_SMALL,
                WatchUi.loadResource($.Rez.Strings.NoStations) as String, Graphics.COLOR_WHITE);
            return;
        }

        var toWork = Departures.towardWork(_flipped);
        var titles = Departures.titles(toWork);
        drawCentered(dc, cx, h * 15 / 100, Graphics.FONT_XTINY, titles[0], Graphics.COLOR_LT_GRAY);
        drawCentered(dc, cx, h * 24 / 100, Graphics.FONT_TINY, "→ " + titles[1], Graphics.COLOR_WHITE);

        var trains = Departures.upcoming(toWork, ROWS);
        if (trains == null || trains.size() == 0) {
            var msg = trains == null ? $.Rez.Strings.NoData : $.Rez.Strings.NoTrains;
            drawCentered(dc, cx, h / 2, Graphics.FONT_SMALL,
                WatchUi.loadResource(msg) as String, Graphics.COLOR_WHITE);
        } else {
            drawRows(dc, w, h, trains);
        }

        if (_status.length() > 0) {
            drawCentered(dc, cx, h * 88 / 100, Graphics.FONT_XTINY, _status, Graphics.COLOR_LT_GRAY);
        }
    }

    private function drawRows(dc as Dc, w as Number, h as Number, trains as Array<Array<Number> >) as Void {
        var now = Departures.nowMinutes();
        var top = h * 36 / 100;
        var step = h * 12 / 100;
        var minLabel = WatchUi.loadResource($.Rez.Strings.Min) as String;
        var expLabel = WatchUi.loadResource($.Rez.Strings.Express) as String;

        for (var i = 0; i < trains.size(); i++) {
            var dep = trains[i][0];
            var y = top + i * step;
            var first = i == 0;
            var font = first ? Graphics.FONT_MEDIUM : Graphics.FONT_SMALL;

            dc.setColor(first ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 16 / 100, y, font, Departures.hhmm(dep),
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

            var wait = dep - now;
            var mid = wait < 60 ? wait + " " + minLabel : "→ " + Departures.hhmm(dep + trains[i][1]);
            dc.setColor(wait <= 5 ? Graphics.COLOR_ORANGE : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 84 / 100, y, Graphics.FONT_XTINY, mid,
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

            if (trains[i][2] != 0) {
                dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w * 15 / 100, y, Graphics.FONT_XTINY, expLabel + " ",
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }
    }

    private function drawCentered(dc as Dc, x as Number, y as Number, font as FontType,
                                  text as String, color as ColorType) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
