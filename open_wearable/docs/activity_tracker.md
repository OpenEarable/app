# Activity Tracker — core implementation

Activity Tracker is a built-in mini-app under **Apps → Activity Tracker**. It
uses the host wearable picker, sensor configuration provider, shared sensor
streams and Material theme. UI copy is English. The reference is the individual
phone screens on the core page of the [approved Figma file](https://www.figma.com/design/8jNxHQ1Xf9OE5VedoepAjY).

## Flow and scope

1. Connect an OpenEarable with three-axis accelerometer and gyroscope streams.
2. Check the fit and stand still for 1.5 seconds. Start tracking once calibrated.
3. Steps continue across mini-app navigation. Choose Squats or Push-ups, hold the
   starting position briefly, then perform complete down/up cycles. Finish each
   set before starting another exercise. Exercise sets suppress step counting.
4. Jump test detects take-off/free flight/landing and displays an estimated
   height only when the timing and signal pass the quality checks. Jumps can
   also be detected between exercises after a still preparation period.
5. Pause/resume preserves confirmed counts. Disconnects and data gaps discard
   incomplete movements and require still calibration before counting resumes.
6. End the session from the overview menu. History, reference trials, JSON and
   CSV exports are available in Sessions. Leaving the mini-app does not end an
   active session; leaving readiness without starting releases its sensors.
   The app tile also opens without a connected wearable, so history and an
   interrupted session remain accessible offline.

There is no ML, automatic exercise selection, walking/running/stairs classifier
or microphone processing in this implementation. The user selects the exercise.

**Execution boundary:** tracking is continuous while the application is in the
foreground. Background/lock-screen operation is not implemented as a platform
service. Counting explicitly pauses on backgrounding; returning requires fresh
calibration. The host does not shut down IMU sensors for an active session.

## Architecture

- `models/activity_engine.dart`: pure Dart, causal algorithms, independent of
  Flutter/BLE/UI. Inputs use m/s², rad/s and sensor seconds.
- `services/activity_sensor_source.dart`: verifies units, converts timestamps
  using each sensor's exponent (OE2 uses microseconds), joins batched IMU streams
  by timestamp, selects a streaming rate near 100 Hz and reconnects by device ID.
  Shared configuration handles are applied once. Existing recording flags and
  higher rates are preserved; stopping restores known original settings only
  if another consumer has not changed them.
- `view_models/activity_tracker_controller.dart`: app-wide owner registered in
  the host provider tree; consumes every sample, updates widgets at up to 10 Hz,
  owns session state and checkpoints confirmed events.
- `services/activity_storage.dart`: serialized atomic JSON checkpoints under
  the app support `activity_tracker` directory and streamed raw CSV per session.
  Startup recovers unfinished sessions as interrupted, without resuming partial
  repetitions. Snapshots retain the latest 200 sessions and 90 daily totals;
  raw traces remain on disk. Export uses the system share sheet after a user tap.
- `widgets/`: separate readiness, overview, live exercise, jump, pause/disconnect,
  history, summary and validation screens. Surfaces, buttons and typography use
  the existing theme; exercise icons are local SVG exports from Figma.

## Algorithms and known limits

Still calibration estimates gravity direction and magnitude. A complementary
filter propagates direction with the gyroscope and slowly corrects near 1 g.
Vertical acceleration is smoothed causally. Missing/invalid data, gaps above
120 ms and clock restarts reset partial states without changing totals.

Steps use peak prominence, an adaptive amplitude threshold, a 280 ms refractory
period, plausible 0.28–1.5 second intervals and a regular three-peak confirmation
window. The first three steps are credited together. One/two-step bouts can be
missed. Isolated peaks and strong head rotations are suppressed. This is a
heuristic starting point: head motions resembling gait can still cause errors.

Squats use a separate `models/squat_detector.dart`: bounded integration of
projected acceleration, a 0.12 m minimum motion proxy, a substantial return and
an upper turning-point check. A standing orientation reference and angular-speed
gate reject large posture changes. An undamped return reference protects held
descents. Squat-mode calibration uses a stable 0.7 s magnitude window and permits
small head rotations; other modes retain their 1.5 s calibration gate.
Push-ups have a separate detector: a quiet 0.7 s starting window estimates a
local acceleration offset after filter settling. Damped velocity and position
proxies limit accumulating drift. An undamped reference checks the return;
continuous cycles also compare speed and duration of both phases. This alternate
comparison is disabled after a hold so waiting cannot complete a partial return.
The minimum proxy excursion is 0.015 m, not a physical depth measurement.
Local movement rejection keeps the set ready without another starting-pose hold;
data gaps, pauses and mode changes still require fresh calibration. See
`models/push_up_detector.dart`.

These are heuristic motion proxies, not measured exercise depth or a form-quality
assessment. Fixed thresholds and independent head movement still need real-data
evaluation. The push-up regression suite uses synthetic kinematic signals only;
a full body cycle cannot always be inferred from the ear.

Jump height uses `h = g * flight_time² / 8`, with still preparation, propulsion,
a low-acceleration flight interval and landing confirmation. Similar take-off
and landing posture is assumed. It estimates ballistic flight height, not
absolute head displacement. Samples slower than 40 Hz, ambiguous landings and
clipped impacts produce an unavailable height. The ±2 g clipping heuristic is
conservative for the OE2 compact format. Walking/running is not classified.

Synthetic replay tests verify implementation behavior, **not real-world
accuracy**. Five local, mixed-activity recordings are available for squat
development. Their folder names supply ordered activity/count labels, not
timestamped event annotations. Matching totals can conceal false counts during
walking, stairs, sitting or push-ups. User-independent performance and
jump-height validity remain to be measured. See the German
[squat report](../../docs/algorithmen/kniebeugen.md) and `tool/squats/README.md`.

## Evaluation workflow

Record separate sessions/trials with synchronized reference video, independent
step/repetition annotations and a jump reference such as a contact mat or
calibrated high-frame-rate video. Use multiple participants, movement speeds,
execution styles and negative controls (talking, head turns, sitting, handling
the earable). Tune on development participants and evaluate on held-out users.

Study mode freezes detected results when opened. Choose session steps, a
completed exercise set or an individual jump attempt. Enter a participant ID,
movement pattern/trial label, reference source, reference count and optionally
reference jump height. Save the trial. Reference intervals must match the
chosen result; use separate sessions for independent step trials.

The UI computes signed count error, absolute percentage error (undefined for
zero reference), per-activity count MAE and paired jump-height MAE. Missing
height estimates stay missing; report valid-height coverage alongside height
error. Export includes trial identities, result labels and capture times.
Automatic exercise-classification accuracy is outside this manual-mode scope.

Each session export contains metadata JSON, reference-trials CSV and raw IMU
CSV with sensor timestamps, SI values, mode, pause/calibration status and event
deltas. Metadata includes the starting gravity calibration, and the raw trace
includes a bounded readiness pre-roll. Keep the exported JSON next to its CSV
to restore the initial calibration during replay.
Replay the same live algorithms with:

```sh
dart run tool/replay_activity_trace.dart /path/to/session.csv
```

Validation commands:

```sh
dart format lib/apps/activity_tracker test/apps/activity_tracker tool/replay_activity_trace.dart
flutter analyze
flutter test
```
