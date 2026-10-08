import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Picks the next trains from the cached schedule and describes problems.
//! No network access.
(:glance)
module Departures {
    // Train fields returned by upcoming().
    enum {
        DEP,
        DUR,
        FLAGS,
        TERMINAL,
        PLATFORM
    }

    function nowMinutes() as Number {
        var clock = System.getClockTime();
        return clock.hour * 60 + clock.min;
    }

    //! true = home -> work. Automatic by SwitchHour, inverted by START.
    function towardWork(flipped as Boolean, now as Number) as Boolean {
        var morning = now / 60 < Schedule.switchHour();
        return morning != flipped;
    }

    //! [fromTitle, toTitle] as resolved by the proxy, or the raw settings.
    function titles(toWork as Boolean) as [String, String] {
        var day = Schedule.load(Schedule.dateString(0));
        var a = Schedule.home();
        var b = Schedule.work();
        if (day != null) {
            a = day["a"] as String;
            b = day["b"] as String;
        }
        return toWork ? [a, b] : [b, a];
    }

    //! Up to `count` trains departing at or after `now` (minutes since
    //! midnight), as
    //! [departureMinute, durationMinutes, flags, terminal, platform].
    //! departureMinute counts from today's midnight; tomorrow's trains get
    //! +1440 so the list continues past the last train of the day.
    //! Returns null when no schedule is cached for today.
    function upcoming(toWork as Boolean, count as Number, now as Number) as Array<Array>? {
        var today = Schedule.load(Schedule.dateString(0));
        if (today == null) {
            return null;
        }
        var result = [] as Array<Array>;
        collect(today, toWork, now, 0, count, result);
        today = null; // the glance has 32 KB: never hold two days at once
        if (result.size() < count) {
            var tomorrow = Schedule.load(Schedule.dateString(1));
            if (tomorrow != null) {
                collect(tomorrow, toWork, 0, 24 * 60, count, result);
            }
        }
        return result;
    }

    function collect(day as Dictionary, toWork as Boolean, fromMinute as Number, shift as Number,
                     count as Number, out as Array<Array>) as Void {
        var trains = day[toWork ? "ab" : "ba"] as Array<Number>;
        var strings = day["s"] as Array<String>;
        var hideExpress = Schedule.hideExpress();
        var stride = Schedule.STRIDE;
        for (var i = 0; i + stride - 1 < trains.size() && out.size() < count; i += stride) {
            if (trains[i] >= fromMinute && !(hideExpress && trains[i + 2] != 0)) {
                out.add([trains[i] + shift, trains[i + 1], trains[i + 2],
                         strings[trains[i + 3]], strings[trains[i + 4]]]);
            }
        }
    }

    //! Minutes until the user should leave for this train (negative = missed).
    //! With walk = 0 this is simply minutes to departure.
    function leaveIn(dep as Number, now as Number, walk as Number) as Number {
        return dep - walk - now;
    }

    //! Index of the first train the user can still catch, or -1.
    function firstCatchable(trains as Array<Array>, now as Number, walk as Number) as Number {
        for (var i = 0; i < trains.size(); i++) {
            if (leaveIn(trains[i][DEP] as Number, now, walk) >= 0) {
                return i;
            }
        }
        return -1;
    }

    //! The last failed fetch as [title, detail], or null.
    //! ["Станция не найдена:", "Одинцвоо"] or ["Нет связи с телефоном", "-104"].
    function error() as [String, String]? {
        var err = Schedule.lastError();
        if (err == null) {
            return null;
        }
        var kind = err["k"];
        var title = $.Rez.Strings.ServerError;
        if (kind == Schedule.ERROR_PHONE) {
            title = $.Rez.Strings.NoPhone;
        } else if (kind == Schedule.ERROR_STATION) {
            title = $.Rez.Strings.NotFound;
        }
        return [WatchUi.loadResource(title) as String, err["d"] as String];
    }

    function hhmm(minute as Number) as String {
        var m = minute % (24 * 60);
        return (m / 60).format("%02d") + ":" + (m % 60).format("%02d");
    }
}
