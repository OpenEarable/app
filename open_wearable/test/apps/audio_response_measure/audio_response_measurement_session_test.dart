import 'package:flutter_test/flutter_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/seal_check/audio_response_measurement_session.dart';
import 'package:open_wearable/apps/seal_check/seal_check_tone.dart';

class _FakeAudioResponseManager implements AudioResponseManager {
  final List<int> transferIds = [];
  final List<List<int>> uploadedSamples = [];
  final List<int> samplingRates = [];
  final List<AudioResponseConfig> configs = [];

  @override
  Future<void> uploadAudioBuffer({
    required int transferId,
    required List<int> samples,
    required int samplingRate,
    int? maximumSamplesPerChunk = 118,
  }) async {
    transferIds.add(transferId);
    uploadedSamples.add(samples);
    samplingRates.add(samplingRate);
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
  });
}
