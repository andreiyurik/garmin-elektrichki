import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

//! Settings and the on-device schedule cache.
//!
//! One Storage entry per day ("d:YYYY-MM-DD"), as returned by the proxy:
//!   {"a": title, "b": title, "ab": [dep, dur, flags, ...], "ba": [...],
//!    "r": routeKey, "t": fetchedAtEpochSeconds}
//! Storage limits (Persisting Data docs): 8 KB per value, 128 KB total;
//! one day for one route is ~2-4 KB.
(:background, :glance)
module Schedule {
    const DAYS_AHEAD = 3;
    const STALE_SECONDS = 12 * 60 * 60;
    const STRIDE = 3;

    function home() as String {
        return Properties.getValue("HomeStation") as String;
    }

    function work() as String {
        return Properties.getValue("WorkStation") as String;
    }

    function switchHour() as Number {
        return Properties.getValue("SwitchHour") as Number;
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
        var moment = Time.today().add(new Time.Duration(dayOffset * Gregorian.SECONDS_PER_DAY));
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        return Lang.format("$1$-$2$-$3$", [
            info.year,
            (info.month as Number).format("%02d"),
            info.day.format("%02d")
        ]);
    }

    function load(date as String) as Dictionary? {
        var day = Storage.getValue("d:" + date);
        if (day instanceof Dictionary && routeKey().equals(day["r"])) {
            return day as Dictionary;
        }
        return null;
    }

    function save(date as String, day as Dictionary) as Void {
        day["r"] = routeKey();
        day["t"] = Time.now().value();
        Storage.setValue("d:" + date, day as Dictionary<Storage.KeyType, Storage.ValueType>);
    }

    //! First date in [today, today + DAYS_AHEAD) that is missing or stale, or null.
    function nextDateToFetch() as String? {
        if (!isConfigured()) {
            return null;
        }
        var now = Time.now().value();
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
