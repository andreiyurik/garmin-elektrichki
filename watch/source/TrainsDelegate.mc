import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

//! START flips the direction, MENU opens the native Menu2.
//! BACK is left to the system (UX guidelines: don't change back behavior).
class TrainsDelegate extends WatchUi.BehaviorDelegate {
    private var _view as TrainsView;
    private var _fetcher as Fetcher?;
    private var _progressShown as Boolean = false;

    public function initialize(view as TrainsView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    public function onSelect() as Boolean {
        _view.flip();
        return true;
    }

    public function onMenu() as Boolean {
        var menu = new WatchUi.Menu2({ :title => WatchUi.loadResource($.Rez.Strings.AppName) as String });
        // Yandex attribution rides along as the sub-label of the only action.
        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource($.Rez.Strings.MenuRefresh) as String,
            WatchUi.loadResource($.Rez.Strings.MenuSource) as String,
            :refresh, null));
        WatchUi.pushView(menu, new TrainsMenuDelegate(self), WatchUi.SLIDE_UP);
        return true;
    }

    //! Automatic fetch of the first missing or stale day (on open, after a
    //! settings change). Non-blocking: the screen stays usable, the footer says
    //! "Loading…".
    public function refresh() as Void {
        var date = Schedule.nextDateToFetch(Time.now().value());
        if (date == null) {
            return;
        }
        _view.setStatus(WatchUi.loadResource($.Rez.Strings.Loading) as String);
        _fetcher = new Fetcher(method(:onFetched));
        (_fetcher as Fetcher).fetch(date);
    }

    public function onFetched(code as Number) as Void {
        _view.setStatus("");
    }

    //! "Refresh now" from the menu: the user waits for it, so it shows the
    //! native progress bar (UX guidelines) and a toast on success (API 3.4.0).
    public function refreshNow() as Void {
        if (!Schedule.isConfigured()) {
            return;
        }
        _progressShown = true;
        WatchUi.pushView(
            new WatchUi.ProgressBar(WatchUi.loadResource($.Rez.Strings.Loading) as String, null),
            new ProgressDelegate(method(:onProgressClosed)),
            WatchUi.SLIDE_IMMEDIATE);
        _fetcher = new Fetcher(method(:onRefreshedNow));
        (_fetcher as Fetcher).fetch(Schedule.dateString(0));
    }

    public function onProgressClosed() as Void {
        _progressShown = false;
    }

    public function onRefreshedNow(code as Number) as Void {
        if (_progressShown) {
            _progressShown = false;
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
        if (code == 200 && WatchUi has :showToast) {
            WatchUi.showToast(WatchUi.loadResource($.Rez.Strings.Updated) as String, null);
        }
        WatchUi.requestUpdate();
    }
}

//! BACK closes the progress bar; the download continues and is stored.
class ProgressDelegate extends WatchUi.BehaviorDelegate {
    private var _onClose as Method() as Void;

    public function initialize(onClose as Method() as Void) {
        BehaviorDelegate.initialize();
        _onClose = onClose;
    }

    public function onBack() as Boolean {
        _onClose.invoke();
        return false; // the system pops the view
    }
}

class TrainsMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _parent as TrainsDelegate;

    public function initialize(parent as TrainsDelegate) {
        Menu2InputDelegate.initialize();
        _parent = parent;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        _parent.refreshNow();
    }
}
