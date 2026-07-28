import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:open_wearable/models/audio_input_source.dart';
import 'package:open_wearable/models/logger.dart';
import 'package:open_wearable/view_models/audio_input_controller.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_models.dart';

void main() {
  setUpAll(() {
    initLogger(Logger());
  });

  group('AudioInputController', () {
    test('clears applied source when turning off after stop failure', () async {
      final platform = _FakeAudioInputPlatform(
        throwWhenStoppingMonitoring: true,
      );
      final controller = AudioInputController(platform: platform);

      await controller.selectSource(AudioInputSource.systemDefault);
      expect(await controller.applySelectedSource(), isTrue);

      platform.emitLevel(0.8);
      expect(controller.appliedSource, AudioInputSource.systemDefault);
      expect(controller.isMonitoringActive, isTrue);
      expect(controller.waveformData, isNotEmpty);

      await controller.selectSource(null);
      expect(controller.hasPendingSelection, isTrue);

      expect(await controller.applySelectedSource(), isTrue);

      expect(controller.selectedSource, isNull);
      expect(controller.appliedSource, isNull);
      expect(controller.hasPendingSelection, isFalse);
      expect(controller.isMonitoringActive, isFalse);
      expect(controller.waveformData, isEmpty);
    });

    test('moves monitoring into recording without stopping recording', () async {
      final platform = _FakeAudioInputPlatform();
      final controller = AudioInputController(platform: platform);

      await controller.selectSource(AudioInputSource.systemDefault);
      expect(await controller.applySelectedSource(), isTrue);
      await controller.startRecording('/tmp/recording');

      expect(platform.monitoringStarts, 1);
      expect(platform.monitoringStops, 1);
      expect(platform.recordingStarts, 1);
      expect(platform.recordingStops, 0);
      expect(controller.isRecordingActive, isTrue);
    });
  });
}

class _FakeAudioInputPlatform implements AudioInputPlatform {
  _FakeAudioInputPlatform({this.throwWhenStoppingMonitoring = false});

  final bool throwWhenStoppingMonitoring;
  ValueChanged<double>? _onLevel;
  int monitoringStarts = 0;
  int monitoringStops = 0;
  int recordingStarts = 0;
  int recordingStops = 0;
  int sourceRefreshes = 0;

  void emitLevel(double level) {
    _onLevel?.call(level);
  }

  @override
  Future<List<AudioInputSource>> listAudioInputSources() async {
    sourceRefreshes++;
    return const [AudioInputSource.systemDefault];
  }

  @override
  Future<bool> startMonitoring(
    AudioInputSource source,
    ValueChanged<double> onLevel,
  ) async {
    monitoringStarts++;
    _onLevel = onLevel;
    return true;
  }

  @override
  Future<void> stopMonitoring() async {
    monitoringStops++;
    if (throwWhenStoppingMonitoring) {
      throw StateError('stop failed');
    }
    _onLevel = null;
  }

  @override
  Future<bool> startRecording(
    AudioInputSource source,
    String recordingFolderPath,
    ValueChanged<double> onLevel,
  ) async {
    recordingStarts++;
    _onLevel = onLevel;
    return true;
  }

  @override
  Future<List<LocalRecorderDraftFile>> stopRecording() async {
    recordingStops++;
    _onLevel = null;
    return const [];
  }

  @override
  Future<void> dispose() async {}
}
