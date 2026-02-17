import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/models/app_shutdown_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppShutdownSettings', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await AppShutdownSettings.initialize();
    });

    test('defaults to disabled sensor shutdown on app close', () {
      expect(AppShutdownSettings.shutOffAllSensorsOnAppClose, isFalse);
      expect(AppShutdownSettings.disableLiveDataGraphs, isFalse);
      expect(AppShutdownSettings.hideLiveDataGraphsWithoutData, isFalse);
    });

    test('persists and reloads the shutdown preference', () async {
      await AppShutdownSettings.saveShutOffAllSensorsOnAppClose(true);

      expect(AppShutdownSettings.shutOffAllSensorsOnAppClose, isTrue);

      final reloaded =
          await AppShutdownSettings.loadShutOffAllSensorsOnAppClose();
      expect(reloaded, isTrue);

      await AppShutdownSettings.saveShutOffAllSensorsOnAppClose(false);
      expect(AppShutdownSettings.shutOffAllSensorsOnAppClose, isFalse);
    });

    test('persists and reloads live data graph preference', () async {
      await AppShutdownSettings.saveDisableLiveDataGraphs(true);

      expect(AppShutdownSettings.disableLiveDataGraphs, isTrue);

      final reloaded = await AppShutdownSettings.loadDisableLiveDataGraphs();
      expect(reloaded, isTrue);

      await AppShutdownSettings.saveDisableLiveDataGraphs(false);
      expect(AppShutdownSettings.disableLiveDataGraphs, isFalse);
    });

    test('persists and reloads hide-no-data graph preference', () async {
      await AppShutdownSettings.saveHideLiveDataGraphsWithoutData(true);

      expect(AppShutdownSettings.hideLiveDataGraphsWithoutData, isTrue);

      final reloaded =
          await AppShutdownSettings.loadHideLiveDataGraphsWithoutData();
      expect(reloaded, isTrue);

      await AppShutdownSettings.saveHideLiveDataGraphsWithoutData(false);
      expect(AppShutdownSettings.hideLiveDataGraphsWithoutData, isFalse);
    });
  });
}
