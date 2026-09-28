import Toybox.Lang;

module Fmt {
    // 83.4 -> "1:23", 5025 -> "1:23:45"
    function time(secs) {
        var s = secs.toNumber();
        if (s < 0) {
            s = 0;
        }
        var h = s / 3600;
        var m = (s % 3600) / 60;
        var sec = s % 60;
        if (h > 0) {
            return h.toString() + ":" + m.format("%02d") + ":" + sec.format("%02d");
        }
        return m.toString() + ":" + sec.format("%02d");
    }

    // Positive = behind plan.
    function delta(secs) {
        return (secs > 0 ? "+" : "-") + time(secs.abs());
    }

    function km(metres) {
        return (metres / 1000.0).format("%.2f");
    }

    // Average pace for the lap in min/km; blank until there's enough distance to mean anything.
    function pace(secs, metres) {
        if (metres < 50) {
            return "--:--";
        }
        return time(secs / (metres / 1000.0));
    }
}
