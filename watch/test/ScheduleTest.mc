import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;
import Toybox.Time.Gregorian;

//! Schedule storage, response validation and Fetcher.handle (no network).

(:test)
function testDateOfPadsMonthAndDay(logger as Logger) as Boolean {
    var moment = Gregorian.moment({ :year => 2026, :month => 1, :day => 5, :hour => 12 });
    return check(logger, Schedule.dateOf(moment).equals("2026-01-05"), Schedule.dateOf(moment));
}

(:test)
function testIsValidAcceptsProxyResponse(logger as Logger) as Boolean {
    return check(logger, Schedule.isValid(sampleDay()), "sample day")
        && check(logger, Schedule.isValid(dayWithTrains([] as Array<Number>)), "no trains is still valid");
}

(:test)
function testIsValidRejectsBrokenResponses(logger as Logger) as Boolean {
    var wrongVersion = sampleDay();
    wrongVersion["v"] = 2;
    var noStrings = sampleDay();
    noStrings.remove("s");
    var badMinute = sampleDay();
    badMinute["ab"] = [packTrain(1440, 0, 0, 0)];
    var badIndex = sampleDay();
    badIndex["ba"] = [packTrain(1090, 0, 99, 0)];
    var negative = sampleDay();
    negative["ab"] = [-1];
    var notNumber = sampleDay();
    notNumber["ab"] = ["08:42"];
    var noTitle = sampleDay();
    noTitle.remove("a");
    return check(logger, !Schedule.isValid(wrongVersion), "old format")
        && check(logger, !Schedule.isValid(noStrings), "missing string table")
        && check(logger, !Schedule.isValid(badMinute), "departure past midnight")
        && check(logger, !Schedule.isValid(badIndex), "string index out of range")
        && check(logger, !Schedule.isValid(negative), "negative minute")
        && check(logger, !Schedule.isValid(notNumber), "string in train array")
        && check(logger, !Schedule.isValid(noTitle), "missing station title");
}

(:test)
function testSaveLoadIsTiedToRouteAndFormat(logger as Logger) as Boolean {
    resetState();
    var date = Schedule.dateString(0);
    Schedule.save(date, sampleDay(), NOW_SECONDS);
    var loaded = check(logger, Schedule.load(date) != null, "loads after save");

    Properties.setValue("WorkStation", "Лобня");
    var otherRoute = check(logger, Schedule.load(date) == null, "new stations ignore old cache");

    Properties.setValue("WorkStation", "Беговая");
    var old = sampleDay();
    old["v"] = 2;
    old["r"] = Schedule.routeKey();
    Storage.setValue("d:" + date, old as Dictionary<Storage.KeyType, Storage.ValueType>);
    var oldFormat = check(logger, Schedule.load(date) == null, "old format ignored");
    return loaded && otherRoute && oldFormat;
}

(:test)
function testNextDateToFetch(logger as Logger) as Boolean {
    resetState();
    var today = Schedule.dateString(0);
    var ok = check(logger, today.equals(Schedule.nextDateToFetch(NOW_SECONDS)), "empty cache: today");

    for (var i = 0; i < Schedule.DAYS_AHEAD; i++) {
        Schedule.save(Schedule.dateString(i), sampleDay(), NOW_SECONDS);
    }
    ok = check(logger, Schedule.nextDateToFetch(NOW_SECONDS) == null, "all fresh: nothing") && ok;
    ok = check(logger, Schedule.nextDateToFetch(NOW_SECONDS + Schedule.STALE_SECONDS) == null,
        "exactly 12 h old is still fresh") && ok;
    ok = check(logger, today.equals(Schedule.nextDateToFetch(NOW_SECONDS + Schedule.STALE_SECONDS + 1)),
        "older than 12 h: refetch today") && ok;

    Storage.deleteValue("d:" + Schedule.dateString(2));
    ok = check(logger, Schedule.dateString(2).equals(Schedule.nextDateToFetch(NOW_SECONDS)),
        "missing day after tomorrow") && ok;

    Properties.setValue("HomeStation", "");
    ok = check(logger, Schedule.nextDateToFetch(NOW_SECONDS) == null, "not configured: nothing") && ok;
    return ok;
}

(:test)
function testPruneDropsPastDays(logger as Logger) as Boolean {
    resetState();
    Schedule.save(Schedule.dateString(-1), sampleDay(), NOW_SECONDS);
    Schedule.save(Schedule.dateString(0), sampleDay(), NOW_SECONDS);
    Schedule.prune();
    return check(logger, Storage.getValue("d:" + Schedule.dateString(-1)) == null, "yesterday deleted")
        && check(logger, Schedule.load(Schedule.dateString(0)) != null, "today kept");
}

