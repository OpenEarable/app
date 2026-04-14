# Upgrade Highlights

This document explains how to customize the post-upgrade "What's new" page that is shown once after a qualifying app update or eligible first install.

## Files Involved

- `lib/models/app_upgrade_highlight.dart`
  - Data model for one upgrade page and its feature cards.
- `lib/models/app_upgrade_registry.dart`
  - Version-to-content mapping. This is the first place to edit for a new release.
- `lib/models/app_upgrade_coordinator.dart`
  - Launch gating logic. Decides whether the page should be shown.
- `lib/widgets/updates/app_upgrade_page.dart`
  - Shared page layout, hero section, card styling, and actions.
- `lib/main.dart`
  - Startup integration that presents the page after app launch.
- `lib/router.dart`
  - Manual preview route at `/whats-new`.

## How The Flow Works

1. On launch, `AppUpgradeCoordinator` reads the installed app version via `package_info_plus`.
2. It compares that version with the last acknowledged version stored in `SharedPreferences`.
3. If the current version exactly matches an entry in `AppUpgradeRegistry`, the page is eligible to be shown.
4. On first install, the page is shown only when the installed version exactly matches a registered highlight.
5. On upgrade, the page is shown only when the new version exactly matches a registered highlight and differs from the acknowledged version.
6. When the user continues, that version is marked as acknowledged and is not shown again.

## Update Content For The Current Version

If you want to change the content for the current release, edit the matching `AppUpgradeHighlight` entry in `lib/models/app_upgrade_registry.dart`.

The most important fields are:

- `eyebrow`
  - Small label above the hero title.
- `title`
  - Main release headline.
- `summary`
  - Short supporting sentence near the hero title.
- `heroDescription`
  - Longer body text introducing the release.
- `accentColor`
  - Optional color used to tint the page.
- `features`
  - List of cards shown below or beside the hero section.

Each feature card is an `AppUpgradeFeatureHighlight` with:

- `icon`
- `title`
- `description`

Example structure:

```dart
AppUpgradeHighlight(
  version: '1.0.14',
  eyebrow: 'Welcome to the new release',
  title: 'A cleaner, more capable OpenWearables app',
  summary: 'Refined navigation, stronger device flows, and sharper tooling.',
  heroDescription: 'Describe the release in one longer paragraph.',
  accentColor: Color(0xFF8F6A67),
  features: <AppUpgradeFeatureHighlight>[
    AppUpgradeFeatureHighlight(
      icon: Icons.space_dashboard_rounded,
      title: 'Reworked app shell',
      description: 'Explain the user-facing change.',
    ),
  ],
)
```

## Add A New Custom Page For The Next Release

When a future version should have its own page:

1. Bump the app version in `pubspec.yaml`.
2. Add a new `AppUpgradeHighlight` entry in `lib/models/app_upgrade_registry.dart`.
3. Set its `version` to the same app version string.
4. Update the hero copy and feature cards for that release.
5. Keep the newest release as the last entry in the registry.

The registry is intentionally simple: one entry per release. The coordinator looks up by exact version.

## Change The Visual Design

If the release needs a different layout or richer presentation, edit `lib/widgets/updates/app_upgrade_page.dart`.

Recommended boundaries:

- Change copy, icons, and accent colors in the registry first.
- Change reusable visual structure in `AppUpgradePage`.
- Keep version-specific content out of the widget tree unless the change is truly unique to one release.

This keeps the architecture clean:

- Registry:
  - release-specific content.
- Page widget:
  - shared presentation framework.
- Coordinator:
  - display rules.

## Preview The Page Without Reinstalling

Use the manual route:

- `/whats-new`
  - Opens the release history page.
- `/whats-new?version=1.1.0`
  - Opens the page for a specific registered version.

There is also a Settings entry called `Release history` that opens the history page.

## Recommended Editing Checklist

- Verify the `version` in the registry exactly matches `pubspec.yaml`.
- Prefer 3 to 5 feature cards with concise descriptions.
- Use icons that already fit the rest of the app's Material style.
- Keep `heroDescription` focused on user-facing changes, not internal refactors.
- Re-run `flutter analyze`.
- Re-run the relevant tests, especially `test/models/app_upgrade_coordinator_test.dart`.

## When To Change The Coordinator

You usually do not need to touch `AppUpgradeCoordinator`.

Only modify it if the product requirement changes, for example:

- show the page on fresh install,
- support multiple pages in sequence,
- support semantic version ranges instead of exact matches,
- or allow re-showing older releases manually from persistence.
