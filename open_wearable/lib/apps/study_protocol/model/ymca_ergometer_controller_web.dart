import 'package:flutter/foundation.dart';

import 'study_devices.dart';
import 'study_session.dart';
import 'ymca_models.dart';

/// Web stub: the ergometer test needs local file storage and BLE devices that
/// are unavailable on web. Exists only so the UI compiles for the web target.
class YmcaErgometerController extends ChangeNotifier {
  static const Duration measurementInterval = Duration(minutes: 1);
  static const Duration recoveryDuration = ymcaRecoveryDuration;

  final StudySession session;
  final StudyDeviceSet deviceSet;
  final String directory;

  YmcaErgometerController({
    required this.session,
    required this.deviceSet,
    required this.directory,
  });

  ErgoStatus get status => ErgoStatus.idle;
  int get submaxHeartRate => session.submaxHeartRate;
  int get maxHeartRate => session.maxHeartRate;
  int get currentStage => 0;
  int? get currentTargetWatt => null;
  List<ErgoMeasurement> get measurements => const <ErgoMeasurement>[];
  bool get isMeasurementDue => false;
  bool get canUndo => false;
  int? get dueMeasurementMinute => null;
  Duration get elapsed => Duration.zero;
  Duration get timeToNextMeasurement => measurementInterval;
  String? get pendingStageMessage => null;
  bool get endSuggested => false;
  Duration get recoveryRemaining => recoveryDuration;
  double get recoveryProgress => 0;
  bool get isRecoveryFinished => false;
  String? get warning => null;
  int? get respibanFileSizeBytes => null;
  int? get respibanFileSizeDeltaBytes => null;

  Future<void> start() async {
    throw UnsupportedError('The ergometer test is not supported on web');
  }

  Future<void> submitMeasurement({
    required int heartRate,
    required int actualWatt,
  }) async {}

  void manualNextStage() {}

  void undoLastMeasurement() {}

  void acknowledgeStageMessage() {}

  void dismissEndSuggestion() {}

  Future<void> end({required int endHeartRate}) async {}

  Future<void> finishRecovery() async {}

  Future<void> skip() async {}
}
