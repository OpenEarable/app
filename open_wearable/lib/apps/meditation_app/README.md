# EarStreAM for OpenWearables

EarStreAM is the guided-meditation in-app included in the OpenWearables App. It combines timed meditation with optional stress-adaptive guidance based on live signals from a compatible OpenEarable. EarStreAM is opened from the
OpenWearables **Apps** section and is not installed or run as a separate app. It received one of the Best Demo Awards at UbiComp 2026 in Shanghai.

## Open EarStreAM

1. In OpenWearables, connect a compatible OpenEarable.
2. If the earbud fit is uncertain, use the separate **Seal Check** in-app from
   the same **Apps** section.
3. Open **Apps**, select **EarStreAM**, and choose the connected wearable.
4. On first use, choose between cloud personalization and fully local
   meditation.
5. Select **Meditation Mode**, choose a mode, and follow the on-screen controls.

Biosignal-adaptive sessions require PPG, accelerometer, and gyroscope sensors.
Timed meditation does not use those measurements, but it currently opens
through the same OpenWearables device-selection flow and therefore still
requires a connected compatible wearable.

Keep OpenWearables active during a session. EarStreAM keeps the screen awake
while it is open, but it does not run as a background service.

EarStreAM is currently exposed by the OpenWearables catalogue on Android, iOS,
macOS, and Windows. It is hidden on Linux because device text-to-speech is not
available through the selected Flutter plugin, and on web because the optional
cloud providers do not offer a dependable browser CORS contract.

## Meditation modes

### Biosignal-Adaptive

This mode uses PPG to estimate heart rate and heart-rate variability (RMSSD).
Accelerometer and gyroscope data help prevent sustained physical activity from
being interpreted as stress.

The session first performs a 30-second signal calibration, followed by a live
baseline of at least five minutes. Monitoring then compares new measurements
with that baseline. When heart rate rises and RMSSD falls beyond the selected
sensitivity while the user is sufficiently still, EarStreAM starts guided
meditation. It checks for recovery after each segment and may finish early.

**Play Recorded Stress** is provided for testing and demonstrations. It plays a
fixed stress-and-relaxation trajectory at the same display cadence as live
measurements; it does not represent the current user's body.

### Timed

Timed mode starts guidance without using biosignals. A session can start
immediately, after 5, 10, or 30 minutes, or at a selected time.

Scheduling exists only while OpenWearables remains active. It is not a system
alarm or notification, and a scheduled session is lost when the app closes or
restarts.

### Demo

Demo mode is a shorter experience intended for demonstrations. It offers a
condensed biosignal-adaptive flow and a personalized meditation flow without
biosignals. Demo sessions use temporary attendee preferences and are not added
to Weekly Analytics.

## Personalization and privacy

EarStreAM asks for an explicit data-processing choice on first use:

- **Local only** uses pre-written guidance, on-device text-to-speech, and
  bundled MP3 ambience. Profile data, preferences, measurements, and narration
  are not sent to the supported cloud providers.
- **Cloud personalization** can use DeepSeek to generate guidance from the
  saved profile and meditation preferences. Biosignal-adaptive guidance may
  also include heart rate and HRV readings after meditation segments. The
  selected ElevenLabs or Tencent service receives narration text to turn it
  into speech.

The choice can be changed later under **Privacy & Data**. Selecting local-only
mode keeps saved credentials on the device but does not use them.

The same page can delete all EarStreAM data, including profile information,
preferences, service credentials, cloud choice, measured baseline, and weekly
analytics. Data belonging to other OpenWearables in-apps is not affected.

## Configure EarStreAM

Settings are available from the menu inside EarStreAM and persist when
EarStreAM or the OpenWearables App is closed.

### Profile

The optional profile contains first name, age, gender, and fitness level. A
complete demographic profile can support the early baseline estimate and
cloud-personalized wording. Leaving fields empty is supported.

### Meditation Preferences

Choose the preferred voice gender and speed, guidance style, ambience,
free-text guidance preferences, and stress sensitivity. The four nature
ambience tracks are bundled with OpenWearables and play locally.

### API Keys

Cloud services are optional. EarStreAM supports:

- **DeepSeek** for generated meditation guidance;
- **ElevenLabs** for cloud speech and selectable voices; and
- **Tencent Cloud TTS** for cloud speech, with International (Singapore) and
  Mainland China (Guangzhou) processing choices.

Credentials are entered and verified inside EarStreAM. API secrets are stored
using the operating system's protected credential storage, while service and
voice selections are stored in the OpenWearables app data. Using cloud
services may incur charges on the associated provider accounts.

If cloud guidance is unavailable when a session starts, EarStreAM uses local
guidance. If the selected cloud voice is unavailable at startup, it uses
on-device speech for that session. A cloud voice that repeatedly fails during
an active session stops the session instead of unexpectedly changing voices.

### Weekly Analytics

Weekly Analytics summarizes regular biosignal-adaptive and timed sessions,
including duration, completion rate, active days, mode use, and recent
sessions. Records remain local and are retained for up to 366 days. Demo
sessions and post-session mood choices are not included.

## Troubleshooting

- **EarStreAM is unavailable:** connect a compatible OpenEarable from the
  OpenWearables **Devices** section, then return to **Apps**.
- **Required sensors are missing:** reconnect the wearable and confirm that it
  exposes PPG, accelerometer, and gyroscope sensors.
- **Calibration or baseline does not finish:** reseat the earbud, use the
  separate Seal Check in-app, remain still, and wait for a reliable signal.
- **Meditation does not start while moving:** regular adaptive mode suppresses
  new stress triggers during sustained activity.
- **Cloud guidance or speech is not used:** confirm the cloud choice, selected
  provider, credentials, and connection check under **API Keys**.
- **A scheduled session did not start:** timed schedules require OpenWearables
  to remain active and do not survive a restart.
- **A live session stops after disconnection:** reconnect the wearable and
  start a new session.

Signal quality and stress estimates depend on fit, motion, skin contact, and
the connected hardware. Network loss, operating-system suspension, or a cloud
provider outage can interrupt cloud-enabled sessions.

## Asset licensing

The four bundled ambient recordings are released under CC0. See
[ASSET_LICENSES.md](ASSET_LICENSES.md) for the exact files and license scope.
