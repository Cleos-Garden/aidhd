import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Timer;
import Toybox.UserProfile;
import Toybox.WatchUi;

const COLOR_HYROX_YELLOW = 0xFFED00;
const COLOR_RUN = 0x00AAFF;
const COLOR_STATION = 0xFF8800;
const COLOR_ROX = 0xAA55FF;

class HyroxView extends WatchUi.View {
    hidden var _race;
    hidden var _timer = null;
    hidden var _zones = null;
    hidden var _w = 0;
    hidden var _h = 0;

    function initialize(race) {
        View.initialize();
        _race = race;
        try {
            _zones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        } catch (e) {
            _zones = null;
        }
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
    }

    function onHide() {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var state = _race.state;
        if (state == STATE_READY) {
            drawReady(dc);
            return;
        }
        if (state == STATE_SAVED || state == STATE_DISCARDED) {
            drawDone(dc);
            return;
        }

        var seg = _race.segment();
        if (seg[:kind] == KIND_RUN) {
            drawRun(dc, seg);
        } else {
            drawStation(dc, seg);
        }
        drawFooter(dc);
    }

    // --- Screens ---------------------------------------------------------

    hidden function drawReady(dc) {
        text(dc, 0.22, Graphics.FONT_MEDIUM, "HYROX", COLOR_HYROX_YELLOW);
        text(dc, 0.38, Graphics.FONT_SMALL, "Target " + Fmt.time(_race.targetSecs), Graphics.COLOR_WHITE);

        var mode = "Indoor run";
        if (_race.recordAs == RECORD_OUTDOOR_RUN) {
            mode = gpsReady() ? "GPS ready" : "GPS searching...";
        } else if (_race.recordAs == RECORD_CARDIO) {
            mode = "Saves as cardio";
        }
        text(dc, 0.50, Graphics.FONT_XTINY, mode, Graphics.COLOR_LT_GRAY);

        var hr = _race.heartRate();
        text(dc, 0.59, Graphics.FONT_XTINY, hr != null ? "HR " + hr : "HR --", hrColor(hr));

        text(dc, 0.74, Graphics.FONT_SMALL, "START to go", Graphics.COLOR_WHITE);
        text(dc, 0.84, Graphics.FONT_XTINY, "LAP / BACK = next", Graphics.COLOR_LT_GRAY);
    }

    hidden function drawRun(dc, seg) {
        var secs = _race.segmentSecs();
        var dist = _race.segmentDistance();
        var cad = _race.cadence();

        header(dc, COLOR_RUN, "RUN " + seg[:num] + " / 8",
            Fmt.km(dist) + " km" + (cad != null ? "  " + cad + " spm" : ""));

        text(dc, 0.32, Graphics.FONT_XTINY, "LAP TIME", Graphics.COLOR_LT_GRAY);
        text(dc, 0.42, Graphics.FONT_NUMBER_MEDIUM, Fmt.time(secs), Graphics.COLOR_WHITE);

        var hr = _race.heartRate();
        var zone = hrZone(hr);
        textAt(dc, 0.32, 0.58, Graphics.FONT_MEDIUM, Fmt.pace(secs, dist), Graphics.COLOR_WHITE);
        textAt(dc, 0.68, 0.58, Graphics.FONT_MEDIUM, hr != null ? hr.toString() : "--", hrColor(hr));
        textAt(dc, 0.32, 0.66, Graphics.FONT_XTINY, "PACE /km", Graphics.COLOR_LT_GRAY);
        textAt(dc, 0.68, 0.66, Graphics.FONT_XTINY, zone > 0 ? "HR  Z" + zone : "HR", Graphics.COLOR_LT_GRAY);
    }

    // Stations and Roxzone share a layout: big elapsed time, progress to goal, HR.
    hidden function drawStation(dc, seg) {
        var isRox = seg[:kind] == KIND_ROX;
        var sub = isRox ? seg[:detail] : seg[:num].toString() + "/8  " + seg[:detail];
        header(dc, isRox ? COLOR_ROX : COLOR_STATION, seg[:name], sub);

        var secs = _race.segmentSecs();
        var plan = seg[:plan];
        text(dc, 0.42, Graphics.FONT_NUMBER_MEDIUM, Fmt.time(secs), Graphics.COLOR_WHITE);

        // Progress bar towards this segment's planned time.
        var barW = (_w * 0.56).toNumber();
        var barX = (_w - barW) / 2;
        var barY = (_h * 0.54).toNumber();
        var ratio = plan > 0 ? secs / plan : 0;
        var over = ratio > 1;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barW, 6);
        dc.setColor(over ? Graphics.COLOR_RED : Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, (barW * (over ? 1 : ratio)).toNumber(), 6);
        text(dc, 0.60, Graphics.FONT_XTINY, "Goal " + Fmt.time(plan), Graphics.COLOR_LT_GRAY);

