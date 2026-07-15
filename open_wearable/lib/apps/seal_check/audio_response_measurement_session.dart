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

/// Phase currently being performed by a seal-check measurement session.
enum AudioResponseMeasurementPhase {
  /// The pregenerated tone is being uploaded to one or more wearables.
  uploadingTone,

  /// Uploaded tones are being played and measured by the wearables.
  measuringResponse,
}

/// Progress information emitted while a seal-check measurement is running.
class AudioResponseMeasurementProgress {
  /// Creates a progress snapshot for the current session phase.
  const AudioResponseMeasurementProgress({
    required this.phase,
    required this.completedUploads,
    required this.totalUploads,
    required this.acknowledgedSamples,
    required this.totalSamples,
  })  : assert(completedUploads >= 0),
        assert(totalUploads >= 0),
        assert(completedUploads <= totalUploads),
        assert(acknowledgedSamples >= 0),
        assert(totalSamples >= 0),
        assert(acknowledgedSamples <= totalSamples);

  /// Current session phase.
  final AudioResponseMeasurementPhase phase;

  /// Number of tone uploads that have completed successfully.
  final int completedUploads;

  /// Number of tone uploads required before measuring starts.
  final int totalUploads;

  /// Number of uploaded samples acknowledged by the selected wearables.
  final int acknowledgedSamples;

  /// Number of samples that must be acknowledged before measuring starts.
  final int totalSamples;

  /// Acknowledged sample fraction, or `null` when there is no upload work.
  double? get uploadFraction {
    if (totalSamples == 0) return null;
    return acknowledgedSamples / totalSamples;
  }
}

/// Receives progress updates from [AudioResponseMeasurementSession.measure].
typedef AudioResponseMeasurementProgressCallback = void Function(
  AudioResponseMeasurementProgress progress,
);

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

  /// Measures all selected managers.
  ///
  /// The pregenerated tone is uploaded once per manager and cached for later
  /// measurements. [onProgress] receives upload and measurement phase changes.
  Future<({AudioResponseMeasurement? left, AudioResponseMeasurement? right})>
      measure({
    AudioResponseMeasurementProgressCallback? onProgress,
  }) async {
    final measurementId = _takeMeasurementId();
    final managers = _selectedManagers();
    final uploads = managers
        .where((entry) => !_bufferUploads.containsKey(entry.manager))
        .toList(growable: false);

    if (uploads.isNotEmpty) {
      final uploadStates =
          Map<AudioResponseManager, _UploadProgressState>.fromEntries(
        uploads.map(
          (entry) => MapEntry(
            entry.manager,
            _UploadProgressState(totalSamples: samples.length),
          ),
        ),
      );

      void reportUploadProgress() {
        onProgress?.call(
          AudioResponseMeasurementProgress(
            phase: AudioResponseMeasurementPhase.uploadingTone,
            completedUploads:
                uploadStates.values.where((state) => state.completed).length,
            totalUploads: uploadStates.length,
            acknowledgedSamples: uploadStates.values.fold<int>(
              0,
              (sum, state) => sum + state.acknowledgedSamples,
            ),
            totalSamples: uploadStates.values.fold<int>(
              0,
              (sum, state) => sum + state.totalSamples,
            ),
          ),
        );
      }

      reportUploadProgress();

      for (final entry in uploads) {
        final state = uploadStates[entry.manager]!;
        await _ensureBufferUploaded(
          entry.manager,
          onProgress: (progress) {
            state.acknowledgedSamples = progress.acknowledgedSamples.clamp(
              0,
              state.totalSamples,
            );
            state.completed =
                progress.phase == AudioResponseUploadPhase.completed;
            reportUploadProgress();
          },
        );
        state
          ..acknowledgedSamples = state.totalSamples
          ..completed = true;
        reportUploadProgress();
      }
    }

    onProgress?.call(
      const AudioResponseMeasurementProgress(
        phase: AudioResponseMeasurementPhase.measuringResponse,
        completedUploads: 0,
        totalUploads: 0,
        acknowledgedSamples: 0,
        totalSamples: 0,
      ),
    );

    final results = await Future.wait(
      managers.map(
        (entry) => _measureUploaded(entry.manager, measurementId)
            .then((value) => (entry.isLeft, value)),
      ),
    );

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

  List<({bool isLeft, AudioResponseManager manager})> _selectedManagers() => [
        if (left != null) (isLeft: true, manager: left!),
        if (right != null) (isLeft: false, manager: right!),
      ];

  Future<AudioResponseMeasurement> _measureUploaded(
    AudioResponseManager manager,
    int measurementId,
  ) async {
    final transferId = await _bufferUploads[manager]!;
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

  Future<int> _ensureBufferUploaded(
    AudioResponseManager manager, {
    AudioResponseUploadProgressCallback? onProgress,
  }) async {
    final existingUpload = _bufferUploads[manager];
    if (existingUpload != null) {
      return existingUpload;
    }

    final upload = _uploadBufferWithRetry(manager, onProgress: onProgress);
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

  Future<int> _uploadBuffer(
    AudioResponseManager manager, {
    AudioResponseUploadProgressCallback? onProgress,
  }) async {
    final transferId = _takeTransferId();
    await manager.uploadAudioBuffer(
      transferId: transferId,
      samples: samples,
      samplingRate: samplingRate,
      onProgress: onProgress,
    );
    return transferId;
  }

  Future<int> _uploadBufferWithRetry(
    AudioResponseManager manager, {
    AudioResponseUploadProgressCallback? onProgress,
  }) async {
    try {
      return await _uploadBuffer(manager, onProgress: onProgress);
    } on StateError catch (error) {
      if (!_isClosedTransferStatusStream(error)) {
        rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return _uploadBuffer(manager, onProgress: onProgress);
    }
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

class _UploadProgressState {
  _UploadProgressState({required this.totalSamples});

  final int totalSamples;
  int acknowledgedSamples = 0;
  bool completed = false;
}

bool _isClosedTransferStatusStream(StateError error) {
  return error.message == 'Audio response transfer status stream closed';
}

bool _isUint16Frequency(int frequency) => frequency > 0 && frequency <= 0xffff;
