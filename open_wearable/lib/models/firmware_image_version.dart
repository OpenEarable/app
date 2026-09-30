import 'dart:typed_data';

import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'firmware_version_matcher.dart';

/// Read local image metadata after unpacking; filenames are arbitrary labels.
String? expectedFirmwareVersionForRequest(FirmwareUpdateRequest request) {
  final firmware = request.firmware;
  if (firmware is RemoteFirmware) {
    return normalizeFirmwareVersion(firmware.version);
  }
  if (firmware is! LocalFirmware) return null;

  if (request is MultiImageFirmwareUpdateRequest) {
    final applicationImages =
        request.firmwareImages?.where((image) => image.image == 0).toList();
    if (applicationImages == null || applicationImages.length != 1) return null;
    return _mcubootVersion(applicationImages.single.data);
  }
  if (request is SingleImageFirmwareUpdateRequest) {
    return _mcubootVersion(firmware.data);
  }
  return null;
}

String? _mcubootVersion(Uint8List bytes) {
  // MCUboot image_header: little-endian magic, sizes, then image_version at 20.
  if (bytes.length < 32) return null;
  final header = ByteData.sublistView(bytes);
  if (header.getUint32(0, Endian.little) != 0x96f3b83d) return null;
  final headerSize = header.getUint16(8, Endian.little);
  final imageSize = header.getUint32(12, Endian.little);
  if (headerSize < 32 ||
      imageSize == 0 ||
      headerSize + imageSize > bytes.length) {
    return null;
  }
  final base = '${header.getUint8(20)}.${header.getUint8(21)}.'
      '${header.getUint16(22, Endian.little)}';
  final tweak = header.getUint32(24, Endian.little);
  return tweak == 0 ? base : '$base.$tweak';
}
