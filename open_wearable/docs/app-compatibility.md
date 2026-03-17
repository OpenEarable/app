# App Compatibility Framework

This document describes how mini-apps declare which wearables they support.

## Overview

App compatibility is defined in `lib/apps/widgets/app_compatibility.dart`.

The framework is built around two concepts:

- `AppSupportOption`: one user-visible supported-device entry shown in the app UI.
- `AppRequirement`: the matcher behind that entry.

An app declares a list of `AppSupportOption`s. A wearable is compatible when it
matches at least one option.

## Core Types

### `AppSupportOption`

`AppSupportOption` contains:

- `label`: text shown in the supported-devices chips.
- `requirement`: the rule that determines whether a `Wearable` matches.

Example:

```dart
const AppSupportOption(
  label: 'OpenRing',
  requirement: AppRequirement.nameStartsWith('OpenRing'),
)
```

### `AppRequirement`

`AppRequirement` is a composable predicate over a `Wearable`.

Available builders:

- `AppRequirement.always()`
  - Matches every wearable.
- `AppRequirement.nameStartsWith(prefix)`
  - Matches by raw or formatted wearable name prefix.
- `AppRequirement.hasCapability<T>()`
  - Matches if the wearable exposes capability `T`.
- `AppRequirement.capability<T>((capability, wearable) => ...)`
  - Matches if the wearable has capability `T` and the predicate returns `true`.
- `AppRequirement.custom((wearable) => ...)`
  - Escape hatch for any custom wearable-level predicate.
- `AppRequirement.allOf([...])`
  - Logical `AND`.
- `AppRequirement.anyOf([...])`
  - Logical `OR`.

## Matching Semantics

- An app with no `supportedDevices` is treated as compatible with every wearable.
- A wearable matches an app when it satisfies any `AppSupportOption`.
- `nameStartsWith` uses both the raw wearable name and the formatted display
  name, so aliases such as OpenRing `bcl-*` names continue to work.

## Defining App Support

Apps define support in `lib/apps/widgets/apps_page.dart` inside the app catalog.

Simple example:

```dart
final List<AppSupportOption> supportedDevices = [
  const AppSupportOption(
    label: 'OpenEarable',
    requirement: AppRequirement.nameStartsWith('OpenEarable'),
  ),
  const AppSupportOption(
    label: 'OpenRing',
    requirement: AppRequirement.nameStartsWith('OpenRing'),
  ),
];
```

Capability-based example:

```dart
final List<AppSupportOption> supportedDevices = [
  AppSupportOption(
    label: 'Configurable OpenEarable',
    requirement: AppRequirement.allOf([
      AppRequirement.nameStartsWith('OpenEarable'),
      AppRequirement.hasCapability<SensorConfigurationManager>(),
    ]),
  ),
];
```

Capability-property example:

```dart
final List<AppSupportOption> supportedDevices = [
  AppSupportOption(
    label: 'Left OpenEarable',
    requirement: AppRequirement.allOf([
      AppRequirement.nameStartsWith('OpenEarable'),
      AppRequirement.capability<StereoDevice>(
        (stereo, _) => stereo.position == DevicePosition.left,
      ),
    ]),
  ),
];
```

## Where It Is Used

The same compatibility model is used in both places:

- `AppsPage`: enables or disables app tiles depending on connected wearables.
- `SelectEarableView`: filters the list of selectable wearables before app launch.

This keeps the tile state and the picker behavior aligned.

## Guidance

- Prefer capability-based requirements when the app depends on runtime device
  features.
- Use name-based requirements only when device family is the real constraint.
- Keep `label` concise and user-facing.
- If one app supports multiple device configurations, model them as multiple
  `AppSupportOption`s instead of a single opaque predicate.

## Tests

Compatibility behavior is covered in `test/apps/widgets/app_compatibility_test.dart`.

Current tests cover:

- OpenRing alias name matching
- composite requirements
- capability presence
- capability property checks
