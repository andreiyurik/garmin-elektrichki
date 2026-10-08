import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

//! Entry point. Three modes share this class (Backgrounding and Glances docs):
//! background service (32 KB), glance (32 KB) and the full widget.
(:background, :glance)
class ElektrichkiApp extends Application.AppBase {
    private const REFRESH_SECONDS = 60 * 60;

    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    private var _delegate as TrainsDelegate?;

    public function initialize() {
        AppBase.initialize();
    }

    (:typecheck(disableGlanceCheck))
    public function getServiceDelegate() as [System.ServiceDelegate] {
        return [new BackgroundService()];
    }

    (:glance, :typecheck(disableBackgroundCheck))
    public function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new TrainsGlanceView()];
    }

    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    public function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        ensureTemporalEvent();
        var view = new TrainsView();
        var delegate = new TrainsDelegate(view);
        delegate.refresh();
        _delegate = delegate;
        return [view, delegate];
    }

    //! Called when settings change in Garmin Connect while the app runs.
    //! Cached days carry their route key, so new stations simply fetch anew.
    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    public function onSettingsChanged() as Void {
        if (_delegate != null) {
            (_delegate as TrainsDelegate).refresh();
        }
        WatchUi.requestUpdate();
    }

    //! The background service saves directly to Storage (API 3.2.0);
    //! the exit code only tells the open view to redraw.
    (:typecheck(disableBackgroundCheck))
    public function onBackgroundData(data as Application.PersistableType) as Void {
        WatchUi.requestUpdate();
    }

    private function ensureTemporalEvent() as Void {
        if (Background.getTemporalEventRegisteredTime() == null) {
            Background.registerForTemporalEvent(new Time.Duration(REFRESH_SECONDS));
        }
    }
}
