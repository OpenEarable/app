# Sensor Pages

## `SensorPage` (`lib/widgets/sensors/sensor_page.dart`)
- Needs:
  - `WearablesProvider` for connected wearables and capability checks.
  - Optional `SensorPageController` for external tab switching.
- Does:
  - Hosts three sensor tabs: Configure, Live Data, Recorder.
  - Maintains shared `(Wearable, Sensor) -> SensorDataProvider` instances.
  - Keeps providers in sync with wearable connect/disconnect events.
- Provides:
  - Main sensor workspace and tab navigation.
  - Shared live-data provider map for child tabs.

## `SensorConfigurationView` (`lib/widgets/sensors/configuration/sensor_configuration_view.dart`)
- Needs:
  - `WearablesProvider` and its per-device `SensorConfigurationProvider` instances.
  - Wearables with `SensorConfigurationManager` capabilities.
- Does:
  - Renders configuration rows per wearable/group.
  - Supports mirrored apply behavior for stereo pairs.
  - Applies pending/unknown config entries via `config.setConfiguration(...)`.
- Provides:
  - Multi-device configuration dashboard.
  - "Apply Profiles" action to push selected settings to hardware.

## `SensorConfigurationDetailView` (`lib/widgets/sensors/configuration/sensor_configuration_detail_view.dart`)
- Needs:
  - Constructor `sensorConfiguration`.
  - `SensorConfigurationProvider` in scope.
  - Optional paired config/provider for mirrored updates.
- Does:
  - Edits data target options and sampling rate for one configuration.
  - Keeps local selected state in provider and can mirror to paired device config.
- Provides:
  - Fine-grained configuration editor UI.

## `SensorValuesPage` (`lib/widgets/sensors/values/sensor_values_page.dart`)
- Needs:
  - `WearablesProvider` for device/sensor discovery.
  - `SensorDataProvider` instances (shared map from parent or owned locally).
  - App settings listenables from `AppShutdownSettings` for graph behavior.
- Does:
  - Builds sensor cards for all active sensors across wearables.
  - Supports no-graph mode and hide-empty-graphs mode.
  - Uses merged provider listenables for efficient live refresh.
- Provides:
  - Live chart/value surface for all connected sensors.

## `LocalRecorderView` (`lib/widgets/sensors/local_recorder/local_recorder_view.dart`)
- Needs:
  - `SensorRecorderProvider` and `WearablesProvider`.
  - File-system access helpers in `local_recorder_storage.dart`.
- Does:
  - Starts/stops recording sessions and tracks elapsed runtime.
  - Offers optional "stop and turn off sensors" behavior.
  - Lists most recent recording folder and supports file/folder actions.
- Provides:
  - In-tab recording control center.
  - Shortcut navigation to full recording history.

## `LocalRecorderAllRecordingsPage` (`lib/widgets/sensors/local_recorder/local_recorder_all_recordings_page.dart`)
- Needs:
  - Constructor input: `isRecording`.
  - Recording storage helpers and file action helpers.
- Does:
  - Displays all recording folders with expansion and file actions.
  - Supports batch selection, share, and delete flows.
- Provides:
  - Complete recording history management UI.
