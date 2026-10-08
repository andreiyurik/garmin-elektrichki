import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.Test;

//! Run No Evil unit tests (Unit Testing docs): build with --unit-test,
//! run with `monkeydo <prg> <device> -t`. Not included in normal builds.

//! Two trains each way, stride 5: [dep, dur, flags, terminal, platform].
function testDay() as Dictionary {
    return {
        "ab" => [522, 23, 0, 1, 3, 531, 17, Schedule.FLAG_EXPRESS, 2, 3],
        "ba" => [1090, 24, 0, 2, 0, 1101, 24, 0, 2, 4],
        "s" => ["", "Лобня", "Беговая", "2", "9 тупик"]
    };
}

(:test)
function testHhmm(logger as Logger) as Boolean {
    return Departures.hhmm(522).equals("08:42")
        && Departures.hhmm(0).equals("00:00")
        && Departures.hhmm(24 * 60 + 5).equals("00:05");
}

(:test)
function testCollectResolvesStringsFromMinute(logger as Logger) as Boolean {
    var out = [] as Array<Array>;
    Departures.collect(testDay(), true, 525, 0, 5, out);
    logger.debug("out = " + out);
    if (out.size() != 1) {
        return false;
    }
    var t = out[0];
    return (t[Departures.DEP] as Number) == 531
        && (t[Departures.FLAGS] as Number) == Schedule.FLAG_EXPRESS
        && "Беговая".equals(t[Departures.TERMINAL] as String)
        && "2".equals(t[Departures.PLATFORM] as String);
}

(:test)
function testCollectBackDirectionShiftAndCount(logger as Logger) as Boolean {
    var out = [] as Array<Array>;
    Departures.collect(testDay(), false, 0, 24 * 60, 1, out);
    logger.debug("out = " + out);
    if (out.size() != 1) {
        return false;
    }
    var t = out[0];
    return (t[Departures.DEP] as Number) == 1090 + 24 * 60
        && "".equals(t[Departures.PLATFORM] as String);
}

(:test)
function testCollectHidesExpress(logger as Logger) as Boolean {
    Properties.setValue("HideExpress", true);
    var out = [] as Array<Array>;
    Departures.collect(testDay(), true, 0, 0, 5, out);
    Properties.setValue("HideExpress", false);
    logger.debug("out = " + out);
    return out.size() == 1 && (out[0][Departures.DEP] as Number) == 522;
}
