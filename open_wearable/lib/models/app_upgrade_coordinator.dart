import 'package:open_wearable/models/app_upgrade_highlight.dart';
import 'package:open_wearable/models/app_upgrade_registry.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads the current app version for upgrade gating.
abstract class AppVersionProvider {
  /// Returns the current app version string.
  Future<String> getVersion();
}

/// Reads the current app version from platform package metadata.
class PackageInfoAppVersionProvider implements AppVersionProvider {
  /// Creates a package-info based version provider.
  const PackageInfoAppVersionProvider();

  @override
  Future<String> getVersion() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }
}

/// Decides whether a post-upgrade announcement should be shown.
///
/// Fresh installs show content only when the installed version exactly matches
/// a registered highlight. Existing installs only show content when the current
/// version has a registered highlight and differs from the last acknowledged
/// version.
class AppUpgradeCoordinator {
  /// Creates an upgrade coordinator.
  const AppUpgradeCoordinator({
    AppVersionProvider versionProvider = const PackageInfoAppVersionProvider(),
  }) : _versionProvider = versionProvider;

  static const String acknowledgedVersionKey =
      'app_upgrade_acknowledged_version';

  final AppVersionProvider _versionProvider;

  /// Returns the highlight that should be displayed on this launch, if any.
  Future<AppUpgradeHighlight?> loadPendingHighlight() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String currentVersion = await _versionProvider.getVersion();
    final AppUpgradeHighlight? currentHighlight = AppUpgradeRegistry.forVersion(
      currentVersion,
    );
    final String? acknowledgedVersion = prefs.getString(
      acknowledgedVersionKey,
    );

    if (acknowledgedVersion == null) {
      if (currentHighlight == null) {
        await prefs.setString(acknowledgedVersionKey, currentVersion);
        return null;
      }
      return currentHighlight;
    }

    if (acknowledgedVersion == currentVersion) {
      return null;
    }

    if (currentHighlight == null) {
      await prefs.setString(acknowledgedVersionKey, currentVersion);
      return null;
    }

    return currentHighlight;
  }

  /// Marks [version] as acknowledged so its upgrade page is not shown again.
  Future<void> acknowledgeVersion(String version) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(acknowledgedVersionKey, version);
  }
}
