import 'package:flutter/material.dart';
import 'package:open_wearable/models/app_upgrade_highlight.dart';

/// Central registry for version-specific post-upgrade announcements.
///
/// Add one [AppUpgradeHighlight] per release that should present a custom
/// "What's new" experience after upgrade.
class AppUpgradeRegistry {
  AppUpgradeRegistry._();

  static const List<AppUpgradeHighlight> _highlights = <AppUpgradeHighlight>[
    AppUpgradeHighlight(
      version: '1.1.0',
      eyebrow: 'Welcome to our new look!',
      title: 'A cleaner,\nmore capable OpenWearables app',
      summary:
          'Refined navigation, stronger device flows, and sharper tooling.',
      heroDescription:
          'This release brings a more structured app experience across overview, devices, sensors, and settings, '
          'while making room for richer workflows in future updates.',
      accentColor: Color(0xFF8F6A67),
      useHeroGradient: false,
      features: <AppUpgradeFeatureHighlight>[
        AppUpgradeFeatureHighlight(
          icon: Icons.space_dashboard_rounded,
          title: 'Reworked app shell',
          description:
              'A clearer overview and section layout make core workflows easier to discover.',
        ),
        AppUpgradeFeatureHighlight(
          icon: Icons.earbuds_rounded,
          title: 'Stereo devices',
          description:
              'Device pairs like earables can now be displayed as a stereo pair, making it easier to '
              'manage and interact with them.',
        ),
        AppUpgradeFeatureHighlight(
          icon: Icons.devices_rounded,
          title: 'Better device journeys',
          description:
              'Connection, inspection, and update-related actions are easier to reach and expand over time.',
        ),
        AppUpgradeFeatureHighlight(
          icon: Icons.ssid_chart_rounded,
          title: 'Improved sensor workflows',
          description:
              'Configuration, live data, and recording fit into a more coherent structure.\n'
              'Save custom sensor profiles and apply them to your devices to quickly switch between '
              'different sensor configurations.',
        ),
        AppUpgradeFeatureHighlight(
          icon: Icons.settings_rounded,
          title: 'Customizable settings',
          description:
              'We introduce settings to customize your app experience to your workflows. '
              'Keep the app in the foreground, disable all sensors when closing the app, '
              'optimize performance and more.',
        ),
      ],
    ),
    AppUpgradeHighlight(
      version: '1.2.0',
      eyebrow: 'OpenWearables 1.2.0',
      title: 'Automate OpenWearables\nwith the new connector',
      summary:
          'Control the app over WebSocket and use your phone as a sensor source.',
      heroDescription:
          'OpenWearables now includes a connector that exposes app control through a WebSocket API. '
          'The Python API builds on that connection, making scripted workflows, external tools, '
          'and repeatable automation possible.',
      accentColor: Color(0xFF2F7D6D),
      useHeroGradient: false,
      features: <AppUpgradeFeatureHighlight>[
        AppUpgradeFeatureHighlight(
          icon: Icons.hub_rounded,
          title: 'Brand-new connector',
          description:
              'Control app behavior remotely through the WebSocket connector for automation and integration workflows.',
        ),
        AppUpgradeFeatureHighlight(
          icon: Icons.code_rounded,
          title: 'Python API support',
          description:
              'Use the Python API on top of the connector to script app interactions from external tools.',
        ),
        AppUpgradeFeatureHighlight(
          icon: Icons.wifi_tethering_rounded,
          title: 'Automation-ready access',
          description:
              'Build repeatable experiments, demos, and integrations without driving every action through the UI.',
        ),
        AppUpgradeFeatureHighlight(
          icon: Icons.phone_iphone_rounded,
          title: 'Phone as a sensor device',
          description:
              'Use the phone running the app as a local sensor source for supported motion data workflows.',
        ),
        AppUpgradeFeatureHighlight(
          icon: Icons.tune_rounded,
          title: 'Configurable local sensors',
          description:
              'Phone sensor streams support configurable sampling options and start with sampling disabled until selected.',
        ),
      ],
    ),
  ];

  /// Returns the configured highlight for [version], if any.
  static AppUpgradeHighlight? forVersion(String version) {
    for (final AppUpgradeHighlight highlight in _highlights) {
      if (highlight.version == version) {
        return highlight;
      }
    }
    return null;
  }

  /// Returns the latest configured highlight in the registry.
  static AppUpgradeHighlight? get latest {
    if (_highlights.isEmpty) {
      return null;
    }
    return _highlights.last;
  }

  /// Returns all registered highlights in newest-first order.
  static List<AppUpgradeHighlight> get all {
    return List<AppUpgradeHighlight>.unmodifiable(
      _highlights.reversed,
    );
  }
}
