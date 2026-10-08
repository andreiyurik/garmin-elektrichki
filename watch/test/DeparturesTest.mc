import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.Test;

//! Departures: train selection, direction, "leave in" and formatting.

(:test)
function testHhmm(logger as Logger) as Boolean {
    return check(logger, Departures.hhmm(522).equals("08:42"), "08:42")
        && check(logger, Departures.hhmm(0).equals("00:00"), "midnight")
        && check(logger, Departures.hhmm(24 * 60 + 5).equals("00:05"), "tomorrow wraps");
}

(:test)
function testTowardWorkSwitchesAtSwitchHour(logger as Logger) as Boolean {
    resetState();
    return check(logger, Departures.towardWork(false, 12 * 60 + 59), "12:59 is morning")
        && check(logger, !Departures.towardWork(false, 13 * 60), "13:00 is evening")
        && check(logger, !Departures.towardWork(true, 8 * 60), "START flips morning")
        && check(logger, Departures.towardWork(true, 20 * 60), "START flips evening");
}

(:test)
function testLeaveInAndFirstCatchable(logger as Logger) as Boolean {
    var trains = [[595, 20, 0, "", ""], [605, 20, 0, "", ""], [620, 20, 0, "", ""]] as Array<Array>;
    return check(logger, Departures.leaveIn(600, 590, 5) == 5, "600 - 5 walk - 590")
        && check(logger, Departures.leaveIn(595, 590, 10) == -5, "missed is negative")
        && check(logger, Departures.firstCatchable(trains, 590, 10) == 1, "skips the missed 09:55")
        && check(logger, Departures.firstCatchable(trains, 590, 0) == 0, "no walk: first train")
        && check(logger, Departures.firstCatchable(trains, 615, 10) == -1, "nothing catchable");
}

(:test)
function testCollectResolvesStringsFromMinute(logger as Logger) as Boolean {
    resetState();
    var out = [] as Array<Array>;
    Departures.collect(sampleDay(), true, 525, 0, 5, out);
    if (!check(logger, out.size() == 1, "one train after 08:45")) {
        return false;
    }
    var t = out[0];
    return check(logger, (t[Departures.DEP] as Number) == 531, "departure")
        && check(logger, (t[Departures.FLAGS] as Number) == Schedule.FLAG_EXPRESS, "express flag")
        && check(logger, "Беговая".equals(t[Departures.TERMINAL] as String), "terminal")
        && check(logger, "2".equals(t[Departures.PLATFORM] as String), "platform");
}

(:test)
function testCollectBackDirectionShiftAndCount(logger as Logger) as Boolean {
    resetState();
    var out = [] as Array<Array>;
    Departures.collect(sampleDay(), false, 0, 24 * 60, 1, out);
    return check(logger, out.size() == 1, "count limits the result")
        && check(logger, (out[0][Departures.DEP] as Number) == 1090 + 24 * 60, "shifted by a day")
        && check(logger, "".equals(out[0][Departures.PLATFORM] as String), "missing platform is empty");
}

(:test)
function testCollectHidesExpress(logger as Logger) as Boolean {
    resetState();
    Properties.setValue("HideExpress", true);
    var out = [] as Array<Array>;
    Departures.collect(sampleDay(), true, 0, 0, 5, out);
    return check(logger, out.size() == 1 && (out[0][Departures.DEP] as Number) == 522, "express skipped");
}

(:test)
function testUpcomingContinuesIntoTomorrow(logger as Logger) as Boolean {
    resetState();
    Schedule.save(Schedule.dateString(0), dayWithTrains([600, 1430]), NOW_SECONDS);
    Schedule.save(Schedule.dateString(1), dayWithTrains([330, 360, 390]), NOW_SECONDS);
    var trains = Departures.upcoming(true, 3, 23 * 60 + 50);
    if (!check(logger, trains != null && trains.size() == 3, "three trains")) {
        return false;
    }
    var t = trains as Array<Array>;
    return check(logger, (t[0][Departures.DEP] as Number) == 1430, "last train today")
        && check(logger, (t[1][Departures.DEP] as Number) == 330 + 24 * 60, "first tomorrow")
        && check(logger, (t[2][Departures.DEP] as Number) == 360 + 24 * 60, "second tomorrow");
}

(:test)
function testUpcomingWithoutTodayIsNull(logger as Logger) as Boolean {
    resetState();
    Schedule.save(Schedule.dateString(1), dayWithTrains([330]), NOW_SECONDS);
    return check(logger, Departures.upcoming(true, 3, 600) == null, "no schedule for today");
}

(:test)
function testUpcomingAfterLastTrainWithoutTomorrowIsEmpty(logger as Logger) as Boolean {
    resetState();
    Schedule.save(Schedule.dateString(0), dayWithTrains([600]), NOW_SECONDS);
    var trains = Departures.upcoming(true, 3, 23 * 60);
    return check(logger, trains != null && trains.size() == 0, "empty, not null");
}
