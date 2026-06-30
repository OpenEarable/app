import 'package:flutter/foundation.dart';

import 'study_devices.dart';
import 'study_recording_status.dart';

/// Web stub: study recordings require local file storage and BLE devices that
/// are unavailable on web. The controller exists only so the UI compiles for
/// the web target; [start] always fails.
class StudyRecordingController extends ChangeNotifier {
  /// Duration of the guided baseline step.
  static const Duration baselineDuration = Duration(minutes: 5);

  /// Target microphone sample rate for OpenEarable SD-card recording.
  static const int microphoneFrequencyHz = 8000;

  /// Target IMU sample rate for OpenEarable SD-card recording.
  static const int imuFrequencyHz = 100;

  StudyRecordingStatus get status => StudyRecordingStatus.idle;
  String? get probandId => null;
  String? get sessionDirectory => null;
  String? get warning => null;
  bool get isRecording => false;
  Duration get remaining => baselineDuration;
  double get progress => 0;

  Future<void> start({
    required String probandId,
    required StudyDeviceSet deviceSet,
  }) async {
    throw UnsupportedError('Study recordings are not supported on web');
  }

  Future<void> stop() async {}
}
