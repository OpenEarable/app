# Apps Pages

## `AppsPage` (`lib/apps/widgets/apps_page.dart`)
- Needs:
  - `WearablesProvider` for connected wearables.
  - App catalog entries (`_apps`) with compatibility metadata.
- Does:
  - Computes enabled/disabled app tiles based on compatible connected devices.
  - Renders app catalog and app-level status summary.
- Provides:
  - Launch entry point for mini-app experiences.
  - Reuses the app compatibility framework documented in `docs/app-compatibility.md`.

## `SelectEarableView` (`lib/apps/widgets/select_earable_view.dart`)
- Needs:
  - Constructor inputs:
    - `startApp(Wearable, SensorConfigurationProvider)` callback
    - `supportedDevices`
  - `WearablesProvider` with sensor config providers for candidate devices.
- Does:
  - Filters connected wearables by app compatibility.
  - Lets user select one wearable and launches app with scoped provider context.
- Provides:
  - Compatibility-safe wearable picker for app flows.

## Compatibility Model

- App compatibility is implemented in `lib/apps/widgets/app_compatibility.dart`.
- Apps declare `List<AppSupportOption>` instead of raw supported-device prefix strings.
- Each `AppSupportOption` combines:
  - a user-facing `label`
  - an `AppRequirement` matcher
- `AppRequirement` supports:
  - wearable name matching
  - capability presence checks
  - capability property predicates
  - logical composition with `allOf` and `anyOf`
- Full details and examples are documented in `docs/app-compatibility.md`.

## `HeartTrackerPage` (`lib/apps/heart_tracker/widgets/heart_tracker_page.dart`)
- Needs:
  - Constructor inputs:
    - `wearable`
    - `ppgSensor` (required)
    - optional accelerometer and optical temperature sensors
  - `SensorConfigurationProvider` in scope.
- Does:
  - Configures required sensor streaming settings on enter.
  - Builds OpenRing-specific or generic PPG processing pipeline.
  - Produces heart-rate/HRV/signal-quality streams for UI charts.
  - Restores/turns off configured streaming settings on dispose (best effort).
- Provides:
  - Heart metrics visualization and quality feedback workflow.

## `PostureTrackerView` (`lib/apps/posture_tracker/view/posture_tracker_view.dart`)
- Needs:
  - Constructor input: `AttitudeTracker` implementation.
- Does:
  - Creates and owns `PostureTrackerViewModel`.
  - Displays live posture state, thresholds, and tracking controls.
  - Opens app-specific settings page.
- Provides:
  - Posture tracking runtime view and control surface.

## `SettingsView` (Posture) (`lib/apps/posture_tracker/view/settings_view.dart`)
- Needs:
  - Constructor input: existing `PostureTrackerViewModel`.
- Does:
  - Edits posture reminder thresholds and tracking behavior.
  - Supports calibration action and tracking start.
- Provides:
  - App-specific posture tuning and calibration settings.
