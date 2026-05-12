# Firmware Update (FOTA) Pages

## `FotaWarningPage` (`lib/widgets/fota/fota_warning_page.dart`)
- Needs:
  - `FirmwareUpdateRequestProvider` with selected wearable.
  - Battery capability on selected device for pre-check (`BatteryLevelStatus`) if available.
- Does:
  - Presents update risk checklist and recovery guidance link.
  - Reads battery level and enforces warning/confirmation gates below threshold.
  - Routes to `/fota/update` when user proceeds.
- Provides:
  - Safety gate before update execution.

## `FirmwareUpdateWidget` (`lib/widgets/fota/firmware_update.dart`)
- Needs:
  - `FirmwareUpdateRequestProvider` in scope.
  - Valid selected firmware for step 0 -> step 1 transition.
- Does:
  - Hosts two-step flow (select firmware, install firmware).
  - Prevents back navigation while update is active.
  - Creates `UpdateBloc` for install step.
  - Caches wearable metadata (name/side label) for post-update verification UX.
- Provides:
  - Main firmware update execution page.

## `UpdateStepView` (`lib/widgets/fota/stepper_view/update_view.dart`)
- Needs:
  - `UpdateBloc` and `FirmwareUpdateRequestProvider` in context.
  - Optional callbacks for update running-state reporting.
- Does:
  - Starts update automatically when configured (`autoStart`).
  - Renders update timeline/history and current stage.
  - Arms and displays post-update verification banner on successful completion.
  - Provides link to update logger view when available.
- Provides:
  - Detailed progress and outcome UI for the update process.

## `FotaSlotsPage` (`lib/widgets/fota/fota_slots_page.dart`)
- Needs:
  - Constructor input: wearable with `FotaSlotInfoCapability`.
- Does:
  - Reads and groups reported MCUboot image slots by image index.
  - Shows active, confirmed, pending, permanent, bootable, version, and hash metadata for each slot.
  - Lets users confirm and erase eligible inactive secondary slots through `eraseFirmwareSlot`.
  - Keeps protected slots read-only and offers mcumgr web as a fallback recovery tool.
- Provides:
  - Firmware slot inspection and recovery controls for stuck FOTA states.

## `LoggerScreen` (`lib/widgets/fota/logger_screen/logger_screen.dart`)
- Needs:
  - Constructor input: `FirmwareUpdateLogger logger`.
- Does:
  - Reads device-side MCU logs and filters by severity.
  - Renders log list with color-coded levels.
- Provides:
  - Post-update diagnostic log visibility.
