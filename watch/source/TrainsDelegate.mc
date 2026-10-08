import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

//! START flips the direction, MENU opens the native Menu2.
//! BACK is left to the system (UX guidelines: don't change back behavior).
class TrainsDelegate extends WatchUi.BehaviorDelegate {
    private var _view as TrainsView;
    private var _fetcher as Fetcher?;

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

    //! Fetches today (or the first missing day) in the foreground.
    public function refresh(force as Boolean) as Void {
        if (!Schedule.isConfigured()) {
            return;
        }
        var date = force ? Schedule.dateString(0) : Schedule.nextDateToFetch(Time.now().value());
        if (date == null) {
            return;
        }
        _view.setStatus(WatchUi.loadResource($.Rez.Strings.Loading) as String);
        _fetcher = new Fetcher(method(:onFetched));
        (_fetcher as Fetcher).fetch(date);
    }

    //! Errors are stored by Fetcher and shown in the footer.
    public function onFetched(code as Number) as Void {
        _view.setStatus("");
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
        _parent.refresh(true);
    }
}
