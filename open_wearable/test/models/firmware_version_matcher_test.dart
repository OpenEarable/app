import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/models/firmware_version_matcher.dart';

void main() {
  group('normalizeFirmwareVersion', () {
    test('removes transport nulls and surrounding whitespace', () {
      expect(normalizeFirmwareVersion(' \x002.2.7\x00 '), '2.2.7');
    });

    test('returns null for missing firmware versions', () {
      expect(normalizeFirmwareVersion(null), isNull);
      expect(normalizeFirmwareVersion('   '), isNull);
    });
  });

  group('firmwareVersionsMatch', () {
    test('matches beta PR labels against device firmware ids', () {
      expect(firmwareVersionsMatch('PR #123', '2.2.7-pr123'), isTrue);
      expect(firmwareVersionsMatch('2.2.7-pr123', 'PR #123'), isTrue);
    });

    test('matches alternate beta PR spellings', () {
      expect(firmwareVersionsMatch('PR #123', '2.2.7-PR-123+1'), isTrue);
      expect(
        firmwareVersionsMatch('pull request #123', '2.2.7-pr123'),
        isTrue,
      );
    });

    test('rejects different beta PR numbers', () {
      expect(firmwareVersionsMatch('PR #123', '2.2.7-pr124'), isFalse);
      expect(firmwareVersionsMatch('PR #123', '2.2.7'), isFalse);
    });

    test('keeps existing stable version containment behavior', () {
      expect(firmwareVersionsMatch('2.2.7', '2.2.7+1'), isTrue);
      expect(firmwareVersionsMatch('2.2.7+1', '2.2.7'), isTrue);
      expect(firmwareVersionsMatch('2.2.7', '2.2.8'), isFalse);
    });
  });
}
