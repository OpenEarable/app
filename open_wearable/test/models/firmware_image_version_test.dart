import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart' as mcumgr;
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/firmware_image_version.dart';
import 'package:open_wearable/models/firmware_version_matcher.dart';

Uint8List image(int major, int minor, int patch, {int tweak = 0}) {
  final bytes = Uint8List(64);
  final data = ByteData.sublistView(bytes);
  data.setUint32(0, 0x96f3b83d, Endian.little);
  data.setUint16(8, 32, Endian.little);
  data.setUint32(12, 32, Endian.little);
  data.setUint8(20, major);
  data.setUint8(21, minor);
  data.setUint16(22, patch, Endian.little);
  data.setUint32(24, tweak, Endian.little);
  return bytes;
}

void main() {
  test('local ZIP uses application header, not filename or network version',
      () {
    final request = MultiImageFirmwareUpdateRequest(
      firmware: LocalFirmware(
          name: 'OpenEarable-2.2.9-validation-e22638ad.zip',
          data: Uint8List(0),
          type: FirmwareType.multiImage,),
      firmwareImages: [
        mcumgr.Image(image: 1, data: image(1, 0, 0)),
        mcumgr.Image(image: 0, data: image(2, 2, 9)),
      ],
    );
    final expected = expectedFirmwareVersionForRequest(request);
    expect(expected, '2.2.9');
    expect(firmwareVersionsMatch(expected, '2.2.9-dev.104+ge22638ad'), isTrue);
    expect(firmwareVersionsMatch(expected, '2.2.8'), isFalse);
    expect(firmwareVersionsMatch(expected, '2.2.90'), isFalse);
    expect(firmwareVersionsMatch(expected, '12.2.9'), isFalse);
  });
  test('local signed binary reads little-endian revision and tweak', () {
    final request = SingleImageFirmwareUpdateRequest(
        firmware: LocalFirmware(
            name: 'arbitrary.bin',
            data: image(2, 3, 260, tweak: 7),
            type: FirmwareType.singleImage,),);
    expect(expectedFirmwareVersionForRequest(request), '2.3.260.7');
  });
  test('malformed images do not fall back to a version-looking filename', () {
    final invalid = [
      Uint8List(0),
      Uint8List(32),
      image(2, 2, 9).sublist(0, 40),
    ];
    for (final data in invalid) {
      final request = SingleImageFirmwareUpdateRequest(
          firmware: LocalFirmware(
              name: '2.2.9.bin', data: data, type: FirmwareType.singleImage,),);
      expect(expectedFirmwareVersionForRequest(request), isNull);
    }
  });
  test('missing or duplicate application images remain unverified', () {
    final request = MultiImageFirmwareUpdateRequest(
        firmware: LocalFirmware(
            name: '2.2.9.zip',
            data: Uint8List(0),
            type: FirmwareType.multiImage,),);
    expect(expectedFirmwareVersionForRequest(request), isNull);
    request.firmwareImages = [mcumgr.Image(image: 1, data: image(1, 0, 0))];
    expect(expectedFirmwareVersionForRequest(request), isNull);
    request.firmwareImages = [
      mcumgr.Image(image: 0, data: image(2, 2, 9)),
      mcumgr.Image(image: 0, data: image(2, 2, 8)),
    ];
    expect(expectedFirmwareVersionForRequest(request), isNull);
  });
  test('remote release labels keep their existing verification behavior', () {
    final request = FirmwareUpdateRequest(
        firmware: RemoteFirmware(
            name: 'release',
            version: '2.2.9',
            url: 'https://example.test/fw.zip',
            type: FirmwareType.multiImage,),);
    expect(expectedFirmwareVersionForRequest(request), '2.2.9');
  });
}
