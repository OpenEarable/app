import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:open_wearable/apps/seal_check/audio_response_measurement_session.dart';
import 'package:open_wearable/apps/seal_check/seal_check_quality.dart';

void main() {
  group('computeSealCheckQuality', () {
    test('returns zero when fewer than two valid peaks are available', () {
      expect(computeSealCheckQuality(const []), 0);
      expect(
        computeSealCheckQuality(
          const [AudioResponsePoint(frequencyHz: 40, magnitude: 119)],
        ),
        0,
      );
    });

    test('matches the firmware formula for valid peaks in index order', () {
      final points = List<AudioResponsePoint>.generate(
        sealCheckTargetMagnitudes.length,
        (index) => AudioResponsePoint(
          frequencyHz: audioResponseRequestFrequencies[index].toDouble(),
          magnitude: sealCheckReferenceAverageMagnitude *
              sealCheckTargetMagnitudes[index],
        ),
      );

      expect(computeSealCheckQuality(points), closeTo(100, 0.000001));
    });

    test('ignores non-positive response points before calculating quality', () {
      final points = const [
        AudioResponsePoint(frequencyHz: 40, magnitude: 119),
        AudioResponsePoint(frequencyHz: 60, magnitude: 0),
        AudioResponsePoint(frequencyHz: 90, magnitude: 100),
        AudioResponsePoint(frequencyHz: 135, magnitude: -1),
      ];

      expect(
        computeSealCheckQuality(points),
        closeTo(_expectedFirmwareQuality(points), 0.000001),
      );
    });
  });
}

double _expectedFirmwareQuality(List<AudioResponsePoint> points) {
  final validPoints = points
      .where((point) => point.frequencyHz > 0 && point.magnitude > 0)
      .toList(growable: false);
  if (validPoints.length < 2) {
    return 0;
  }

  final logFrequencies =
      validPoints.map((point) => math.log(point.frequencyHz)).toList();
  final amplitudes = validPoints.map((point) => point.magnitude).toList();
  final meanLogFrequency = logFrequencies.reduce((sum, value) => sum + value) /
      logFrequencies.length;
  final meanAmplitude =
      amplitudes.reduce((sum, value) => sum + value) / amplitudes.length;

  var numerator = 0.0;
  var denominator = 0.0;
  for (var index = 0; index < validPoints.length; index++) {
    final logFrequencyDiff = logFrequencies[index] - meanLogFrequency;
    final amplitudeDiff = amplitudes[index] - meanAmplitude;
    numerator += logFrequencyDiff * amplitudeDiff;
    denominator += logFrequencyDiff * logFrequencyDiff;
  }

  final slope = denominator == 0.0 ? 0.0 : numerator / denominator;

  var mse = 0.0;
  for (var index = 0; index < validPoints.length; index++) {
    final frequencyError =
        amplitudes[index] / meanAmplitude - sealCheckTargetMagnitudes[index];
    mse += frequencyError * frequencyError;
  }
  mse /= validPoints.length;

  final quality = math.min(
        meanAmplitude / sealCheckReferenceAverageMagnitude,
        1,
      ) -
      mse -
      (slope / sealCheckReferenceAverageMagnitude -
          sealCheckReferenceAverageSlope);
  return (quality * 100).clamp(0, 100);
}
