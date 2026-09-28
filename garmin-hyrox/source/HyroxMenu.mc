import Toybox.Lang;
import Toybox.WatchUi;

module HyroxMenu {
    function show(race) {
        var finished = race.state == STATE_FINISHED;
        var menu = new WatchUi.Menu2({:title => finished ? "Finished" : "Paused"});
        var resume = new WatchUi.MenuItem("Resume", finished ? "Back to last station" : null, :resume, null);
        var save = new WatchUi.MenuItem("Save", null, :save, null);
        if (finished) {
            menu.addItem(save);
            menu.addItem(resume);
        } else {
            menu.addItem(resume);
            menu.addItem(save);
        }
        menu.addItem(new WatchUi.MenuItem("Discard", null, :discard, null));
        WatchUi.pushView(menu, new MenuDelegate(race), WatchUi.SLIDE_UP);
    }

    class MenuDelegate extends WatchUi.Menu2InputDelegate {
        hidden var _race;

        function initialize(race) {
            Menu2InputDelegate.initialize();
            _race = race;
        }

        function onSelect(item) {
            var id = item.getId();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            if (id == :resume) {
                _race.resume();
            } else if (id == :save) {
                _race.save();
            } else if (id == :discard) {
                WatchUi.pushView(new WatchUi.Confirmation("Discard HYROX?"),
                    new DiscardDelegate(_race), WatchUi.SLIDE_UP);
            }
            WatchUi.requestUpdate();
        }

        // Backing out of the menu leaves the race paused; START reopens it.
        function onBack() {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }

    class DiscardDelegate extends WatchUi.ConfirmationDelegate {
        hidden var _race;

        function initialize(race) {
            ConfirmationDelegate.initialize();
            _race = race;
        }

        function onResponse(response) {
            if (response == WatchUi.CONFIRM_YES) {
                _race.discard();
                WatchUi.requestUpdate();
            }
            return true;
        }
    }
}