(:test)
function testErrorLifecycle(logger as Logger) as Boolean {
    resetState();
    Schedule.saveError(Schedule.ERROR_PHONE, "-104");
    var saved = Schedule.lastError();
    var ok = check(logger, saved != null && (saved["k"] as Number) == Schedule.ERROR_PHONE, "error stored");

    Properties.setValue("HomeStation", "Лобня");
    ok = check(logger, Schedule.lastError() == null, "error belongs to the old stations") && ok;

    Properties.setValue("HomeStation", "Одинцово");
    Schedule.save(Schedule.dateString(0), sampleDay(), NOW_SECONDS);
    ok = check(logger, Schedule.lastError() == null, "a successful save clears it") && ok;
    return ok;
}

(:test)
function testHandleStoresValidResponse(logger as Logger) as Boolean {
    resetState();
    var date = Schedule.dateString(0);
    var code = Fetcher.handle(date, 200, sampleDay(), NOW_SECONDS);
    var day = Schedule.load(date);
    return check(logger, code == 200, "returns 200")
        && check(logger, day != null && ((day as Dictionary)["t"] as Number) == NOW_SECONDS, "saved with fetch time")
        && check(logger, Schedule.lastError() == null, "no error");
}

(:test)
function testHandleClassifiesErrors(logger as Logger) as Boolean {
    resetState();
    var date = Schedule.dateString(0);
    var ok = true;

    var code = Fetcher.handle(date, 200, { "v" => 9 }, NOW_SECONDS);
    ok = check(logger, code == Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE, "bad body code") && ok;
    ok = check(logger, Schedule.load(date) == null, "bad body not saved") && ok;
    ok = expectError(logger, Schedule.ERROR_SERVER, "bad body") && ok;

    Fetcher.handle(date, 404, { "error" => "station", "which" => "a", "q" => "Одинцвоо" }, NOW_SECONDS);
    ok = expectError(logger, Schedule.ERROR_STATION, "station") && ok;
    ok = check(logger, "Одинцвоо".equals((Schedule.lastError() as Dictionary)["d"] as Object?), "names the station") && ok;

    Fetcher.handle(date, Communications.BLE_CONNECTION_UNAVAILABLE, null, NOW_SECONDS);
    ok = expectError(logger, Schedule.ERROR_PHONE, "no phone") && ok;

    Fetcher.handle(date, 502, { "error" => "upstream" }, NOW_SECONDS);
    ok = expectError(logger, Schedule.ERROR_SERVER, "502") && ok;

    Fetcher.handle(date, Communications.NETWORK_RESPONSE_TOO_LARGE, null, NOW_SECONDS);
    ok = expectError(logger, Schedule.ERROR_SERVER, "too large is not a connection problem") && ok;
    return ok;
}

(:test)
function testHandleKeepsOldScheduleOnError(logger as Logger) as Boolean {
    resetState();
    var date = Schedule.dateString(0);
    Fetcher.handle(date, 200, sampleDay(), NOW_SECONDS);
    Fetcher.handle(date, Communications.NETWORK_REQUEST_TIMED_OUT, null, NOW_SECONDS + 3600);
    var day = Schedule.load(date);
    return check(logger, day != null && ((day as Dictionary)["t"] as Number) == NOW_SECONDS, "old schedule still there")
        && expectError(logger, Schedule.ERROR_PHONE, "timeout");
}

(:test)
function testIsConnectionError(logger as Logger) as Boolean {
    var connection = [
        Communications.BLE_ERROR, Communications.BLE_HOST_TIMEOUT, Communications.BLE_SERVER_TIMEOUT,
        Communications.BLE_NO_DATA, Communications.BLE_REQUEST_CANCELLED, Communications.BLE_QUEUE_FULL,
        Communications.BLE_REQUEST_TOO_LARGE, Communications.BLE_UNKNOWN_SEND_ERROR,
        Communications.BLE_CONNECTION_UNAVAILABLE, Communications.NETWORK_REQUEST_TIMED_OUT,
        Communications.REQUEST_CONNECTION_DROPPED
    ] as Array<Number>;
    var other = [
        200, 404, 500, Communications.UNKNOWN_ERROR, Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE,
        Communications.NETWORK_RESPONSE_TOO_LARGE, Communications.NETWORK_RESPONSE_OUT_OF_MEMORY,
        Communications.SECURE_CONNECTION_REQUIRED
    ] as Array<Number>;
    var ok = true;
    for (var i = 0; i < connection.size(); i++) {
        ok = check(logger, Fetcher.isConnectionError(connection[i]), "connection: " + connection[i]) && ok;
    }
    for (var i = 0; i < other.size(); i++) {
        ok = check(logger, !Fetcher.isConnectionError(other[i]), "not connection: " + other[i]) && ok;
    }
    return ok;
}

function expectError(logger as Logger, kind as Number, what as String) as Boolean {
    var err = Schedule.lastError();
    return check(logger, err != null && (err["k"] as Number) == kind, what + ": error kind " + kind);
}
