import Toybox.Communications;
import Toybox.Lang;

//! Downloads one day of schedule from the proxy and stores it.
//! Pattern from the SDK WebRequest sample; runs in the background service
//! and in the foreground (manual refresh).
(:background)
class Fetcher {
    private var _date as String = "";
    private var _done as Method(code as Number) as Void;

    public function initialize(done as Method(code as Number) as Void) {
        _done = done;
    }

    public function fetch(date as String) as Void {
        _date = date;
        Communications.makeWebRequest(
            Schedule.proxyUrl() + "/v1/day",
            { "a" => Schedule.home(), "b" => Schedule.work(), "date" => date },
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onReceive)
        );
    }

    public function onReceive(code as Number, data as Dictionary or String or Null) as Void {
        if (code == 200 && data instanceof Dictionary && data["ab"] instanceof Array) {
            Schedule.save(_date, data);
        }
        _done.invoke(code);
    }
}
