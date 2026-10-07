import Toybox.Lang;
import Toybox.System;

//! Picks the next trains from the cached schedule. No network access.
(:glance)
module Departures {

    function nowMinutes() as Number {
        var clock = System.getClockTime();
        return clock.hour * 60 + clock.min;
    }

    //! true = home -> work. Automatic by SwitchHour, inverted by START.
    function towardWork(flipped as Boolean) as Boolean {
        var morning = System.getClockTime().hour < Schedule.switchHour();
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

    //! Up to `count` trains as [departureMinute, durationMinutes, flags].
    //! departureMinute counts from today's midnight; tomorrow's trains get
    //! +1440 so the list continues past the last train of the day.
    //! Returns null when no schedule is cached for today.
    function upcoming(toWork as Boolean, count as Number) as Array<Array<Number> >? {
        var key = toWork ? "ab" : "ba";
        var result = [] as Array<Array<Number> >;
        var today = Schedule.load(Schedule.dateString(0));
        if (today == null) {
            return null;
        }
        collect(today[key] as Array<Number>, nowMinutes(), 0, count, result);
        if (result.size() < count) {
            var tomorrow = Schedule.load(Schedule.dateString(1));
            if (tomorrow != null) {
                collect(tomorrow[key] as Array<Number>, 0, 24 * 60, count, result);
            }
        }
        return result;
    }

    function collect(trains as Array<Number>, fromMinute as Number, shift as Number,
                     count as Number, out as Array<Array<Number> >) as Void {
        for (var i = 0; i + 2 < trains.size() && out.size() < count; i += Schedule.STRIDE) {
            if (trains[i] >= fromMinute) {
                out.add([trains[i] + shift, trains[i + 1], trains[i + 2]]);
            }
        }
    }

    function hhmm(minute as Number) as String {
        var m = minute % (24 * 60);
        return (m / 60).format("%02d") + ":" + (m % 60).format("%02d");
    }
}
