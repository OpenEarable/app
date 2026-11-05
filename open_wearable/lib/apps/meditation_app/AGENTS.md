# EarStreAM in-app contributor guide

## Scope and precedence

This file applies to `lib/apps/meditation_app/` and its descendants. EarStreAM
is a built-in feature module of the OpenWearables App, not a standalone Flutter
application. It has no independent entry point, router, device connection
stack, or application lifecycle.

Follow the repository-level `CONTRIBUTING.md` and the architecture guidance in
`open_wearable/docs/` first. This guide adds EarStreAM-specific ownership,
privacy, signal-processing, and validation requirements. When instructions
conflict, the narrower safety or privacy constraint wins; otherwise preserve
the established OpenWearables pattern.

The adjacent `README.md` is the user guide for the EarStreAM in-app. Keep
implementation details here rather than expanding that guide into developer
documentation.

## Place in OpenWearables

OpenWearables owns app startup, top-level routing, global providers, wearable
connections, device selection, sensor configuration state, application
lifecycle, and the **Apps** catalogue. EarStreAM owns only its feature-local
navigation, settings, sessions, signal interpretation, playback, and
analytics.

The launch boundary is intentional:

1. `lib/apps/widgets/apps_page.dart` advertises EarStreAM and declares its
   supported device family and capabilities.
2. OpenWearables' `SelectEarableView` supplies a connected wearable and its
   existing `SensorConfigurationProvider`.
3. The catalogue entry resolves the required PPG, accelerometer, and gyroscope
   sensors and constructs `MeditationView` with those dependencies.
4. EarStreAM returns control to the existing OpenWearables navigation stack
   when its view closes.

Do not add an EarStreAM `main()`, top-level route, connection manager, global
provider tree, or duplicate device selector. Do not make feature code discover
host state through global singletons when dependencies can cross the launch
boundary explicitly. EarStreAM's drawer is internal navigation within the
feature and must not replace or bypass the OpenWearables shell.

Keep changes outside `lib/apps/meditation_app/` as small and reviewable as
possible. Host-level changes must serve a documented integration need and must
preserve every existing in-app. Seal Check is a separate official
OpenWearables in-app; do not reintroduce a private copy inside EarStreAM.

EarStreAM is listed only on Android, iOS, macOS, and Windows. Keep the host
platform policy centralized in `model/earstream_platform_support.dart`. Linux
lacks a `flutter_tts` implementation, and direct browser calls to the supported
cloud APIs have no dependable CORS contract, so do not expose EarStreAM on
Linux or web without first providing and testing equivalent local speech,
credential, audio, and cloud behavior.

## Product contract

EarStreAM has three user-visible modes:

- **Biosignal-Adaptive** runs calibration, establishes a live baseline,
  monitors HR/RMSSD and activity, and starts adaptive guidance after stress is
  detected.
- **Timed** runs guidance without biosignals, either immediately or from an
  in-memory schedule.
- **Demo** offers a condensed biosignal-adaptive experience and a personalized
  meditation-only experience. Demo sessions use attendee-scoped preferences
  and are excluded from analytics.

Every mode must remain useful without cloud access. Local-only operation uses
static guidance, device TTS, and bundled ambience. Cloud failures must degrade
as documented below and must never bypass the user's cloud-processing choice.

This is a research/wellness feature, not a medical device. Do not describe a
threshold crossing as a diagnosis or hide uncertainty in the signal quality.

## Start here

The main responsibilities are deliberately separated:

