import 'package:pub_semver/pub_semver.dart';

/// Compare firmware precedence, ignoring transport padding and build metadata.
bool isNewerFirmwareVersion(String latest, String current) {
  Version parse(String value) {
    final normalized = value
        .replaceAll('\x00', '')
        .trim()
        .replaceFirst(RegExp(r'^v(?=\d)'), '');
    final version = Version.parse(normalized);
    return Version(version.major, version.minor, version.patch,
        pre: version.preRelease.join('.'));
  }

  return parse(latest) > parse(current);
}
