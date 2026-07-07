import 'package:flutter/foundation.dart';

import 'study_devices.dart';
import 'study_recording_status.dart';

/// Web stub: recording needs local file storage and BLE devices unavailable on
/// web. Exists only so the phase UI compiles for the web target.
class TimedRecordingController extends ChangeNotifier {
  final Duration duration;
  final String respibanFileLabel;
  final String earablePrefixSuffix;

  TimedRecordingController({
    required this.duration,
    this.respibanFileLabel = '',
    this.earablePrefixSuffix = '',
  });

  StudyRecordingStatus get status => StudyRecordingStatus.idle;
  String? get warning => null;
  int? get respibanFileSizeBytes => null;
  int? get respibanFileSizeDeltaBytes => null;
  bool get isRecording => false;
  Duration get remaining => duration;
  double get progress => 0;

  Future<void> start({
    required String probandId,
    required StudyDeviceSet deviceSet,
    required String directory,
  }) async {
    throw UnsupportedError('Study recordings are not supported on web');
  }

  Future<void> stop() async {}
}