| Area | Source of truth |
| --- | --- |
| Shared service, playback, prompt, and analytics constants | `configs/overall_config.dart` |
| Regular adaptive timing and detection policy | `configs/bio_adaptive_mode_config.dart` |
| Timed-mode scheduling and segment policy | `configs/timed_mode_config.dart` |
| Condensed conference-demo policy | `configs/demo_mode_config.dart` |
| Mapping regular/demo values into one adaptive pipeline | `model/bio_adaptive_session_config.dart` |
| Mutable session settings and configuration parsing | `model/user_account.dart` |
| Profile, preference, and consent persistence | `model/meditation_user_settings_store.dart` |
| Provider and credential persistence | `model/meditation_service_settings_store.dart` |
| Host-platform availability | `model/earstream_platform_support.dart` |
| Sensor subscription and recorded-stress sources | `model/biometric_source.dart` |
| HR/HRV processing and optical-channel selection | `model/hr_hrv_processor.dart` |
| Phase changes and measurement lifecycle | `model/measurement.dart` |
| Stress and activity policy | `model/stress_detector.dart`, `model/activity_tracker.dart` |
| Script generation and static fallbacks | `model/meditation_session_generator.dart` |
| Session, narration prefetch, and recovery lifecycle | `model/meditation.dart` |
| Cloud/device speech routing | `model/tts_service.dart` |
| Service checks | `model/service_connection_manager.dart` |
| In-app composition and navigation | `views/meditation_view.dart` |
| Mode UI | `views/meditation_modes/` |
| Settings and analytics UI | `views/pages/` |

Keep labels, icons, and presentation state in the views. Keep signal decoding,
mode decisions, provider routing, and persistence out of widgets so they remain
testable without a device.

## Host integration points

Changes to this subtree can require a small number of coordinated changes
elsewhere in `open_wearable/`:

- `lib/apps/widgets/apps_page.dart` registers EarStreAM, limits it to the
  `OpenEarable` device prefix, locates PPG/accelerometer/gyroscope sensors, and
  constructs `MeditationView`.
- `pubspec.yaml` declares shared package dependencies and bundles the EarStreAM
  assets. Any dependency change affects the whole OpenWearables app: justify
  additions, preserve compatible versions, and avoid unrelated upgrades.
  Flutter asset directory entries are not recursive, so keep both the
  top-level asset directory and `assets/audio/`; do not list tracks
  individually as well.
- Flutter tooling owns the generated Linux, macOS, and Windows plugin
  registrants. Regenerate them through `flutter pub get`; never hand-edit them.
- Android backup/data-extraction XML excludes the secure credential namespace,
  while `ios/Runner/Runner.entitlements` and the Runner Xcode build settings
  contain keychain access configuration.

Treat these as OpenWearables integration contracts, not as a second application
bootstrap. Do not make the meditation module silently reach into global host
state.

## Session and signal invariants

These behaviors are intentional and regression-tested. Change them only with a
clear product/research decision, updated configuration, and focused tests.

### Regular biosignal-adaptive mode

- Calibration lasts 30 seconds. It selects/commits the optical channel and must
  not leak calibration samples, detected peaks, or RR history into baseline.
- Baseline lasts at least five minutes and completes only after a valid HR and
  RMSSD pair exists. Do not add synthetic values merely to make it finish.
- With a complete age, gender, and fitness profile, the demographic prior can
  blend into the measured baseline beginning after one minute. Its weight
  falls from 70% to 30% by minute five. An incomplete profile, including
  `Gender.unspecified`, must not enable that blend.
- Monitoring uses both a rise in HR and a fall in RMSSD relative to baseline.
  The configured stress sensitivity is applied to both conditions.
- Sustained motion suppresses a new stress trigger in regular mode. It must not
  prevent recovery checks after a meditation has started.
- Recovery is HR-only: after a segment, HR at or below baseline can finish the
  session. RMSSD is deliberately not part of this exit decision.
- The regular session is capped at ten generated segments. Segment duration is
  narration-driven, not forced to the demo's 30-second duration.

### Demo isolation

- The biosignal demo uses 30-second calibration and baseline phases, a 3%
  stress threshold, best-effort beat-derived estimates, up to three 30-second
  segments, and a guaranteed trigger two minutes after monitoring begins.
- Activity is still classified and displayed in the demo but cannot suppress
  its trigger.
- Demo estimates may relax production confidence thresholds; they must remain
  derived from actual waveform/beat evidence. Never inject synthetic HR/RMSSD.
