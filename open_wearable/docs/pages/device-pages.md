# Device Pages

## `DevicesPage` (`lib/widgets/devices/devices_page.dart`)
- Needs:
  - `WearablesProvider` with current `wearables` list.
  - `WearableDisplayGroup` helpers for pair/single grouping and ordering.
- Does:
  - Shows connected wearables as list (small screens) or grid (large screens).
  - Supports pull-to-refresh by attempting `connectToSystemDevices()`.
  - Allows pair combine/split UI mode through `WearablesProvider` stereo pair state.
- Provides:
  - Main device inventory view.
  - Entry into `DeviceDetailPage` and connect flow.

## `ConnectDevicesPage` (`lib/widgets/devices/connect_devices_page.dart`)
- Needs:
  - `WearablesProvider` (to display connected devices and add new connections).
  - `WearableConnector` provider for explicit connect actions.
  - `WearableManager` scan/connect capabilities and runtime BLE permissions.
- Does:
  - Starts BLE scanning on page open and allows manual refresh/rescan.
  - Displays connected and available devices separately.
  - Connects selected devices and updates global wearable state.
- Provides:
  - Device discovery and connection workflow.
  - Scan status and actionable connection UI.

## `DeviceDetailPage` (`lib/widgets/devices/device_detail/device_detail_page.dart`)
- Needs:
  - Constructor input: `Wearable device`.
  - `WearablesProvider` (for sensor shutdown/disconnect helper flow).
  - `FirmwareUpdateRequestProvider` (for preselecting FOTA target).
  - Device capabilities to unlock sections (`AudioModeManager`, `RgbLed`, `StatusLed`, `Battery*`, etc.).
- Does:
  - Shows detailed per-device controls and metadata.
  - Handles disconnect flow and "forget" helper (system settings handoff).
  - Prepares firmware update target and navigates to FOTA flow.
- Provides:
  - Capability-aware control surface for one wearable.
  - Path from device details to firmware update workflow.
