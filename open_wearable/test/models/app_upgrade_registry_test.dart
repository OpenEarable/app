import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/models/app_upgrade_registry.dart';

void main() {
  group('AppUpgradeRegistry', () {
    test('registers version 1.2.0 as the latest upgrade highlight', () {
      final highlight = AppUpgradeRegistry.forVersion('1.2.0');

      expect(highlight, isNotNull);
      expect(highlight?.version, '1.2.0');
      expect(AppUpgradeRegistry.latest?.version, '1.2.0');
      expect(AppUpgradeRegistry.all.first.version, '1.2.0');
    });
  });
}
