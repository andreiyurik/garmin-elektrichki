import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

//! Settings and the on-device schedule cache.
//!
//! One Storage entry per day ("d:YYYY-MM-DD"), as returned by the proxy (v2):
//!   {"a": title, "b": title, "ab": [dep, dur, flags, terminal, platform, ...],
//!    "ba": [...], "s": [strings], "r": routeKey, "t": fetchedAtEpochSeconds}
//! The last failed fetch is kept in "err" as {"k": kind, "d": detail, "r": routeKey}
//! so the views can explain it.
//! Storage limits (Persisting Data docs): 8 KB per value, 128 KB total;
//! one day for one route is ~2-4 KB.
(:background, :glance)
module Schedule {
    const DAYS_AHEAD = 3;
    const STALE_SECONDS = 12 * 60 * 60;
    const STRIDE = 5;
    const FORMAT = 2;
    // Flags only mark express kinds (proxy compact.js): 0 = regular train.
    const FLAG_EXPRESS = 1;

    // Kinds of the last fetch error.
    enum {
        ERROR_PHONE = 1,   // no phone / Bluetooth / timeout: try again later
        ERROR_SERVER = 2,  // the proxy answered with an error or bad data
        ERROR_STATION = 3  // a station name was not found; detail = the name
    }

    function home() as String {
        return Properties.getValue("HomeStation") as String;
    }

    function work() as String {
        return Properties.getValue("WorkStation") as String;
    }

    function switchHour() as Number {
        return Properties.getValue("SwitchHour") as Number;
    }

    function walkMinutes() as Number {
        return Properties.getValue("WalkMinutes") as Number;
    }

    function hideExpress() as Boolean {
        return Properties.getValue("HideExpress") as Boolean;
    }

    function proxyUrl() as String {
        return Properties.getValue("ProxyUrl") as String;
    }

    function isConfigured() as Boolean {
        return home().length() > 0 && work().length() > 0;
    }

    //! Cached days are tied to the stations they were fetched for.
    function routeKey() as String {
        return home() + "|" + work();
    }

    //! "2026-10-07" for today + dayOffset, device local time.
    function dateString(dayOffset as Number) as String {
        return dateOf(Time.today().add(new Time.Duration(dayOffset * Gregorian.SECONDS_PER_DAY)));
    }

    function dateOf(moment as Time.Moment) as String {
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        return Lang.format("$1$-$2$-$3$", [
            info.year,
            (info.month as Number).format("%02d"),
            info.day.format("%02d")
        ]);
    }

    function load(date as String) as Dictionary? {
        var day = Storage.getValue("d:" + date);
        if (!(day instanceof Dictionary)) {
            return null;
        }
        var version = day["v"];
        if (version instanceof Number && version == FORMAT && routeKey().equals(day["r"])) {
            return day as Dictionary;
        }
        return null;
    }

    //! Checks a proxy response before it is stored, so a changed or broken
    //! response becomes an error message instead of a crash in the views.
    function isValid(day as Dictionary) as Boolean {
        var version = day["v"];
        var strings = day["s"];
        if (!(version instanceof Number) || version != FORMAT
            || !(day["a"] instanceof String) || !(day["b"] instanceof String)
            || !(strings instanceof Array)) {
            return false;
        }
        for (var i = 0; i < strings.size(); i++) {
            if (!(strings[i] instanceof String)) {
                return false;
            }
        }
        return isValidTrains(day["ab"] as Object?, strings.size())
            && isValidTrains(day["ba"] as Object?, strings.size());
    }

    function isValidTrains(trains as Object?, stringCount as Number) as Boolean {
        if (!(trains instanceof Array) || trains.size() % STRIDE != 0) {
            return false;
        }
        for (var i = 0; i < trains.size(); i++) {
            var value = trains[i];
            if (!(value instanceof Number) || value < 0) {
                return false;
            }
            var field = i % STRIDE;
            if (field >= 3 && value >= stringCount) {
                return false;
            }
        }
        return true;
    }

    function save(date as String, day as Dictionary, now as Number) as Void {
        day["r"] = routeKey();
        day["t"] = now;
        Storage.setValue("d:" + date, day as Dictionary<Storage.KeyType, Storage.ValueType>);
        Storage.deleteValue("err");
    }

    function saveError(kind as Number, detail as String) as Void {
        Storage.setValue("err", { "k" => kind, "d" => detail, "r" => routeKey() });
    }

    //! The last error for the current stations, or null.
    function lastError() as Dictionary? {
        var err = Storage.getValue("err");
        if (err instanceof Dictionary && routeKey().equals(err["r"])) {
            return err as Dictionary;
        }
        return null;
    }

    //! First date in [today, today + DAYS_AHEAD) that is missing or stale, or null.
    //! now: epoch seconds (Time.now().value()).
    function nextDateToFetch(now as Number) as String? {
        if (!isConfigured()) {
            return null;
        }
        for (var i = 0; i < DAYS_AHEAD; i++) {
            var date = dateString(i);
            var day = load(date);
            if (day == null || now - (day["t"] as Number) > STALE_SECONDS) {
                return date;
            }
        }
        return null;
    }

    //! Drops the past week's days; older ones were pruned on earlier runs.
    function prune() as Void {
        for (var i = 1; i <= 7; i++) {
            Storage.deleteValue("d:" + dateString(-i));
        }
    }
}
