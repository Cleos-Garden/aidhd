import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class HyroxApp extends Application.AppBase {
    hidden var _race = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        _race = new Race();
    }

    function onStop(state) {
        if (_race != null) {
            _race.shutdown();
        }
    }

    function getInitialView() {
        return [new HyroxView(_race), new HyroxDelegate(_race)];
    }
}
