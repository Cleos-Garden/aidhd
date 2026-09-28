import Toybox.Lang;
import Toybox.WatchUi;

// START: begin / pause menu. LAP (or BACK on 5-button watches): next segment.
class HyroxDelegate extends WatchUi.BehaviorDelegate {
    hidden var _race;

    function initialize(race) {
        BehaviorDelegate.initialize();
        _race = race;
    }

    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_ENTER) {
            return onStartKey();
        }
        if (key == WatchUi.KEY_ESC || key == WatchUi.KEY_LAP) {
            return onLapKey();
        }
        return false;
    }

    // Swallow swipe-back mid race so the app can't be closed by accident.
    function onBack() {
        return _race.isActive();
    }

    hidden function onStartKey() {
        var state = _race.state;
        if (state == STATE_READY) {
            _race.start();
        } else if (state == STATE_RUNNING) {
            _race.pause();
            HyroxMenu.show(_race);
        } else if (state == STATE_PAUSED || state == STATE_FINISHED) {
            HyroxMenu.show(_race);
        } else {
            return false;
        }
        WatchUi.requestUpdate();
        return true;
    }

    hidden function onLapKey() {
        if (_race.state == STATE_RUNNING) {
            _race.lap();
            if (_race.state == STATE_FINISHED) {
                HyroxMenu.show(_race);
            }
            WatchUi.requestUpdate();
            return true;
        }
        // Before the start and after saving, BACK exits as normal.
        return _race.isActive();
    }
}
