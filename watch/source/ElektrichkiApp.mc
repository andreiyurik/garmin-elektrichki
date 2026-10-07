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

    public function initialize() {
        AppBase.initialize();
    }

    public function getServiceDelegate() as [System.ServiceDelegate] {
        return [new BackgroundService()];
    }

    (:glance)
    public function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new TrainsGlanceView()];
    }

    public function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        ensureTemporalEvent();
        var view = new TrainsView();
        var delegate = new TrainsDelegate(view);
        delegate.refresh(false);
        return [view, delegate];
    }

    //! Stations changed. Cached days carry their route key, so the old route's
    //! days are ignored and the view or the next background run fetches anew.
    public function onSettingsChanged() as Void {
        ensureTemporalEvent();
        WatchUi.requestUpdate();
    }

    //! The background service saves directly to Storage (API 3.2.0);
    //! the exit code only tells the open view to redraw.
    public function onBackgroundData(data as Application.PersistableType) as Void {
        WatchUi.requestUpdate();
    }

    private function ensureTemporalEvent() as Void {
        if (Background.getTemporalEventRegisteredTime() == null) {
            Background.registerForTemporalEvent(new Time.Duration(REFRESH_SECONDS));
        }
    }
}
