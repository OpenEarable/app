import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/beta_firmware_title_resolver.dart';

void main() {
  group('BetaFirmwareTitleResolver', () {
    test('uses GitHub pull request title for beta firmware display name',
        () async {
      final resolver = BetaFirmwareTitleResolver(
        fetchTitles: (numbers) async {
          expect(numbers, {250});
          return {250: '2.2.7'};
        },
      );

      final entries = await resolver.resolve([
        _betaEntry(
          name: '2 2 7',
          version: 'PR #250',
          url:
              'https://github.com/OpenEarable/open-earable-2/releases/download/pr-builds/pr-250-2_2_7-openearable_v2_fota.zip',
        ),
      ]);

      expect(entries.single.firmware.name, '2.2.7');
      expect(entries.single.firmware.version, 'PR #250');
      expect(entries.single.firmware.url, contains('pr-250-2_2_7'));
      expect(entries.single.firmware.type, FirmwareType.multiImage);
      expect(entries.single.isBeta, isTrue);
    });

    test('preserves punctuation from pull request titles', () async {
      final resolver = BetaFirmwareTitleResolver(
        fetchTitles: (_) async => {228: 'Feature/audio response'},
      );

      final entries = await resolver.resolve([
        _betaEntry(
          name: 'Feature audio response',
          version: 'PR #228',
          url:
              'https://github.com/OpenEarable/open-earable-2/releases/download/pr-builds/pr-228-Feature_audio_response-openearable_v2_fota.zip',
        ),
      ]);

      expect(entries.single.firmware.name, 'Feature/audio response');
    });

    test('preserves brackets and dots from pull request titles', () async {
      final resolver = BetaFirmwareTitleResolver(
        fetchTitles: (_) async => {250: '[2.2.7] FOTA retry upload'},
      );

      final entries = await resolver.resolve([
        _betaEntry(
          name: '2 2 7 FOTA retry upload',
          version: 'PR #250',
          url:
              'https://github.com/OpenEarable/open-earable-2/releases/download/pr-builds/pr-250-2_2_7_FOTA_retry_upload-openearable_v2_fota.zip',
        ),
      ]);

      expect(entries.single.firmware.name, '[2.2.7] FOTA retry upload');
    });

    test('does not change stable firmware entries', () async {
      final resolver = BetaFirmwareTitleResolver(
        fetchTitles: (numbers) async {
          expect(numbers, isEmpty);
          return const {};
        },
      );
      final entry = FirmwareEntry(
        firmware: RemoteFirmware(
          name: 'OpenEarable 2.2.7',
          version: '2.2.7',
          url: 'https://example.com/openearable_v2_fota.zip',
          type: FirmwareType.multiImage,
        ),
        source: FirmwareSource.stable,
      );

      final entries = await resolver.resolve([entry]);

      expect(entries.single, same(entry));
    });

    test('keeps asset-derived title when pull request title is unavailable',
        () async {
      final resolver = BetaFirmwareTitleResolver(
        fetchTitles: (_) async => const {},
      );
      final entry = _betaEntry(
        name: '2 2 7',
        version: 'PR #250',
        url:
            'https://github.com/OpenEarable/open-earable-2/releases/download/pr-builds/pr-250-2_2_7-openearable_v2_fota.zip',
      );

      final entries = await resolver.resolve([entry]);

      expect(entries.single, same(entry));
    });
  });
}

FirmwareEntry _betaEntry({
  required String name,
  required String version,
  required String url,
}) {
  return FirmwareEntry(
    firmware: RemoteFirmware(
      name: name,
      version: version,
      url: url,
      type: FirmwareType.multiImage,
    ),
    source: FirmwareSource.beta,
  );
}
