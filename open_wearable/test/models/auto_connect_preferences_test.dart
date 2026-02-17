import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/models/auto_connect_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutoConnectPreferences', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await AutoConnectPreferences.loadAutoConnectEnabled();
    });

    test('rememberDeviceName stores normalized names and keeps duplicates',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AutoConnectPreferences.connectedDeviceNamesKey: <String>[
          'OpenEarable 2',
          '   ',
          'OpenEarable 2',
        ],
      });

      final prefs = await SharedPreferences.getInstance();

      expect(
        AutoConnectPreferences.readRememberedDeviceNames(prefs),
        <String>['OpenEarable 2', 'OpenEarable 2'],
      );

      await AutoConnectPreferences.rememberDeviceName(
        prefs,
        ' OpenEarable 3 ',
      );
      await AutoConnectPreferences.rememberDeviceName(
        prefs,
        'OpenEarable 2',
      );

      expect(
        prefs.getStringList(AutoConnectPreferences.connectedDeviceNamesKey),
        <String>[
          'OpenEarable 2',
          'OpenEarable 2',
          'OpenEarable 3',
          'OpenEarable 2',
        ],
      );
    });

    test('forgetDeviceName removes one matching remembered name per call',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AutoConnectPreferences.connectedDeviceNamesKey: <String>[
          'OpenEarable 2',
          'OpenEarable 3',
          'OpenEarable 3',
        ],
      });

      final prefs = await SharedPreferences.getInstance();

      await AutoConnectPreferences.forgetDeviceName(prefs, ' OpenEarable 3 ');
      await AutoConnectPreferences.forgetDeviceName(prefs, 'Unknown');

      expect(
        prefs.getStringList(AutoConnectPreferences.connectedDeviceNamesKey),
        <String>['OpenEarable 2', 'OpenEarable 3'],
      );
    });

    test('countRememberedDeviceName returns normalized occurrence counts',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AutoConnectPreferences.connectedDeviceNamesKey: <String>[
          'OpenEarable 2',
          ' OpenEarable 2 ',
          'OpenEarable 3',
        ],
      });

      final prefs = await SharedPreferences.getInstance();

      expect(
        AutoConnectPreferences.countRememberedDeviceName(
          prefs,
          'OpenEarable 2',
        ),
        2,
      );
      expect(
        AutoConnectPreferences.countRememberedDeviceName(
          prefs,
          ' OpenEarable 3 ',
        ),
        1,
      );
      expect(
        AutoConnectPreferences.countRememberedDeviceName(prefs, 'Unknown'),
        0,
      );
    });

    test('changes stream emits for remember and forget updates', () async {
      final prefs = await SharedPreferences.getInstance();

      final rememberChange = AutoConnectPreferences.changes.first;
      await AutoConnectPreferences.rememberDeviceName(prefs, 'OpenEarable 9');
      await expectLater(rememberChange, completes);

      final forgetChange = AutoConnectPreferences.changes.first;
      await AutoConnectPreferences.forgetDeviceName(prefs, 'OpenEarable 9');
      await expectLater(forgetChange, completes);
    });

    test('auto-connect enabled defaults to true when no value is stored',
        () async {
      final loaded = await AutoConnectPreferences.loadAutoConnectEnabled();

      expect(loaded, isTrue);
      expect(AutoConnectPreferences.autoConnectEnabled, isTrue);
    });

    test('saveAutoConnectEnabled persists value and emits changes', () async {
      final changed = AutoConnectPreferences.changes.first;
      final saved = await AutoConnectPreferences.saveAutoConnectEnabled(false);
      final prefs = await SharedPreferences.getInstance();

      expect(saved, isFalse);
      expect(
        prefs.getBool(AutoConnectPreferences.autoConnectEnabledKey),
        false,
      );
      expect(AutoConnectPreferences.autoConnectEnabled, isFalse);
      await expectLater(changed, completes);
    });
  });
}