- `UserAccount.forConferenceDemo` may copy only service configuration and the
  cloud choice. Permanent profile, saved preferences, stress sensitivity,
  measured baseline, and analytics must not leak into the attendee session.
- `MeditationPromptPolicy.conferenceDemo` excludes permanent profile and
  physiological data. Both demo submodes use that policy.
- Demo sessions never receive an analytics store.

### Timed mode

- Timed mode has no biometric source and must not imply that it measured or
  reacted to stress.
- Its schedule is an in-process poll, not an OS alarm. It does not survive a
  restart and must not acquire native audio resources until the session starts.
- It uses the standard personalized prompt policy and three narration-driven
  segments.

### Signal processing

- Target rates are 200 Hz PPG and 25 Hz accelerometer/gyroscope, with the
  fallbacks defined in `BioAdaptiveModeConfig`.
- Live metric output is throttled by `metricEmitInterval` (currently three
  seconds). Recorded-stress playback aliases this value; keep both display
  cadences identical.
- Decode SDK samples through `sensor_sample_decoding.dart` and interpret axes
  through `sensor_axis_mapping.dart`. Sensor labels vary across firmware.
- Rank optical channels by perfusion index, apply the configured hysteresis and
  dwell, and commit a channel for the measurement. Uncontrolled switching can
  reset filters and corrupt the baseline.
- Beat timing defaults to the lightly filtered parallel path. Its 400 ms
  minimum beat interval prevents dicrotic-notch double counting. The fully
  conditioned path remains available for diagnostics/comparison.
- RMSSD must come from cleaned consecutive RR intervals derived from the same
  accepted beat stream used for HR. Do not compute it from display-rate HR
  points.
- A five-second PPG silence is treated as signal loss. Stream errors and normal
  completion must surface as loss instead of leaving a phase stalled forever.
- Tile streams are stable `late final` instances on `Measurement`. Do not
  derive a new stream inside a widget `build`; `StreamBuilder` would resubscribe
  and repeatedly fall back to the baseline display.

Low-level filter and detector coefficients live next to the algorithms in
`hr_hrv_processor.dart`, not in the high-level config files. If changing DSP,
capture/replay the same trace before and after, report beat/interval evidence,
and add regression coverage. Historical experiment tables do not belong in
README or AGENTS; preserve durable conclusions as comments/tests and keep raw
analysis in a dedicated research note when needed.

## Generation, narration, and audio

`Meditation` owns the shared lifecycle. Mode subclasses decide when another
segment is allowed, while `AdaptiveMeditationScript` owns sequential LLM
conversation state.

- DeepSeek is used only when `allowsCloudProcessing` and a valid DeepSeek key
  are both true. `createMeditationScript` is the central gate; do not duplicate
  or weaken it in a view.
- Standard prompts may include saved profile/preferences. Adaptive standard
  prompts may include current HR/RMSSD after a segment. Timed prompts explicitly
  have no biosignals. Conference-demo prompts may include only the attendee's
  meditation type and environment.
- An unavailable key or failed opening generation selects a local static
  script. A later generation failure substitutes a static segment so the
  session can continue.
- The richer demo fallback is generated into
  `model/demo_fallback_script.dart` from `tool/demo_fallback.json`. Edit the
  JSON and re-bake; do not hand-edit the generated Dart constants.
- Narration uses one ordered producer because each generated segment depends on
  the previous conversation. Non-biometric sessions may prefetch up to the
  configured depth. Biometric sessions are limited to one segment of lookahead
  so each request uses measurements sampled when the current segment starts.
- The decision to play a prefetched segment remains a post-segment recovery
  decision. Discard prefetched work when recovery ends the session.
- TTS routing is fixed when a meditation object is created. If the selected
  cloud provider is unusable at that point, use device TTS for the whole
  session. If it fails after cloud playback begins, retry using the configured
  delays and then stop; never change the voice midway through a meditation.