        var hr = _race.heartRate();
        var zone = hrZone(hr);
        text(dc, 0.69, Graphics.FONT_SMALL,
            "HR " + (hr != null ? hr : "--") + (zone > 0 ? "  Z" + zone : ""), hrColor(hr));
    }

    // Total vs target, then either the last segment's result, the plan gap, or pause state.
    hidden function drawFooter(dc) {
        text(dc, 0.79, Graphics.FONT_SMALL,
            Fmt.time(_race.totalSecs()) + " / " + Fmt.time(_race.targetSecs), Graphics.COLOR_WHITE);

        var state = _race.state;
        if (state == STATE_PAUSED) {
            text(dc, 0.88, Graphics.FONT_XTINY, "PAUSED - START", Graphics.COLOR_RED);
            return;
        }
        if (state == STATE_FINISHED) {
            text(dc, 0.88, Graphics.FONT_XTINY, "FINISHED - START", COLOR_HYROX_YELLOW);
            return;
        }

        var result = _race.recentResult();
        if (result != null) {
            text(dc, 0.88, Graphics.FONT_XTINY,
                result[:name] + " " + Fmt.time(result[:secs]) + " " + Fmt.delta(result[:vsPlan]), COLOR_HYROX_YELLOW);
            return;
        }

        var gap = _race.vsPlan();
        text(dc, 0.88, Graphics.FONT_XTINY,
            Fmt.delta(gap) + "  ETA " + Fmt.time(_race.projectedFinish()),
            gap > 0 ? Graphics.COLOR_RED : Graphics.COLOR_GREEN);
    }

    hidden function drawDone(dc) {
        var saved = _race.state == STATE_SAVED;
        text(dc, 0.28, Graphics.FONT_MEDIUM, saved ? "Saved" : "Discarded",
            saved ? Graphics.COLOR_GREEN : Graphics.COLOR_LT_GRAY);
        if (saved) {
            var total = _race.finalSecs;
            text(dc, 0.46, Graphics.FONT_NUMBER_MILD, Fmt.time(total), Graphics.COLOR_WHITE);
            var gap = total - _race.targetSecs;
            text(dc, 0.60, Graphics.FONT_SMALL, Fmt.delta(gap) + " vs target",
                gap > 0 ? Graphics.COLOR_RED : Graphics.COLOR_GREEN);
        }
        text(dc, 0.80, Graphics.FONT_XTINY, "BACK to exit", Graphics.COLOR_LT_GRAY);
    }

    // --- Helpers --------------------------------------------------------

    hidden function header(dc, color, title, sub) {
        dc.setColor(color, color);
        dc.fillRectangle(0, 0, _w, (_h * 0.27).toNumber());
        text(dc, 0.12, Graphics.FONT_SMALL, title, Graphics.COLOR_BLACK);
        text(dc, 0.21, Graphics.FONT_XTINY, sub, Graphics.COLOR_BLACK);
    }

    hidden function text(dc, yFrac, font, str, color) {
        textAt(dc, 0.5, yFrac, font, str, color);
    }

    hidden function textAt(dc, xFrac, yFrac, font, str, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText((_w * xFrac).toNumber(), (_h * yFrac).toNumber(), font, str,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Zones array: [z1 min, z1 max, z2 max, z3 max, z4 max, z5 max].
    hidden function hrZone(hr) {
        if (hr == null || _zones == null || _zones.size() < 6) {
            return 0;
        }
        for (var z = 4; z >= 1; z--) {
            if (hr > _zones[z]) {
                return z + 1;
            }
        }
        return 1;
    }

    hidden function hrColor(hr) {
        var zone = hrZone(hr);
        if (zone == 5) { return Graphics.COLOR_RED; }
        if (zone == 4) { return Graphics.COLOR_ORANGE; }
        if (zone == 3) { return Graphics.COLOR_GREEN; }
        if (zone == 2) { return Graphics.COLOR_BLUE; }
        return Graphics.COLOR_WHITE;
    }

    hidden function gpsReady() {
        var acc = _race.gpsAccuracy;
        return acc != null && acc >= Position.QUALITY_USABLE;
    }
}
