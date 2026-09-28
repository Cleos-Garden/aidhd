# HYROX for Garmin

A Connect IQ watch app for HYROX training and racing. You press LAP to move through the race. Each part of the race gets its own screen and is saved as its own lap.

## Race flow

`Run 1 → Roxzone → SkiErg → Roxzone → Run 2 → … → Run 8 → Roxzone → Wall Balls`

That's 31 laps with Roxzone on, or 16 with it off. After the Wall Balls press, the timer stops and the Save / Resume / Discard menu opens.

| Button | Action |
|---|---|
| START | Start the race. During the race, pause and open the menu. |
| LAP (BACK on 5-button watches) | Finish the current segment and go to the next. Presses within 3 s of each other are ignored. |
| Swipe back | Ignored during a race, so the app can't be closed by accident. |

## Screens

**Run** (blue header): the run number and lap distance with live cadence. Below that: lap time, lap average pace (min/km), and heart rate coloured by zone with the zone number.

**Station** (orange header): the station name, station number and distance or reps. Below that: elapsed time for the station, a progress bar against the station's goal time (turns red once you go over), and heart rate with zone.

**Roxzone** (purple header): the same layout as a station, with where you're heading next.

**Every screen has the same footer:**
- Total time / target time.
- Seconds ahead (`-`, green) or behind (`+`, red) of plan, and your projected finish time (ETA).
- For 6 s after each lap, this line shows the split you just finished instead.

## Plan

You set a target finish time. The app scales a baseline split plan to it: 5:00 per run, 0:30 per Roxzone transition, and a typical time for each station. From that it works out a goal time for every segment and how far ahead or behind you are.

## What's saved to Garmin Connect

- One activity with a lap per segment, so the laps table shows each run, station and Roxzone with time, heart rate, pace and cadence.
- Custom fields on each lap: **Segment** (for example "Sled Push" or "Run 3") and **vs plan** (seconds ahead or behind at the end of that lap).
- A custom field on the activity summary: **Target time**.

**Activity type:** Garmin doesn't let an app change the sport partway through a recording, so the whole activity is saved as a single type. You choose which in the settings:
- **Running (indoor)** (default): runs look like runs in Connect, with pace and cadence. Stations count toward your running totals.
- **Running (GPS)**: for outdoor HYROX-style sessions.
- **Cardio**: keeps your running stats clean, but Connect won't show pace charts.

## Settings

Change these in the Garmin Connect app under the app's settings:
- Target finish time, in minutes (default 90).
- Separate Roxzone laps (default on).
- Save activity as.

## Build and run

1. Install the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) and the Monkey C VS Code extension. Download device files for your watch in the SDK Manager.
2. If your watch isn't in the `<iq:products>` list in `manifest.xml`, add it.
3. In VS Code, run **Monkey C: Build for Device** to put it on your watch over USB, or **Run App** to use the simulator. To build from the command line:
   ```sh
   monkeyc -f monkey.jungle -d fr265 -o bin/hyrox.prg -y /path/to/developer_key
   ```
4. To publish, run **Monkey C: Export Project** and upload the `.iq` file to the Connect IQ Store.

## Known limits

- **Indoor distance** comes from the watch's accelerometer. It's rough, especially while carrying or pushing things. The lap time for each run is the number to trust. Pace only shows once a lap has covered 50 m.
- **Rep counting** isn't included. Wall Balls shows elapsed time against its goal.