- Pause/resume must preserve narration position where the provider supports it.
  Device TTS may need to restart the utterance because the plugin has no
  dependable resume primitive.
- Ambience failure is non-fatal. Log it and continue with narration.
- Ambience assets are compressed MP3 files. Add new tracks under
  `assets/audio/`, use an `.mp3` `MeditationEnvironment.assetPath`, and verify
  decoding on supported platforms. Record each bundled track and its exact
  redistribution license in `ASSET_LICENSES.md`. Do not reintroduce WAV or
  demo-only TTS pipelines.
- EarStreAM acquires its wakelock only while its feature view is mounted and
  restores the OpenWearables app's desired wakelock state on exit. A wakelock
  error must never prevent a session from starting.

## Privacy, persistence, and secrets

Privacy is a runtime boundary, not just UI text.

- `cloudProcessingConsent == null` means no decision has been saved and forces
  the first-use choice. Both `null` and `false` disable DeepSeek and cloud TTS.
- The choice can be changed later on **Privacy & Data**. Local-only mode retains
  configured credentials but never uses them.
- Gate cloud generation, provider availability, and live service checks on the
  consent state. New cloud features need an explicit disclosure and the same
  central enforcement.
- Profile, preferences, consent, and analytics use app-local preferences. API
  secrets use `flutter_secure_storage`; provider, region, voice, and verified
  state use ordinary preferences.
- A fresh OpenWearables installation has no EarStreAM service credentials.
  Once the device has saved service settings, that snapshot wins, including
  deliberately cleared keys.
- Verification responses are revisioned. Do not let a stale request mark
  edited credentials or a different region as valid.
- **Delete all EarStreAM data** must clear user settings, service credentials,
  consent, measured baseline, and analytics, and must not affect other in-apps.
- Never print API keys or raw secrets. Signal capture is opt-in diagnostic data
  and must be treated as sensitive.
- Do not bundle `.env` or any other credential asset. Users configure services
  through **API Keys**; the opt-in demo fallback generator reads its key only
  from the developer shell environment.

## Safe extension paths

### Add or change a mode

1. Put policy constants in a mode-specific file under `configs/`.
2. If it uses biosignals, map them through `BioAdaptiveSessionConfig` instead
   of forking the measurement pipeline.
3. Add the mode and its description to `views/pages/meditation_page.dart`.
4. Decide explicitly whether it receives permanent profile data, biosignals,
   analytics, activity suppression, stress simulation, and cloud prompts.
5. Exercise start, pause, resume, stop, completion, sensor loss, cloud failure,
   and local-only operation in tests.

### Add a cloud provider

1. Extend the provider/account types and immutable session-time snapshot.
2. Add verification in `service_connection_manager.dart`.
3. Store secrets through `MeditationServiceSettingsStore`, including clear and
   migration behavior; do not put them in `SharedPreferences`.
4. Add settings UI, consent disclosure, privacy-policy access, and deletion.
5. Implement a `TtsProvider` (or a separate generation abstraction), retain
   fixed per-session routing, and add timeout/retry tests.

### Add a user preference

1. Add the nullable/default value to `UserAccount`.
2. Add parsing and persistence to the correct settings store.
3. Wire every editing surface to the shared account and save callback.
4. Decide whether it is allowed in standard prompts, demo prompts, TTS only,
   or never sent to cloud services.
5. Clear it in the EarStreAM reset path and add round-trip tests.

### Support another wearable or sensor schema

1. Update host registration and compatibility checks in
   `lib/apps/widgets/apps_page.dart`.
2. Keep SDK-to-domain translation in the decoding/axis-mapping helpers.
3. Confirm actual units, labels, sample ordering, and achievable rates on
   hardware; do not infer axes from list position when names exist.
4. Revalidate channel selection, signal-loss timing, filters, beat detection,
   baseline completion, motion suppression, and audio coexistence.

## Diagnostics

Diagnostics are debug-only and opt-in. From `open_wearable/`:

```powershell
flutter run --dart-define=MEDITATION_HR_HRV_TRACE=true
flutter run --dart-define=MEDITATION_PPG_RATE_LOG=true
flutter run --dart-define=MEDITATION_HR_HRV_SUMMARY_LOG=true
flutter run --dart-define=MEDITATION_DETECTOR_COMPARE_LOG=true
flutter run --dart-define=MEDITATION_BEAT_QUALITY_LOG=true
```

`MEDITATION_HR_HRV_TRACE` writes bounded JSONL trace events in the app support
directory. It does not include raw PPG unless full capture is explicitly
enabled:

```powershell
flutter run --dart-define=MEDITATION_CAPTURE_SIGNAL=true
```

Full capture can grow to 256 MiB and contains sensitive raw PPG/IMU and
conditioned signal data. Use only with informed participants, transfer it
carefully, and delete it after analysis. Replay a capture with:

```powershell
flutter test test/apps/meditation_app/trace_replay_test.dart "--dart-define=MEDITATION_TRACE=C:\path\capture.jsonl"
```

`MEDITATION_SKIP_BACKGROUND_MUSIC=true` is a trace-only aid for isolating audio
interaction and must not change normal production behavior.

## Validation

Run commands from `open_wearable/`. During iteration, prefer the narrowest
relevant checks:

```powershell
dart analyze lib/apps/meditation_app
dart analyze test/apps/meditation_app
flutter test test/apps/meditation_app
```

Before handing off a material EarStreAM change, and always after changing the
app catalogue, dependencies, assets, or platform integration, validate the
entire OpenWearables app as required by `CONTRIBUTING.md`:

```powershell
dart format lib test
flutter analyze
flutter test
```

The full-app checks are required because EarStreAM shares the Flutter process,
dependency graph, plugin registrants, wearable connection, and sensor
configuration state with every other in-app.

Important suites include:

- `hr_hrv_processor_test.dart`: processing configuration, phase behavior,
  stress/recovery policy, provider parsing, privacy policy, persistence-adjacent
  behavior, and other domain regressions.
- `baseline_blend_test.dart`: demographic prior and measured-baseline blending.
- `sensor_sample_decoding_test.dart`: firmware label/axis/sample translation.
- `meditation_pipeline_test.dart`: generation/TTS overlap, prefetch bounds,
  early-exit discard, stop, pause, and provider failure behavior.
- `meditation_service_settings_store_test.dart`: persisted service state,
  secure-secret behavior, consent/settings reset, and write ordering.
- `heart_rate_chart_test.dart`: stable presentation of measurement streams.
- `demo_fallback_script_test.dart`: all attendee preference combinations.
- `trace_replay_test.dart`: opt-in analysis of real captured signals.

The demo fallback generator is intentionally skipped unless
`GENERATE_DEMO_FALLBACK=true`; it is the only test intended to call DeepSeek.
Normal tests must not use the network or real API credentials.

Do not claim completion from static analysis alone when changing session
lifecycle, persistence, privacy enforcement, signal processing, or audio. Add
or update a focused test, then run the full meditation test directory. Build or
hardware validation is warranted for dependency, platform, asset, secure
storage, sensor, or audio-route changes.

## Documentation and completion checklist

Before handing off a material change, confirm:

- regular, timed, and both demo paths still have an intentional behavior;
- local-only mode cannot reach cloud generation, TTS, or connection checks;
- demo prompts and analytics remain isolated;
- saved settings load after restart and deletion does not retain credentials;
- sensor disconnect, stream error, and missing valid baseline do not silently
  strand the UI;
- fallback guidance, device TTS, and ambience failure behavior still work;
- any new asset is compressed, declared once, and included in size review;
- tests cover the changed policy or lifecycle edge; and
- `README.md` is updated only when the user-visible workflow changes.

Keep this guide about durable architecture, invariants, adaptation, and
validation. Put detailed benchmark data, one-off debugging transcripts, and
conference deployment diaries in dedicated notes rather than either primary
document.
