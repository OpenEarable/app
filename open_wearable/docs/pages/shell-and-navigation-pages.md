# Shell and Navigation Pages

## `HomePage` (`lib/widgets/home_page.dart`)
- Needs:
  - Optional `initialSectionIndex` input (from router query `tab`).
  - Child section pages to be available: Overview, Devices, Sensors, Apps, Settings.
  - `SensorPageController` wiring for cross-section tab deep-linking.
- Does:
  - Hosts the main app shell and top-level section navigation.
  - Switches between compact bottom-tab layout and large-screen navigation rail layout.
  - Keeps section state using `PlatformTabController` and `IndexedStack`.
- Provides:
  - Stable root navigation context for all section pages.
  - Public section-level navigation entry points used by Overview and Settings actions.

## `OverviewPage` (`lib/widgets/home_page_overview.dart`)
- Needs:
  - `WearablesProvider` and `SensorRecorderProvider` in widget tree.
  - Three callbacks from `HomePage`:
    - `onDeviceSectionRequested`
    - `onConnectRequested`
    - `onSensorTabRequested(tabIndex)`
- Does:
  - Shows high-level session status (connected wearables and recording status).
  - Shows guided workflow steps: connect, configure, validate live data, record.
  - Opens device detail from overview cards.
- Provides:
  - Quick navigation hub to device connect flow and sensor tabs.
  - At-a-glance health/status for the current setup session.
