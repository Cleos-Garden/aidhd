# Handover: HYROX Connect IQ app

For a Claude Code session running on Sam's computer. This app was written in a cloud session that **could not download the Connect IQ SDK**, so it has **never been compiled or run**. Your first job is to get it building and running on a Forerunner 965 (device id `fr965`).

## What this is

A Garmin watch app for HYROX racing and training, written in Monkey C. It lives in `garmin-hyrox/` and is completely separate from the AIDhd Next.js app in the rest of the repo. User-facing docs are in `README.md` in this folder.

**What Sam asked for:**
- Laps are ended with a button press. No auto-detection.
- Run laps should look and feel like a running activity on the watch: lap time, pace, distance, cadence and HR.
- Stations and Roxzone should show relevant metrics: elapsed time for the station, HR, and total time against target time.
- Sam's watch is a **Forerunner 965**: 454×454 AMOLED, 5 buttons plus touchscreen, API level 5.x.

## Files

| File | Role |
|---|---|
| `source/HyroxApp.mc` | AppBase. Creates `Race`, saves the race if the app closes mid-race. |
| `source/Race.mc` | State machine, segment list, split plan, `ActivityRecording` session, FIT developer fields, vibrate/tone alerts, GPS. |
| `source/HyroxView.mc` | All screens (ready, run, station/Roxzone, saved), drawn in proportions of screen size. 1 s refresh timer. |
| `source/HyroxDelegate.mc` | Keys: `KEY_ENTER` = start/pause menu; `KEY_ESC`/`KEY_LAP` = next segment. Blocks swipe-back mid-race. |
| `source/HyroxMenu.mc` | Menu2 with Resume / Save / Discard, plus a confirmation before discarding. |
| `source/Fmt.mc` | Time, delta, km and pace formatting. |
| `resources/settings/*` | App settings, edited in the Garmin Connect app: `targetMinutes`, `trackRoxzone`, `recordAs` (0 indoor run / 1 GPS run / 2 cardio). |
| `resources/fit/fitcontributions.xml` | How the developer fields display in Garmin Connect. |

## Design decisions (already agreed; don't change without asking)

- **One recording session with one sport for the whole race.** Connect IQ can't change sport partway through. The default is `SPORT_RUNNING` / `SUB_SPORT_INDOOR_RUNNING`, so the runs look like runs in Garmin Connect. Cardio can be chosen in settings.
- **Segment order:** Run → Roxzone → Station → Roxzone → next Run. That's 31 laps, or 16 with Roxzone off. The final lap stops the timer and opens the Save / Resume / Discard menu. Resume is there in case the last press was an accident.
- **Split plan:** baseline times (5:00 per run, 0:30 per Roxzone, a typical time per station) scaled to the target finish time. "vs plan" carries the gap from earlier segments, and only grows during a segment once that segment runs over its planned time.
- **Accidental presses:** lap presses within 3 s are ignored, and swipe-back is swallowed while a race is active.

## Parts most likely to need fixing

These were written without being able to check them against the SDK:

1. **Type checking.** The code is untyped, so it relies on gradual type checking. If the build uses strict checking, lower it (`monkeyC.typeCheckLevel` in VS Code settings) or add types.
2. **`FitContributor.DATA_TYPE_STRING` with `:count => 20`** for the lap "Segment" field in `Race.createFitFields()`. If string fields aren't supported, or don't display in Connect, switch to a numeric segment index.
3. **`Activity.SPORT_*` / `Activity.SUB_SPORT_*` constants** in `createSession`. Older SDKs used `ActivityRecording.SPORT_*`.
4. **Global `enum`s and `const`s** declared at the top of `Race.mc` and `HyroxView.mc`, and classes nested inside `module HyroxMenu`. Move them if the compiler complains.
5. **Key handling on the 965.** Check that `onKey` gets `KEY_ESC` from the BACK/LAP button before `onBack` fires, so one press isn't counted twice or lost.
6. **Indoor distance.** Unconfirmed whether `ActivityInfo.elapsedDistance` fills in from the accelerometer for an indoor-running session. If it stays at 0, pace shows `--:--`, which is acceptable for now.
7. **Screen layout.** Check text fits on the 454 px round screen, especially the header band and the footer line at y=0.88.
8. **Launcher icon.** It's 60×60. The compiler may warn and rescale it for the 965; that's fine.

## Suggested steps

1. Install the Connect IQ SDK, the Monkey C VS Code extension and the `fr965` device files. Generate a developer key.
2. Build: `monkeyc -f garmin-hyrox/monkey.jungle -d fr965 -o bin/hyrox.prg -y <key>`. Fix compile errors.
3. Run it in the simulator. Step through a full race with the lap key, pause and resume, finish, save. Use the simulator's FIT export to check the laps and developer fields.
4. Sideload onto Sam's watch (copy the `.prg` to `GARMIN/APPS`) for a real session.
5. Ship the fixes. The repo has a rule that blocks pushes to existing branches ("Changes must be made through a pull request"), so you can't push more commits to this PR's branch (`claude/garmin-hyrox-app-handover`). Instead, create a new branch from it, push that, and open a PR. Target this branch if the PR is still open, or `main` if it's been merged.

## Possible later work (not started)

- A per-station goal time override in settings, instead of only the scaled plan.
- Wall ball rep counting from the accelerometer.
- A summary screen after saving that lists every split.
- Publishing to the Connect IQ Store.
