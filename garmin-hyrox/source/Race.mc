import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Application;
import Toybox.Attention;
import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Sensor;
import Toybox.System;

enum { KIND_RUN, KIND_ROX, KIND_STATION }
enum { STATE_READY, STATE_RUNNING, STATE_PAUSED, STATE_FINISHED, STATE_SAVED, STATE_DISCARDED }
enum { RECORD_INDOOR_RUN, RECORD_OUTDOOR_RUN, RECORD_CARDIO }

// Owns the race: the segment sequence, the recording session and the plan.
class Race {
    // Presses closer together than this are treated as an accidental double press.
    const LAP_DEBOUNCE_MS = 3000;
    // How long the "last segment" result stays on screen after a lap.
    const RESULT_SHOW_MS = 6000;

    // Baseline split plan (seconds) for a ~84 min finish, scaled to the target time.
    const RUN_PLAN = 300;
    const ROX_PLAN = 30;

    var state = STATE_READY;
    var index = 0;
    var segments = [];
    var targetSecs = 5400;
    var recordAs = RECORD_INDOOR_RUN;
    var gpsAccuracy = null;
    var lastResult = null;
    var finalSecs = 0;

    hidden var _session = null;
    hidden var _planEnd = [];
    hidden var _segStartMs = 0;
    hidden var _segStartDist = 0.0;
    hidden var _lastLapAt = null;
    hidden var _segmentField = null;
    hidden var _vsPlanField = null;

    function initialize() {
        targetSecs = prop("targetMinutes", 90) * 60;
        recordAs = prop("recordAs", RECORD_INDOOR_RUN);
        buildSegments(prop("trackRoxzone", true));

        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        if (recordAs == RECORD_OUTDOOR_RUN) {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        }
    }

    hidden function buildSegments(roxzone) {
        // [screen name, FIT name, distance/reps, baseline seconds]
        var stations = [
            ["SKIERG", "SkiErg", "1000 m", 270],
            ["SLED PUSH", "Sled Push", "50 m", 240],
            ["SLED PULL", "Sled Pull", "50 m", 300],
            ["BURPEE BJ", "Burpee Broad Jump", "80 m", 300],
            ["ROW", "Row", "1000 m", 285],
            ["FARMERS", "Farmers Carry", "200 m", 120],
            ["LUNGES", "Sandbag Lunges", "100 m", 300],
            ["WALL BALLS", "Wall Balls", "100 reps", 390]
        ];

        for (var i = 0; i < 8; i++) {
            var st = stations[i];
            segments.add({:kind => KIND_RUN, :name => "RUN", :fitName => "Run " + (i + 1),
                :detail => "1 km", :num => i + 1, :plan => RUN_PLAN});
            if (roxzone) {
                segments.add({:kind => KIND_ROX, :name => "ROXZONE", :fitName => "Roxzone in",
                    :detail => "to " + st[0], :num => i + 1, :plan => ROX_PLAN});
            }
            segments.add({:kind => KIND_STATION, :name => st[0], :fitName => st[1],
                :detail => st[2], :num => i + 1, :plan => st[3]});
            if (roxzone && i < 7) {
                segments.add({:kind => KIND_ROX, :name => "ROXZONE", :fitName => "Roxzone out",
                    :detail => "to RUN " + (i + 2), :num => i + 1, :plan => ROX_PLAN});
            }
        }

        // Scale the baseline plan so it adds up to the target time.
        var raw = 0;
        for (var i = 0; i < segments.size(); i++) {
            raw += segments[i][:plan];
        }
        var scale = targetSecs.toFloat() / raw;
        var cumulative = 0.0;
        for (var i = 0; i < segments.size(); i++) {
            var plan = segments[i][:plan] * scale;
            segments[i][:plan] = plan;
            cumulative += plan;
            _planEnd.add(cumulative);
        }
    }

    function onPosition(info as Position.Info) as Void {
        gpsAccuracy = info.accuracy;
    }

    // --- Controls ---------------------------------------------------------

    function start() {
        if (_session == null) {
            var sport = Activity.SPORT_RUNNING;
            var subSport = Activity.SUB_SPORT_INDOOR_RUNNING;
            if (recordAs == RECORD_OUTDOOR_RUN) {
                subSport = Activity.SUB_SPORT_GENERIC;
            } else if (recordAs == RECORD_CARDIO) {
                sport = Activity.SPORT_TRAINING;
                subSport = Activity.SUB_SPORT_CARDIO_TRAINING;
            }
            _session = ActivityRecording.createSession({:name => "HYROX", :sport => sport, :subSport => subSport});
            createFitFields();
        }
        _session.start();
        _segStartMs = timerMs();
        _segStartDist = distance();
        state = STATE_RUNNING;
        alert(false);
    }

