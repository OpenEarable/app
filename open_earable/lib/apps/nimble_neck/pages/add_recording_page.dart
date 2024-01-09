import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

import '../components/recording_values.dart';
import '../model/record_value.dart';
import '../model/recording.dart';
import '../utils/math_utils.dart';

/// Lets the user record new values
/// Lets the user connect to an OpenEarable device
class AddRecordingPage extends StatefulWidget {
  /// Callback for when the user saves the new values
  final void Function(Recording) saveRecording;

  /// OpenEarable instance to use for recording
  final OpenEarable openEarable;

  const AddRecordingPage(
      {super.key, required this.saveRecording, required this.openEarable});

  @override
  State<AddRecordingPage> createState() => _AddRecordingPageState();
}

class _AddRecordingPageState extends State<AddRecordingPage> {
  var controller = Flutter3DController();

  StreamSubscription? _sensorSubscription;

  var _isRecording = false;

  double _rollDegree = 0;
  double _pitchDegree = 0;
  double _yawDegree = 0;

  double _startRollDegree = 0;
  double _startPitchDegree = 0;
  double _startYawDegree = 0;

  double _minRollDegree = 0;
  double _minPitchDegree = 0;
  double _minYawDegree = 0;

  double _maxRollDegree = 0;
  double _maxPitchDegree = 0;
  double _maxYawDegree = 0;

  final List<String> logs = [];

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _setSensorListener();
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = widget.openEarable.bleManager.connected;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('New Recording'),
        actions: [
          Visibility(
              visible: _isRecording,
              child: IconButton(
                color: Theme.of(context).colorScheme.error,
                onPressed: _reset,
                icon: const Icon(Icons.stop_circle),
              )),
        ],
      ),
      body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Visibility(
                  visible: isConnected,
                  child: Column(
                    children: [
                      Text(
                          _isRecording
                              ? 'Move your head in every direction!\nThen click Save!'
                              : 'Stand up straight, looking forward!\nThen click Start!',
                          textAlign: TextAlign.center),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 32, 0, 32),
                        child: Transform(
                          alignment: Alignment.center,
                          transform:
                              Matrix4.rotationZ(math.pi * _rollDegree / 180),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.width,
                            child: Flutter3DViewer(
                              controller: controller,
                              src: 'assets/head.glb',
                              //src: 'assets/sheen_chair.glb',
                            ),
                          ),
                        ),
                      ),
                      RecordingValues(recording: _createRecording()),
                    ],
                  ))
            ],
          )),
      floatingActionButton: _isRecording
          ? FloatingActionButton.extended(
              onPressed: _save,
              label: const Text('Save'),
              icon: const Icon(Icons.save))
          : FloatingActionButton.extended(
              onPressed: _startRecording,
              label: const Text('Start'),
              icon: const Icon(Icons.play_circle)),
    );
  }

  /// Starts listening to the 3D values of the [OpenEarable] if connected
  /// Norms the measured values using the start values
  /// Tries to fix the yaw-value by using a threshold
  void _setSensorListener() {
    if (widget.openEarable.bleManager.connected) {
      final config =
          OpenEarableSensorConfig(sensorId: 0, samplingRate: 30, latency: 0);
      widget.openEarable.sensorManager.writeSensorConfig(config);

      double yawDegreeCorrection = 0;
      double prevYawDegree = _yawDegree;

      _sensorSubscription?.cancel();
      _sensorSubscription = widget.openEarable.sensorManager
          .subscribeToSensorData(0)
          .listen((data) {
        final roll = data['EULER']['ROLL'];
        final pitch = data['EULER']['PITCH'];
        final yaw = data['EULER']['YAW'];

        _rollDegree = radianToDegree(roll) - _startRollDegree;
        _pitchDegree = radianToDegree(pitch) - _startPitchDegree;
        final sensorYawDegree =
            radianToDegree(yaw) - _startYawDegree - yawDegreeCorrection;

        if ((sensorYawDegree - prevYawDegree).abs() > 0.1) {
          _yawDegree = sensorYawDegree;
        }

        prevYawDegree = sensorYawDegree;

        setState(() {});
        _setCamera();

        if (_isRecording) {
          _minRollDegree = math.min(_rollDegree, _minRollDegree);
          _minPitchDegree = math.min(_pitchDegree, _minPitchDegree);
          _minYawDegree = math.min(_yawDegree, _minYawDegree);

          _maxRollDegree = math.max(_rollDegree, _maxRollDegree);
          _maxPitchDegree = math.max(_pitchDegree, _maxPitchDegree);
          _maxYawDegree = math.max(_yawDegree, _maxYawDegree);
        }
      });
    }
  }

  /// Starts recording
  /// Sets start values to norm the measured values
  void _startRecording() {
    _isRecording = true;
    _startRollDegree = _rollDegree;
    _startPitchDegree = _pitchDegree;
    _startYawDegree = _yawDegree;
  }

  /// Stops recording
  /// Resets values to zero
  void _reset() {
    _isRecording = false;
    _startRollDegree = 0;
    _startPitchDegree = 0;
    _startYawDegree = 0;

    _minRollDegree = 0;
    _minPitchDegree = 0;
    _minYawDegree = 0;

    _maxRollDegree = 0;
    _maxPitchDegree = 0;
    _maxYawDegree = 0;
  }

  /// Saves a new recording
  _save() {
    final recording = _createRecording();
    widget.saveRecording(recording);
    Navigator.of(context).pop();
  }

  /// Sets the angles of the 3D-Head-Model
  _setCamera() {
    controller.setCameraOrbit(-_yawDegree, -_pitchDegree + 90, 500);
  }

  /// Creates and returns a [Recording] instance from the measured values and the current [DateTime]
  Recording _createRecording() => Recording(
      datetime: DateTime.now(),
      roll:
          RecordValue(min: _minRollDegree.toInt(), max: _maxRollDegree.toInt()),
      pitch: RecordValue(
          min: _minPitchDegree.toInt(), max: _maxPitchDegree.toInt()),
      yaw: RecordValue(min: _minYawDegree.toInt(), max: _maxYawDegree.toInt()));
}
