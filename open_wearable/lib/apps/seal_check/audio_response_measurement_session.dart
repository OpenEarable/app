import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/seal_check/seal_check_tone.dart';

/// The playback sample rate expected by OpenEarable seal-check firmware.
const int audioResponseSamplingRate = 48000;

/// Frequencies requested from the seal-check firmware.
const List<int> audioResponseRequestFrequencies = [
  40,
  60,
  90,
  135,
  203,
  304,
  456,
  683,
  1025,
];

/// One frequency and magnitude pair returned by a seal-check measurement.
class AudioResponsePoint {
  /// Creates a validated seal-check response point.
  const AudioResponsePoint({
    required this.frequencyHz,
    required this.magnitude,
  });

  /// Frequency represented by this point, in hertz.
  final double frequencyHz;

  /// Raw FFT magnitude measured by the wearable.
  final double magnitude;

  /// Converts this point to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'frequency_hz': frequencyHz,
        'magnitude': magnitude,
      };
}

/// Typed result used by the Seal Check app.
class AudioResponseMeasurement {
  /// Creates an app measurement from a protocol [result].
  factory AudioResponseMeasurement.fromProtocol(AudioResponseResult result) {
    if (result.frequencies.length != result.points ||
        result.response.length != result.points) {
      throw FormatException(
        'Audio response result point count does not match its data arrays.',
      );
    }

    final points = List<AudioResponsePoint>.generate(
      result.points,
      (index) => AudioResponsePoint(
        frequencyHz: result.frequencies[index].toDouble(),
        magnitude: result.response[index].toDouble(),
      ),
      growable: false,
    );
    return AudioResponseMeasurement._(id: result.id, points: points);
  }

  const AudioResponseMeasurement._({
    required this.id,
    required this.points,
  });

  /// Protocol measurement identifier.
  final int id;

  /// Frequency response points returned by the wearable.
  final List<AudioResponsePoint> points;

  /// Converts this measurement to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'points': points.map((point) => point.toJson()).toList(growable: false),
      };
}

/// Coordinates buffer uploads and measurements for one Seal Check app run.
///
/// A manager receives the generated stimulus only before its first measurement.
/// The committed buffer is then reused for subsequent measurements.
class AudioResponseMeasurementSession {
  /// Creates a session for the selected [left] and/or [right] managers.
  AudioResponseMeasurementSession({
    this.left,
    this.right,
    List<int>? samples,
    List<int> frequencies = audioResponseRequestFrequencies,
    this.samplingRate = audioResponseSamplingRate,
    this.volume = 1.0,
  })  : assert(left != null || right != null),
        assert(volume >= 0 && volume <= 1),
        assert(frequencies.isNotEmpty),
        assert(frequencies.length <= 0xff),
        assert(frequencies.every(_isUint16Frequency)),
        frequencies = List.unmodifiable(frequencies),
        samples = samples ?? sealCheckToneBuffer;

  /// Manager for the left wearable, when selected.
  final AudioResponseManager? left;

  /// Manager for the right wearable, when selected.
  final AudioResponseManager? right;

  /// Signed 16-bit PCM stimulus uploaded to each manager.
  final List<int> samples;

  /// Sampling rate of [samples].
  final int samplingRate;

  /// Playback volume passed to the wearable.
  final double volume;

  /// Frequency response points requested from the wearable.
  final List<int> frequencies;

  final Map<AudioResponseManager, Future<int>> _bufferUploads = {};
  int _nextTransferId = 1;
  int _nextMeasurementId = 1;

  /// Measures all selected managers in parallel.
  Future<({AudioResponseMeasurement? left, AudioResponseMeasurement? right})>
      measure() async {
    final measurementId = _takeMeasurementId();
    final results = await Future.wait([
      if (left != null)
        _measure(left!, measurementId).then((value) => (true, value)),
      if (right != null)
        _measure(right!, measurementId).then((value) => (false, value)),
    ]);

    AudioResponseMeasurement? leftResult;
    AudioResponseMeasurement? rightResult;
    for (final (isLeft, result) in results) {
      if (isLeft) {
        leftResult = result;
      } else {
        rightResult = result;
      }
    }
    return (left: leftResult, right: rightResult);
  }

  Future<AudioResponseMeasurement> _measure(
    AudioResponseManager manager,
    int measurementId,
  ) async {
    final transferId = await _ensureBufferUploaded(manager);
    final result = await manager.measureAudioResponse(
      AudioResponseConfig(
        id: measurementId,
        transfer_id: transferId,
        volume: volume,
        points: frequencies.length,
        frequencies: frequencies,
      ),
    );
    return AudioResponseMeasurement.fromProtocol(result);
  }

  Future<int> _ensureBufferUploaded(AudioResponseManager manager) async {
    final existingUpload = _bufferUploads[manager];
    if (existingUpload != null) {
      return existingUpload;
    }

    final upload = _uploadBuffer(manager);
    _bufferUploads[manager] = upload;
    try {
      return await upload;
    } on Object {
      if (identical(_bufferUploads[manager], upload)) {
        _bufferUploads.remove(manager);
      }
      rethrow;
    }
  }

  Future<int> _uploadBuffer(AudioResponseManager manager) async {
    final transferId = _takeTransferId();
    await manager.uploadAudioBuffer(
      transferId: transferId,
      samples: samples,
      samplingRate: samplingRate,
    );
    return transferId;
  }

  int _takeTransferId() {
    final id = _nextTransferId;
    _nextTransferId = _nextTransferId == 0xffff ? 1 : _nextTransferId + 1;
    return id;
  }

  int _takeMeasurementId() {
    final id = _nextMeasurementId;
    _nextMeasurementId =
        _nextMeasurementId == 0xff ? 1 : _nextMeasurementId + 1;
    return id;
  }
}

bool _isUint16Frequency(int frequency) => frequency > 0 && frequency <= 0xffff;
