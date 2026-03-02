import 'dart:io';

Future<String?> resolveCurrentDeviceIpAddressImpl() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );

  String? fallback;
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      final host = address.address.trim();
      if (host.isEmpty || host.startsWith('169.254.')) {
        continue;
      }
      if (_isPrivateIpv4(host)) {
        return host;
      }
      fallback ??= host;
    }
  }

  return fallback;
}

bool _isPrivateIpv4(String host) {
  return host.startsWith('10.') ||
      host.startsWith('192.168.') ||
      RegExp(r'^172\.(1[6-9]|2\d|3[0-1])\.').hasMatch(host);
}
