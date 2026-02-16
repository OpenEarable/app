import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/models/auto_connect_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutoConnectPreferences', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('rememberDeviceName stores normalized unique names', () async {
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
        <String>['OpenEarable 2'],
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
        <String>['OpenEarable 2', 'OpenEarable 3'],
      );
    });

    test('forgetDeviceName removes matching remembered names', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AutoConnectPreferences.connectedDeviceNamesKey: <String>[
          'OpenEarable 2',
          'OpenEarable 3',
        ],
      });

      final prefs = await SharedPreferences.getInstance();

      await AutoConnectPreferences.forgetDeviceName(prefs, ' OpenEarable 3 ');
      await AutoConnectPreferences.forgetDeviceName(prefs, 'Unknown');

      expect(
        prefs.getStringList(AutoConnectPreferences.connectedDeviceNamesKey),
        <String>['OpenEarable 2'],
      );
    });
  });
}
