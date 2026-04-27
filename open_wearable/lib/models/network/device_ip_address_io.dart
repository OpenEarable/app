import 'dart:io';

/// Resolves the best client-reachable IPv4 address for the current device.
///
/// The resolver returns private LAN addresses on likely Wi-Fi or Ethernet
/// interfaces and rejects cellular, VPN, hotspot, or peer-to-peer interfaces.
Future<String?> resolveCurrentDeviceIpAddressImpl() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );

  _ResolvedAddress? bestMatch;
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      final host = address.address.trim();
      if (host.isEmpty || host.startsWith('169.254.')) {
        continue;
      }
      final resolved = _ResolvedAddress(
        host: host,
        score: _scoreInterfaceAddress(interface.name, host),
      );
      if (_isPrivateIpv4(host) &&
          resolved.isLikelyLanAddress &&
          (bestMatch == null || resolved.score > bestMatch.score)) {
        bestMatch = resolved;
      }
    }
  }

  return bestMatch?.host;
}

/// Returns whether [host] is within one of the standard private IPv4 ranges.
bool _isPrivateIpv4(String host) {
  return host.startsWith('10.') ||
      host.startsWith('192.168.') ||
      RegExp(r'^172\.(1[6-9]|2\d|3[0-1])\.').hasMatch(host);
}

/// Scores an interface/address pair for LAN reachability preference.
int _scoreInterfaceAddress(String interfaceName, String host) {
  final name = interfaceName.toLowerCase();
  var score = 0;

  if (_isPrivateIpv4(host)) {
    score += 100;
  }

  if (name == 'en0') {
    score += 80;
  }
  if (name.startsWith('wlan') || name.startsWith('wifi')) {
    score += 80;
  }
  if (name.startsWith('eth') || name.startsWith('en')) {
    score += 50;
  }
  if (name.startsWith('rmnet') ||
      name.startsWith('pdp_ip') ||
      name.startsWith('ccmni')) {
    score -= 40;
  }
  if (name.startsWith('utun') ||
      name.startsWith('tun') ||
      name.startsWith('tap') ||
      name.startsWith('bridge') ||
      name.startsWith('awdl') ||
      name.startsWith('llw') ||
      name.startsWith('p2p') ||
      name.startsWith('ap')) {
    score -= 100;
  }

  return score;
}

/// Holds a candidate advertised host with its selection score.
class _ResolvedAddress {
  final String host;
  final int score;

  const _ResolvedAddress({
    required this.host,
    required this.score,
  });

  bool get isLikelyLanAddress => score >= 100;
}
