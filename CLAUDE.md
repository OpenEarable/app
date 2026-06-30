# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Layout

This repo is a wrapper around a single Flutter app module. **All app code lives in [`open_wearable/`](./open_wearable/)** — run every Flutter command from inside that directory.

```
app/                      # repo root (README, CONTRIBUTING, LICENSE, CI lives in .github/)
└── open_wearable/        # the Flutter app module — work here
```

The app depends on a **sibling package via local path**: `open_earable_flutter` at `../../open_earable_flutter` (i.e. a checkout two levels up from `open_wearable/`). It supplies the device/wearable abstractions (`WearableManager`, sensors, FOTA, recording). When tracing connection, sensor, or firmware behavior, that package — not this repo — is the source of truth for the hardware layer.

## Commands

Run from `open_wearable/`:

```bash
flutter pub get          # fetch dependencies
flutter run              # run on connected device/emulator
flutter run --release    # install/run in release mode

# Validation before any PR (CI runs analyze + tests):
dart format lib test
flutter analyze
flutter test
flutter test test/models/auto_connect_preferences_test.dart   # single test file
flutter test --name "substring of test name"                  # single test by name
```

Flutter SDK is pinned in `open_wearable/.flutter_version` (currently `3.44.0`, stable channel, Dart `^3.6.0`). The app targets **all six platforms**: Android, iOS, web, Linux, macOS, Windows. CI (`.github/workflows/`) builds Android/Linux/Windows/web on PRs and deploys web to Firebase + GitHub Pages on merge to `main`.

## Architecture

Full architecture docs live in [`open_wearable/docs/`](./open_wearable/docs/) — read these before substantial changes:
- `docs/app-setup.md` — startup, routing, shell, lifecycle
- `docs/state-and-providers.md` — provider responsibilities and data flow
- `docs/connectors/websocket-ipc-api.md` — the WebSocket IPC protocol
- `docs/pages/` — per-section page docs; `docs/upgrade-highlights.md` — "What's new" flow

### State management: `provider`, layered by lifetime

State is `provider`-based with a deliberate split by lifetime — match this when adding state:
- **Global** providers wired once in `lib/main.dart`'s `MultiProvider`: `WearablesProvider`, `SensorRecorderProvider`, `FirmwareUpdateRequestProvider`, `WearableConnector` (plain `Provider.value`, not a notifier), `AppBannerController`, `LogFileManager`.
- **Per-device / per-sensor** providers created on demand: `WearablesProvider` creates one `SensorConfigurationProvider` per wearable; `SensorPage` owns a map of `SensorDataProvider` keyed by `(Wearable, Sensor)`. These are handed to children via `ChangeNotifierProvider.value` (used **only** for already-created instances).
- Hardware streams from `open_earable_flutter` are bridged into provider state rather than subscribed to directly in widgets.

### `main.dart` is the global orchestrator

`_MyAppState` (stateful, a `WidgetsBindingObserver`) is where global side effects live. It subscribes once to connector/provider streams and maps events to dialogs, toasts, and banners; it also drives lifecycle policy:
- **Auto-connect**: paused on app pause, resumed on resume per `AutoConnectPreferences` (via `BluetoothAutoConnector`).
- **Shutdown-on-close**: if enabled, a grace-period timer turns off all sensors when the app goes inactive — but `SensorRecorderProvider.isRecording` defers shutdown while a recording is active. `AppBackgroundExecutionBridge` holds a background execution window while shutdown/recording protection is needed.

### Connection layers

Two layers sit above `open_earable_flutter`'s `WearableManager`:
- `WearableConnector` (`lib/models/wearable_connector.dart`) — direct connect API + connect/disconnect event stream.
- `BluetoothAutoConnector` (`lib/models/bluetooth_auto_connector.dart`) — reconnect workflow keyed on remembered device names.

### Config edit → hardware apply (optimistic)

`SensorConfigurationProvider` holds local *pending* edits. On "Apply Profiles", `SensorConfigurationView` calls `config.setConfiguration(...)`; pending entries clear only when the hardware's reported config stream reports matching values. Stereo pairs can mirror target entries onto a paired device.

### WebSocket IPC connector

`lib/models/connectors/` exposes the app's capabilities over a JSON-over-WebSocket server (`websocket_ipc_server.dart`, default `ws://<ip>:8765/ws`) so external clients (e.g. the Python `open-wearables` package) can scan, connect, stream sensors, and play audio. Each IPC method is a `Command` in `connectors/commands/`. **Adding a method = adding a command class** and registering it; keep `docs/connectors/websocket-ipc-api.md` in sync with the protocol.

### Routing

`go_router` with a global `rootNavigatorKey` in `lib/router.dart`. `HomePage` (`/`) is the shell with sections Overview / Devices / Sensors / Apps / Settings — compact screens use bottom nav, large screens a `NavigationRail` + `IndexedStack`. The `/fota` route guards against unsupported platforms.

### Platform-conditional code

Web vs. native is handled via conditional imports / `_io` / `_web` / `_stub` file suffixes (e.g. `lib/models/network/device_ip_address{_io,_stub}.dart`, `lib/view_models/sensor_recorder_provider{_io,_web}.dart`). When touching IO/network/recording code, update the matching platform variants together.

### Persistence boundaries

Providers stay in-memory; persistence is delegated to model/storage helpers. `SharedPreferences` holds toggles (auto-connect names, shutdown/graph settings); file storage holds sensor profile JSONs (`SensorConfigurationStorage`) and log files (`LogFileManager`). Keep persistence out of widgets.

### Feature mini-apps

`lib/apps/` holds self-contained demos (`posture_tracker`, `heart_tracker`) with their own assets registered in `pubspec.yaml`.

## Conventions (from CONTRIBUTING.md)

- **Linear history via rebase, never merge.** Branch from latest `main`; rebase onto `main` before opening/updating a PR; push with `--force-with-lease`, never plain `--force`.
- **Conventional Commits** required: `<type>(<scope>): <summary>` in imperative mood. Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `build`, `ci`, `perf`. Scopes seen in history: `connectors`, `audio`, `devices`, `sensors`, `android`, `version`.
- Small, focused PRs; no drive-by reformatting or unrelated dependency bumps.
- Document public classes/functions and non-obvious decisions; update the relevant `docs/*.md` when a change affects architecture, app flow, or the IPC protocol.
- Lints beyond `flutter_lints` are enforced in `analysis_options.yaml` (notably `require_trailing_commas`, `always_declare_return_types`, `cancel_subscriptions`, `prefer_interpolation_to_compose_strings`).
