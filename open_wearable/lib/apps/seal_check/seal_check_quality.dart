import 'dart:math' as math;

import 'package:open_wearable/apps/seal_check/audio_response_measurement_session.dart';

/// Reference average peak magnitude used by the firmware quality formula.
const double sealCheckReferenceAverageMagnitude = 119.0;

/// Reference slope used by the firmware quality formula.
const double sealCheckReferenceAverageSlope = -0.07382279460490486;

/// Target response curve used by the firmware quality formula.
const List<double> sealCheckTargetMagnitudes = [
  0.90833731,
  1.18334124,
  1.38796968,
  1.16634027,
  0.85781358,
  0.65981396,
  0.84768657,
  0.98236069,
  1.00633671,
];

/// Computes seal-check quality with the same regression formula as firmware.
///
/// The firmware first extracts valid peaks from the full FFT spectrum, then
/// computes quality from those valid peaks in their discovered order. The app
/// receives already-selected seal-check response points, so positive points are
/// treated as the valid peak set and are compared to [sealCheckTargetMagnitudes]
/// by index, matching the final C quality block.
double computeSealCheckQuality(List<AudioResponsePoint> points) {
  final validPoints = points
      .where((point) => point.frequencyHz > 0 && point.magnitude > 0)
      .toList(growable: false);
  if (validPoints.length < 2) {
    return 0.0;
  }

  final logFrequencies = validPoints
      .map((point) => math.log(point.frequencyHz))
      .toList(growable: false);
  final amplitudes =
      validPoints.map((point) => point.magnitude).toList(growable: false);

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
  final averagePeakMagnitude = meanAmplitude;

  var mse = 0.0;
  for (var index = 0; index < validPoints.length; index++) {
    final targetMagnitude = sealCheckTargetMagnitudes[index];
    final frequencyError =
        amplitudes[index] / averagePeakMagnitude - targetMagnitude;
    mse += frequencyError * frequencyError;
  }
  mse /= validPoints.length;

  final quality = math.min(
        averagePeakMagnitude / sealCheckReferenceAverageMagnitude,
        1.0,
      ) -
      mse -
      (slope / sealCheckReferenceAverageMagnitude -
          sealCheckReferenceAverageSlope);

  return (quality * 100.0).clamp(0.0, 100.0);
}
