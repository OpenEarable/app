import 'study_devices.dart';

/// Web stub: physiological recording needs local file storage and BLE devices
/// that are unavailable on web. The recorder is a no-op so the shared study
/// controllers still compile for the web target.
class StudyDeviceRecorder {
  static const int microphoneFrequencyHz = 8000;
  static const int imuFrequencyHz = 100;

  String? get warning => null;

  Future<int?> respibanFileSizeBytes() async => null;

  Future<DateTime> start({
    required StudyDeviceSet deviceSet,
    required String directory,
    required String probandId,
    String respibanFileLabel = '',
    String earablePrefixSuffix = '',
  }) async => DateTime.now();

  Future<void> stop() async {}
}
