import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/models/firmware_version_comparison.dart';

void main() {
  test('compares released firmware against the installed development build',
      () {
    expect(
        isNewerFirmwareVersion('2.2.9', '2.2.10-dev.60+ga99d057fa'), isFalse);
    expect(
        isNewerFirmwareVersion('2.2.10', '2.2.10-dev.60+ga99d057fa'), isTrue);
    expect(
        isNewerFirmwareVersion('2.2.11', '2.2.10-dev.60+ga99d057fa'), isTrue);
  });
  test('prerelease numbers are numeric and build metadata has no precedence',
      () {
    expect(isNewerFirmwareVersion('2.2.10-dev.10', '2.2.10-dev.9'), isTrue);
    expect(isNewerFirmwareVersion('2.2.10+z', '2.2.10+a'), isFalse);
    expect(isNewerFirmwareVersion(' v2.2.10\x00 ', '2.2.9'), isTrue);
    expect(isNewerFirmwareVersion('2.2.9', '2.2.9'), isFalse);
  });
  test('unrecognized labels fail explicitly instead of suggesting a downgrade',
      () {
    expect(() => isNewerFirmwareVersion('2.2.9', 'PR #123'),
        throwsFormatException);
  });
}
