import 'device_ip_address_stub.dart'
    if (dart.library.io) 'device_ip_address_io.dart';

Future<String?> resolveCurrentDeviceIpAddress() =>
    resolveCurrentDeviceIpAddressImpl();
