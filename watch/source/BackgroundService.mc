import Toybox.Background;
import Toybox.Lang;
import Toybox.System;

//! Hourly temporal event: fills missing or stale days, one request at a time.
//! Each day is saved as soon as it arrives, so if the system stops the
//! service (30 s limit, Backgrounding docs) the next run continues from there.
(:background)
class BackgroundService extends System.ServiceDelegate {
    private var _fetcher as Fetcher?;
    private var _lastCode as Number = 0;
    private var _requests as Number = 0;

    public function initialize() {
        ServiceDelegate.initialize();
    }

    public function onTemporalEvent() as Void {
        Schedule.prune();
        _fetcher = new Fetcher(method(:onFetched));
        fetchNext();
    }

    public function onFetched(code as Number) as Void {
        _lastCode = code;
        if (code != 200) {
            Background.exit(code);
            return;
        }
        fetchNext();
    }

    private function fetchNext() as Void {
        var date = Schedule.nextDateToFetch();
        // Bounded so a response that is never saved cannot loop forever.
        _requests++;
        if (date == null || _requests > Schedule.DAYS_AHEAD) {
            Background.exit(_lastCode);
            return;
        }
        (_fetcher as Fetcher).fetch(date);
    }
}
