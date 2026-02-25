import 'package:open_earable_flutter/open_earable_flutter.dart';

abstract class CommandRuntime {
  List<String> get methods;

  Future<bool> hasPermissions();

  Future<bool> checkAndRequestPermissions();

  Future<Map<String, dynamic>> startScan({
    bool checkAndRequestPermissions = true,
  });

  Future<List<Map<String, dynamic>>> getDiscoveredDevices();

  Future<Map<String, dynamic>> connect({
    required String deviceId,
    bool connectedViaSystem = false,
  });

  Future<List<Map<String, dynamic>>> connectSystemDevices({
    List<String> ignoredDeviceIds = const <String>[],
  });

  Future<List<Map<String, dynamic>>> listConnected();

  Future<Map<String, dynamic>> disconnect({
    required String deviceId,
  });

  Future<int> createSubscriptionId();

  Future<void> attachStreamSubscription({
    required dynamic session,
    required int subscriptionId,
    required String streamName,
    required String deviceId,
    required Stream<dynamic> stream,
  });

  Future<Map<String, dynamic>> unsubscribe({
    required dynamic session,
    required int subscriptionId,
  });

  Future<Object?> invokeAction({
    required String deviceId,
    required String action,
    Map<String, dynamic> args = const <String, dynamic>{},
  });

  Future<Wearable> getWearable({required String deviceId});
}
