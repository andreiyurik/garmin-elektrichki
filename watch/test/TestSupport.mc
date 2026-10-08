import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

//! Shared fixtures for the Run No Evil unit tests (Unit Testing docs).
//! Build with --unit-test and run with `monkeydo <prg> <device> -t`;
//! test code is not included in normal builds.

const NOW_SECONDS = 1791360000; // a fixed epoch second; only differences matter

//! Clean storage and known settings before every test that touches them.
function resetState() as Void {
    Storage.clearValues();
    Properties.setValue("HomeStation", "Одинцово");
    Properties.setValue("WorkStation", "Беговая");
    Properties.setValue("SwitchHour", 13);
    Properties.setValue("WalkMinutes", 0);
    Properties.setValue("HideExpress", false);
}

//! A valid proxy response (format v2): two trains each way.
//! Stride 5: [dep, dur, flags, terminal, platform]; strings indexed from "s".
function sampleDay() as Dictionary {
    return {
        "v" => 2,
        "date" => "2026-10-07",
        "a" => "Одинцово",
        "b" => "Беговая",
        "ab" => [522, 23, 0, 1, 3, 531, 17, Schedule.FLAG_EXPRESS, 2, 3],
        "ba" => [1090, 24, 0, 2, 0, 1101, 24, 0, 2, 4],
        "s" => ["", "Лобня", "Беговая", "2", "9 тупик"]
    };
}

//! A day whose only trains leave at the given minutes (both directions).
function dayWithTrains(minutes as Array<Number>) as Dictionary {
    var trains = [] as Array<Number>;
    for (var i = 0; i < minutes.size(); i++) {
        trains.addAll([minutes[i], 20, 0, 0, 0]);
    }
    return { "v" => 2, "a" => "A", "b" => "B", "ab" => trains, "ba" => trains, "s" => [""] };
}

function check(logger as Logger, ok as Boolean, what as String) as Boolean {
    if (!ok) {
        logger.error("FAILED: " + what);
    }
    return ok;
}
