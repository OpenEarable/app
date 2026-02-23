# Settings and Logging Pages

## `SettingsPage` (`lib/widgets/settings/settings_page.dart`)
- Needs:
  - Callbacks from shell:
    - `onLogsRequested`
    - `onConnectRequested`
    - `onGeneralSettingsRequested`
- Does:
  - Shows top-level app settings entry points.
  - Routes to general settings, logs, and about flow.
- Provides:
  - Central settings navigation hub.

## `GeneralSettingsPage` (`lib/widgets/settings/general_settings_page.dart`)
- Needs:
  - Static settings backends initialized at app startup:
    - `AutoConnectPreferences`
    - `AppShutdownSettings`
- Does:
  - Binds switch controls to persisted app settings.
  - Serializes save operations via `_isSaving` guard.
- Provides:
  - Runtime policy controls (auto-connect, shutdown behavior, live graph behavior).

## `_AboutPage` (`lib/widgets/settings/settings_page.dart`)
- Needs:
  - Internet/external app availability for URL launches (`url_launcher`).
- Does:
  - Shows app/about/legal context and external links.
  - Exposes entry into open-source license listing page.
- Provides:
  - Product attribution and legal discoverability.

## `_OpenSourceLicensesPage` (`lib/widgets/settings/settings_page.dart`)
- Needs:
  - Flutter `LicenseRegistry` data.
- Does:
  - Loads and groups licenses by package.
  - Displays per-package license details.
- Provides:
  - In-app third-party license compliance view.

## `LogFilesScreen` (`lib/widgets/logging/log_files_screen.dart`)
- Needs:
  - `LogFileManager` provider.
  - File share plugin support (`share_plus`).
- Does:
  - Lists collected log files and metadata.
  - Supports share/delete per file and clear-all with confirmation.
  - Navigates to log file detail viewer.
- Provides:
  - Diagnostic log management for users/developers.

## `LogFileDetailScreen` (`lib/widgets/logging/log_file_detail_screen.dart`)
- Needs:
  - Constructor input: `File file`.
- Does:
  - Loads file contents once and renders scrollable/selectable text.
  - Handles empty/error states for file reading.
- Provides:
  - Raw log content inspection view.
