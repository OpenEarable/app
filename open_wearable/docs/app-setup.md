# App Setup and Architecture

This document describes the high-level setup of the OpenWearable Flutter app (`open_wearable/`), including startup, routing, shell layout, and lifecycle behavior.

## 1. Runtime Entry Point

Main entry point: `lib/main.dart`

Startup sequence:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. Create `LogFileManager` and initialize both app and library loggers.
3. Initialize persisted settings:
   - `AutoConnectPreferences.initialize()`
   - `AppShutdownSettings.initialize()`
4. Start app with `MultiProvider`.

The app wraps all screens in a single provider tree so global services/state are available everywhere.

## 2. Top-Level Provider Tree

Created in `main.dart`:

- `WearablesProvider` (`ChangeNotifierProvider`)
- `FirmwareUpdateRequestProvider` (`ChangeNotifierProvider`)
- `SensorRecorderProvider` (`ChangeNotifierProvider`)
- `WearableConnector` (`Provider.value`)
- `AppBannerController` (`ChangeNotifierProvider`)
- `LogFileManager` (`ChangeNotifierProvider.value`)

`MyApp` is stateful and subscribes to provider streams once, then orchestrates global side effects (dialogs, toasts, banners, lifecycle reactions).

## 3. App Shell and Navigation

Router config: `lib/router.dart`

- Router uses `GoRouter` with a global `rootNavigatorKey`.
- `HomePage` is mounted at `/` and receives optional section query parameter (`?tab=`).
- Primary routes:
  - `/` home shell
  - `/connect-devices`
  - `/device-detail`
  - `/log-files`
  - `/recordings`
  - `/settings/general`
  - `/fota` and `/fota/update`

### FOTA route guard

`/fota` redirects back to `/?tab=devices` on unsupported platforms and shows a platform dialog explaining the restriction.

## 4. Home Layout Structure

Main shell: `lib/widgets/home_page.dart`

Top-level sections:

1. Overview
2. Devices
3. Sensors
4. Apps
5. Settings

Behavior:

- Compact screens use `PlatformTabScaffold` with bottom navigation.
- Large screens use a `NavigationRail` + `IndexedStack` layout.
- `SensorPageController` lets other sections deep-link into specific tabs inside the Sensors page.

## 5. Lifecycle and Background Behavior

Handled centrally in `_MyAppState` (`main.dart`) via `WidgetsBindingObserver`.

Key behaviors:

- Auto-connect is stopped on pause and resumed on app resume depending on user setting.
- If "shut off all sensors on app close" is enabled, a grace-period timer is started when app goes inactive/paused.
- Background execution window is managed via `AppBackgroundExecutionBridge` while shutdown or recording protection is needed.
- If sensor shutdown completed while app was backgrounded, open app-flow screens are popped back to root on resume.

## 6. Connection and Event Handling

Two layers are used:

- `WearableConnector` (`lib/models/wearable_connector.dart`)
  - Direct connection API and event stream for connect/disconnect events.
- `BluetoothAutoConnector` (`lib/models/bluetooth_auto_connector.dart`)
  - Reconnect workflow based on remembered device names and user preference.

`MyApp` subscribes to connector/provider event streams to:

- Add wearables to global providers.
- Show firmware dialogs.
- Show app banners/toasts for important runtime events.

## 7. Feature Module Layout

High-level code organization under `lib/`:

- `widgets/`: shared UI and top-level pages.
- `view_models/`: provider-backed state and orchestration logic.
- `models/`: persistence, app-level settings, connection helpers, logging helpers.
- `apps/`: feature mini-apps (e.g., posture tracker, heart tracker).
- `theme/`: theming.
- `router.dart`: route table.
- `main.dart`: bootstrap and global lifecycle/event orchestration.

## 8. Persistence and Local State

Persisted settings/data include:

- Auto-connect preference and remembered names (`AutoConnectPreferences` + `SharedPreferences`).
- Shutdown/graph settings (`AppShutdownSettings` + `SharedPreferences`).
- Sensor profiles/configuration JSON files (`SensorConfigurationStorage`).
- Log files (`LogFileManager`).

## 9. Typical Runtime Flow

1. App starts and initializes settings/logging.
2. Providers are created.
3. Router builds Home shell.
4. User connects devices manually or auto-connect restores previous devices.
5. `WearablesProvider` initializes per-device sensor configuration state.
6. Sensors/config pages consume provider state and update UI.
7. Lifecycle transitions trigger shutdown/auto-connect policies.
