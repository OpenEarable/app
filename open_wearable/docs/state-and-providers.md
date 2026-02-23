# State and Providers

This document explains how state is handled in the app, with emphasis on provider responsibilities and data flow.

## 1. State Management Model

The app uses `provider` with a mixed approach:

- Global `ChangeNotifier` providers for app-wide state.
- Plain `Provider` for stateless services.
- Feature-local providers created on demand (for per-device/per-sensor state).
- Streams from `open_earable_flutter` bridged into provider state.

Main provider wiring starts in `lib/main.dart`.

## 2. Global Providers

## `WearablesProvider`

File: `lib/view_models/wearables_provider.dart`

Responsibilities:

- Source of truth for connected wearables.
- Creates and stores one `SensorConfigurationProvider` per wearable.
- Tracks stereo pair combine/split UI preference.
- Emits high-level streams for:
  - unsupported firmware events
  - wearable events (time sync, errors, firmware update availability)
- Handles capability updates and sync side effects (for example time synchronization).

Used by:

- Devices page
- Sensor configuration pages
- Sensor page orchestration
- Mini-app device selectors

## `SensorRecorderProvider`

File: `lib/view_models/sensor_recorder_provider.dart`

Responsibilities:

- Tracks recording session state (`isRecording`, start time, output directory).
- Manages per-wearable/per-sensor `Recorder` instances.
- Starts/stops recording streams for all connected sensors.
- Handles recorder setup for wearables that connect during an active recording session.

Used by:

- Recorder tab UI
- App lifecycle logic in `main.dart` to prevent shutdown while recording

## `FirmwareUpdateRequestProvider`

Provided globally in `main.dart` (type comes from `open_earable_flutter`).

Responsibilities:

- Holds FOTA selection/update context used across warning/select/update screens.

Used by:

- FOTA flow widgets under `lib/widgets/fota/`

## `AppBannerController`

File: `lib/view_models/app_banner_controller.dart`

Responsibilities:

- Stores active transient `AppBanner` entries.
- Provides methods to show/hide banners.

Used by:

- `GlobalAppBannerOverlay`
- `main.dart` event handling (maps wearable events to banners)

## `WearableConnector`

File: `lib/models/wearable_connector.dart`

This is provided with `Provider.value` (not `ChangeNotifier`).

Responsibilities:

- Encapsulates direct `WearableManager` connection calls.
- Emits connect/disconnect events as a stream.

Used by:

- Device connect UI
- `main.dart` global event wiring

## `LogFileManager`

Provided as `ChangeNotifierProvider.value` in `main.dart`.

Responsibilities:

- Owns logging file operations and state for log browsing screens.

## 3. Per-Device and Per-Sensor Providers

## `SensorConfigurationProvider` (per wearable)

File: `lib/view_models/sensor_configuration_provider.dart`

Created by `WearablesProvider` per connected wearable.

Responsibilities:

- Tracks selected config values.
- Tracks pending (optimistic) edits until hardware reports matching values.
- Tracks last reported device configuration snapshot.
- Resolves whether a configuration is selected/applied/pending.

Consumption pattern:

- `SensorConfigurationView` pulls provider instances from `WearablesProvider`.
- It passes each via `ChangeNotifierProvider.value` into row/detail widgets.

## `SensorDataProvider` (per wearable + sensor)

File: `lib/view_models/sensor_data_provider.dart`

Created and owned by `SensorPage` as a map keyed by `(Wearable, Sensor)`.

Responsibilities:

- Subscribes to sensor stream (`SensorStreams.shared(sensor)`).
- Maintains rolling time-window queue for charting and value displays.
- Uses throttled notifications for UI smoothness.
- Handles stale/silent stream behavior so charts age out correctly.

Consumption pattern:

- Passed down to live data cards/details using `ChangeNotifierProvider.value`.

## 4. Data Flow: Connection -> UI

1. Connection succeeds via `WearableConnector` or auto-connect.
2. `main.dart` receives event and calls:
   - `WearablesProvider.addWearable(...)`
   - `SensorRecorderProvider.addWearable(...)`
3. `WearablesProvider` creates/updates per-device `SensorConfigurationProvider` and subscriptions.
4. UI consumers (`Consumer`, `watch`, `read`) rebuild where needed.
5. Sensor pages create `SensorDataProvider` instances for available sensors and stream live updates.

## 5. Data Flow: Config Edit -> Hardware Apply

1. User modifies selections in `SensorConfigurationProvider` (local/pending state).
2. UI marks pending values.
3. User taps "Apply Profiles".
4. `SensorConfigurationView` sends selected values to hardware (`config.setConfiguration(...)`).
5. Provider stream receives hardware report; pending entries are cleared when values match.

For stereo pairs, mirrored target entries can be applied alongside primary entries.

## 6. Data Flow: App Lifecycle

App lifecycle handling in `main.dart` coordinates provider state:

- Uses `SensorRecorderProvider.isRecording` to decide whether shutdown should be deferred.
- Uses `WearablesProvider.turnOffSensorsForAllDevices()` when close-shutdown setting is enabled.
- Uses `AutoConnectPreferences` + `BluetoothAutoConnector` to pause/resume reconnection policy.

## 7. Persistence Boundaries

- `SharedPreferences`:
  - auto-connect toggles and remembered names
  - app shutdown/graph settings
- File storage:
  - sensor profile JSONs via `SensorConfigurationStorage`
  - log files via `LogFileManager`

Providers remain in-memory runtime state; persistence is delegated to model/storage helpers.

## 8. Practical Rules for Adding State

When introducing new state:

1. Put cross-screen runtime state in a top-level provider.
2. Keep feature-specific transient state near the widget tree that owns it.
3. Keep persistence out of widgets; use model/storage helpers.
4. Prefer stream-to-provider adapters over direct widget stream subscriptions.
5. Use `ChangeNotifierProvider.value` only for existing provider instances (already-created objects).
