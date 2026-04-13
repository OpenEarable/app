import 'package:open_wearable/models/app_upgrade_highlight.dart';

/// Central registry for version-specific post-upgrade announcements.
///
/// Add one [AppUpgradeHighlight] per release that should present a custom
/// "What's new" experience after upgrade.
class AppUpgradeRegistry {
  AppUpgradeRegistry._();

  static const List<AppUpgradeHighlight> _highlights = <AppUpgradeHighlight>[];

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
