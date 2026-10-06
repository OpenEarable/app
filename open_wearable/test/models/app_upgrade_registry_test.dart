import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/models/app_upgrade_registry.dart';

void main() {
  group('AppUpgradeRegistry', () {
    test('describes firmware 2.3.0 as beta before October 20 locally', () {
      final highlight = AppUpgradeRegistry.forVersion(
        '1.6.0',
        now: DateTime(2026, 10, 19, 23, 59, 59),
      )!;

      expect(
        highlight.heroDescription,
        contains(
          'OpenEarable firmware 2.3.0 is currently available as a beta.',
        ),
      );
    });

    test('omits the beta notice from October 20 locally', () {
      for (final date in [DateTime(2026, 10, 20), DateTime(2026, 10, 21)]) {
        final highlight = AppUpgradeRegistry.forVersion('1.6.0', now: date)!;

        expect(highlight.heroDescription, isNot(contains('beta')));
        expect(
          highlight.heroDescription,
          contains('OpenEarable firmware 2.3.0'),
        );
      }
    });

    test('keeps older highlights and lists version 1.6.0 first', () {
      final highlight = AppUpgradeRegistry.forVersion('1.5.0');

      expect(highlight, isNotNull);
      expect(highlight?.version, '1.5.0');
      expect(
        highlight?.title,
        'Labels and more control\nfor your OpenEarables',
      );
      expect(
        highlight?.features.map((feature) => feature.title),
        [
          'Recording labels',
          'Seal Check',
          'Microphone gain controls',
          'Smarter device selection',
        ],
      );
      expect(AppUpgradeRegistry.forVersion('1.6.0'), isNotNull);
      expect(AppUpgradeRegistry.latest?.version, '1.6.0');
      expect(AppUpgradeRegistry.all.first.version, '1.6.0');
    });
  });
}
