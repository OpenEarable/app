import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/models/app_upgrade_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppUpgradeCoordinator', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('shows registered content on a fresh install when version matches',
        () async {
      const AppUpgradeCoordinator coordinator = AppUpgradeCoordinator(
        versionProvider: _FakeAppVersionProvider('1.1.0'),
      );

      final result = await coordinator.loadPendingHighlight();

      expect(result, isNotNull);
      expect(result?.version, '1.1.0');
    });

    test('does not show upgrade content on a fresh install without match',
        () async {
      const AppUpgradeCoordinator coordinator = AppUpgradeCoordinator(
        versionProvider: _FakeAppVersionProvider('1.1.1'),
      );

      final result = await coordinator.loadPendingHighlight();
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      expect(result, isNull);
      expect(
        prefs.getString(AppUpgradeCoordinator.acknowledgedVersionKey),
        '1.1.1',
      );
    });

    test('returns registered content after upgrade from older version',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppUpgradeCoordinator.acknowledgedVersionKey: '1.0.13',
      });
      const AppUpgradeCoordinator coordinator = AppUpgradeCoordinator(
        versionProvider: _FakeAppVersionProvider('1.1.0'),
      );

      final result = await coordinator.loadPendingHighlight();

      expect(result, isNotNull);
      expect(result?.version, '1.1.0');
    });

    test('ignores upgrades without registered highlight content', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppUpgradeCoordinator.acknowledgedVersionKey: '1.1.0',
      });
      const AppUpgradeCoordinator coordinator = AppUpgradeCoordinator(
        versionProvider: _FakeAppVersionProvider('1.1.1'),
      );

      final result = await coordinator.loadPendingHighlight();
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      expect(result, isNull);
      expect(
        prefs.getString(AppUpgradeCoordinator.acknowledgedVersionKey),
        '1.1.1',
      );
    });

    test('acknowledgeVersion stores the accepted app version', () async {
      const AppUpgradeCoordinator coordinator = AppUpgradeCoordinator(
        versionProvider: _FakeAppVersionProvider('1.1.0'),
      );

      await coordinator.acknowledgeVersion('1.1.0');

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(AppUpgradeCoordinator.acknowledgedVersionKey),
        '1.1.0',
      );
    });
  });
}

class _FakeAppVersionProvider implements AppVersionProvider {
  const _FakeAppVersionProvider(this.version);

  final String version;

  @override
  Future<String> getVersion() async => version;
}
