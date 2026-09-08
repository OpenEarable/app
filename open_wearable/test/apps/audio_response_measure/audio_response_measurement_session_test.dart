import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/seal_check/audio_response_measurement_session.dart';
import 'package:open_wearable/apps/seal_check/seal_check_tone.dart';

class _FakeAudioResponseManager implements AudioResponseManager {
  _FakeAudioResponseManager({this.failUploadAttempts = 0});

  final int failUploadAttempts;
  final List<int> transferIds = [];
  final List<List<int>> uploadedSamples = [];
  final List<int> samplingRates = [];
  final List<AudioResponseConfig> configs = [];
  int _uploadAttempts = 0;

  @override
  Future<void> uploadAudioBuffer({
    required int transferId,
    required List<int> samples,
    required int samplingRate,
    int maximumSamplesPerChunk = 118,
    AudioResponseUploadProgressCallback? onProgress,
  }) async {
    _uploadAttempts += 1;
    if (_uploadAttempts <= failUploadAttempts) {
      throw StateError('Audio response transfer status stream closed');
    }

    transferIds.add(transferId);
    uploadedSamples.add(samples);
    samplingRates.add(samplingRate);
    onProgress?.call(
      AudioResponseUploadProgress(
        phase: AudioResponseUploadPhase.starting,
        acknowledgedSamples: 0,
        totalSamples: samples.length,
      ),
    );
    onProgress?.call(
      AudioResponseUploadProgress(
        phase: AudioResponseUploadPhase.uploading,
        acknowledgedSamples: samples.length ~/ 2,
        totalSamples: samples.length,
      ),
    );
    onProgress?.call(
      AudioResponseUploadProgress(
        phase: AudioResponseUploadPhase.completed,
        acknowledgedSamples: samples.length,
        totalSamples: samples.length,
      ),
    );
  }

  @override
  Future<AudioResponseResult> measureAudioResponse(
    AudioResponseConfig config,
  ) async {
    configs.add(config);
    return AudioResponseResult(
      id: config.id,
      points: 2,
      frequencies: [40, 60],
      response: [100, 120],
    );
  }
}

void main() {
  group('AudioResponseMeasurementSession', () {
    test('uploads the pregenerated seal-check tone by default', () async {
      final manager = _FakeAudioResponseManager();
      final session = AudioResponseMeasurementSession(left: manager);

      await session.measure();

      expect(manager.uploadedSamples.single, same(sealCheckToneBuffer));
      expect(manager.samplingRates, [audioResponseSamplingRate]);
    });

    test('requests the configured seal-check response frequencies', () async {
      final manager = _FakeAudioResponseManager();
      final session = AudioResponseMeasurementSession(
        left: manager,
        samples: const [0, 100, -100],
      );

      final first = await session.measure();
      final second = await session.measure();

      expect(manager.transferIds, [1]);
      expect(manager.configs.map((config) => config.transfer_id), [1, 1]);
      expect(manager.configs.map((config) => config.id), [1, 2]);
      expect(
        manager.configs.first.frequencies,
        audioResponseRequestFrequencies,
      );
      expect(
        manager.configs.first.points,
        audioResponseRequestFrequencies.length,
      );
      expect(first.left?.points.first.frequencyHz, 40);
      expect(first.left?.points.first.magnitude, 100);
      expect(second.left?.id, 2);
      expect(first.right, isNull);
    });

    test('uses the same measurement id for both sides', () async {
      final left = _FakeAudioResponseManager();
      final right = _FakeAudioResponseManager();
      final session = AudioResponseMeasurementSession(
        left: left,
        right: right,
        samples: const [1],
      );

      final result = await session.measure();

      expect(left.configs.single.id, right.configs.single.id);
      expect(result.left, isNotNull);
      expect(result.right, isNotNull);
    });

    test('reports upload and measurement progress', () async {
      final manager = _FakeAudioResponseManager();
      final session = AudioResponseMeasurementSession(
        left: manager,
        samples: const [1, 2],
      );
      final progressUpdates = <AudioResponseMeasurementProgress>[];

      await session.measure(onProgress: progressUpdates.add);

      expect(
        progressUpdates.map((progress) => progress.phase).toList(),
        [
          AudioResponseMeasurementPhase.uploadingTone,
          AudioResponseMeasurementPhase.uploadingTone,
          AudioResponseMeasurementPhase.uploadingTone,
          AudioResponseMeasurementPhase.uploadingTone,
          AudioResponseMeasurementPhase.uploadingTone,
          AudioResponseMeasurementPhase.measuringResponse,
        ],
      );
      expect(
        progressUpdates
            .map((progress) => progress.uploadFraction)
            .toList(growable: false),
        [0.0, 0.0, 0.5, 1.0, 1.0, null],
      );
      expect(
        progressUpdates
            .map((progress) => progress.acknowledgedSamples)
            .toList(growable: false),
        [0, 0, 1, 2, 2, 0],
      );
    });

    test('skips upload progress after the tone has been cached', () async {
      final manager = _FakeAudioResponseManager();
      final session = AudioResponseMeasurementSession(
        left: manager,
        samples: const [1],
      );

      await session.measure();

      final progressUpdates = <AudioResponseMeasurementProgress>[];
      await session.measure(onProgress: progressUpdates.add);

      expect(
        progressUpdates.map((progress) => progress.phase).toList(),
        [AudioResponseMeasurementPhase.measuringResponse],
      );
    });

    test('retries a transient closed transfer status stream once', () async {
      final manager = _FakeAudioResponseManager(failUploadAttempts: 1);
      final session = AudioResponseMeasurementSession(
        left: manager,
        samples: const [1],
      );

      await session.measure();

      expect(manager.transferIds, [2]);
    });

    test('surfaces persistent closed transfer status stream failures',
        () async {
      final manager = _FakeAudioResponseManager(failUploadAttempts: 2);
      final session = AudioResponseMeasurementSession(
        left: manager,
        samples: const [1],
      );

      await expectLater(
        session.measure(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Audio response transfer status stream closed',
          ),
        ),
      );
      expect(manager.transferIds, isEmpty);
    });
  });
}
