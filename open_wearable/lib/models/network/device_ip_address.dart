import 'device_ip_address_stub.dart'
    if (dart.library.io) 'device_ip_address_io.dart';

/// Resolves the best client-reachable IPv4 address for the current device.
///
/// Native targets attempt to return the preferred LAN address. Targets without
/// `dart:io` support return `null`.
Future<String?> resolveCurrentDeviceIpAddress() =>
    resolveCurrentDeviceIpAddressImpl();