    function pause() {
        if (state == STATE_RUNNING) {
            _session.stop();
            state = STATE_PAUSED;
        }
    }

    // Also used to carry on after an accidental finish.
    function resume() {
        if (state == STATE_PAUSED || state == STATE_FINISHED) {
            _session.start();
            state = STATE_RUNNING;
        }
    }

    // Ends the current segment and moves to the next; the last lap finishes the race.
    function lap() {
        if (state != STATE_RUNNING) {
            return;
        }
        var now = System.getTimer();
        if (_lastLapAt != null && now - _lastLapAt < LAP_DEBOUNCE_MS) {
            return;
        }
        _lastLapAt = now;

        var t = timerMs();
        var segSecs = (t - _segStartMs) / 1000.0;
        var vsPlan = t / 1000.0 - _planEnd[index];
        var seg = segments[index];

        _segmentField.setData(seg[:fitName]);
        _vsPlanField.setData(vsPlan.toNumber());
        lastResult = {:name => seg[:kind] == KIND_RUN ? "RUN " + seg[:num] : seg[:name],
            :secs => segSecs, :vsPlan => vsPlan, :at => now};

        if (index == segments.size() - 1) {
            _session.stop();
            state = STATE_FINISHED;
            alert(true);
            return;
        }

        _session.addLap();
        index++;
        _segStartMs = t;
        _segStartDist = distance();
        alert(false);
    }

    function save() {
        finalSecs = totalSecs();
        if (_session != null) {
            _session.save();
        }
        state = STATE_SAVED;
        stopSensors();
    }

    function discard() {
        if (_session != null) {
            _session.discard();
        }
        state = STATE_DISCARDED;
        stopSensors();
    }

    // Called when the app closes: never lose a race that was in progress.
    function shutdown() {
        if (isActive()) {
            if (_session.isRecording()) {
                _session.stop();
            }
            save();
        }
        stopSensors();
    }

    function isActive() {
        return state == STATE_RUNNING || state == STATE_PAUSED || state == STATE_FINISHED;
    }

    // --- Live values for the screens ---------------------------------------

    function segment() {
        return segments[index];
    }

    function segmentSecs() {
        return (timerMs() - _segStartMs) / 1000.0;
    }

    function totalSecs() {
        return timerMs() / 1000.0;
    }

    function segmentDistance() {
        var d = distance() - _segStartDist;
        return d < 0 ? 0.0 : d;
    }

    // Seconds behind (+) or ahead (-) of plan. Carries the gap from earlier
    // segments and only grows during a segment once it overruns its plan.
    function vsPlan() {
        var plan = segments[index][:plan];
        var planStart = _planEnd[index] - plan;
        var over = segmentSecs() - plan;
        return _segStartMs / 1000.0 - planStart + (over > 0 ? over : 0);
    }

    function projectedFinish() {
        return targetSecs + vsPlan();
    }

    function recentResult() {
        if (lastResult != null && System.getTimer() - lastResult[:at] < RESULT_SHOW_MS) {
            return lastResult;
        }
        return null;
    }

    function heartRate() {
        var info = Activity.getActivityInfo();
        return info != null ? info.currentHeartRate : null;
    }

    function cadence() {
        var info = Activity.getActivityInfo();
        return info != null ? info.currentCadence : null;
    }

    // --- Internals ------------------------------------------------------

    hidden function createFitFields() {
        _segmentField = _session.createField("segment", 0, FitContributor.DATA_TYPE_STRING,
            {:mesgType => FitContributor.MESG_TYPE_LAP, :count => 20});
        _vsPlanField = _session.createField("vs_plan", 1, FitContributor.DATA_TYPE_SINT32,
            {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "s"});
        var targetField = _session.createField("target", 2, FitContributor.DATA_TYPE_UINT16,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "min"});
        targetField.setData(targetSecs / 60);
    }

    hidden function timerMs() {
        var info = Activity.getActivityInfo();
        return (info != null && info.timerTime != null) ? info.timerTime : 0;
    }

    hidden function distance() {
        var info = Activity.getActivityInfo();
        return (info != null && info.elapsedDistance != null) ? info.elapsedDistance : 0.0;
    }

    hidden function alert(strong) {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(100, strong ? 1000 : 400)]);
        }
        if (Attention has :playTone) {
            Attention.playTone(strong ? Attention.TONE_SUCCESS : Attention.TONE_LAP);
        }
    }

    hidden function stopSensors() {
        if (recordAs == RECORD_OUTDOOR_RUN) {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        }
    }

    hidden function prop(key, fallback) {
        var value = null;
        try {
            value = Application.Properties.getValue(key);
        } catch (e) {
            value = null;
        }
        return value == null ? fallback : value;
    }
}
