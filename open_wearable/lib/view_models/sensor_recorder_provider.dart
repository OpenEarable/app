import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class SensorRecorderProvider with ChangeNotifier {
  final Map<Wearable, Map<Sensor, Recorder>> _recorders = {};

  bool _isRecording = false;
  bool _hasSensorsConnected = false;
  String? _currentDirectory;

  bool get isRecording => _isRecording;
  bool get hasSensorsConnected => _hasSensorsConnected;
  String? get currentDirectory => _currentDirectory;

  void startRecording(String dirname) async {
    _isRecording = true;
    _currentDirectory = dirname;

    for (Wearable wearable in _recorders.keys) {
      for (Sensor sensor in _recorders[wearable]!.keys) {
        Recorder? recorder = _recorders[wearable]?[sensor];
        if (recorder != null) {
          File file = await recorder.start(
            filepath: '$dirname/${wearable.name}_${sensor.sensorName}.csv',
            inputStream: sensor.sensorStream,
          );
          logger.i('Started recording for ${wearable.name} - ${sensor.sensorName} to ${file.path}');
        }
      }
    }
    
    notifyListeners();
  }

  void stopRecording() {
    _isRecording = false;
    for (Wearable wearable in _recorders.keys) {
      for (Sensor sensor in _recorders[wearable]!.keys) {
        Recorder? recorder = _recorders[wearable]?[sensor];
        if (recorder != null) {
          recorder.stop();
          logger.i('Stopped recording for ${wearable.name} - ${sensor.sensorName}');
        }
      }
    }
    notifyListeners();
  }

  Recorder? getRecorder(Wearable wearable, Sensor sensor) {
    if (!_recorders.containsKey(wearable)) {
      return null;
    }
    return _recorders[wearable]?[sensor];
  }

  Map<Sensor, Recorder> getRecorders(Wearable wearable) {
    return _recorders[wearable] ?? {};
  }

  void addWearable(Wearable wearable) {
    if (!_recorders.containsKey(wearable)) {
      _recorders[wearable] = {};
    }

    wearable.addDisconnectListener(() {
      removeWearable(wearable);
      notifyListeners();
    });

    if (wearable is SensorManager) {
      for (Sensor sensor in (wearable as SensorManager).sensors) {
        if (!_recorders[wearable]!.containsKey(sensor)) {
          _recorders[wearable]![sensor] = Recorder(columns: sensor.axisNames);
        }
      }
    }

    _updateConnected();
  }

  void removeWearable(Wearable wearable) {
    _recorders.remove(wearable);
    _updateConnected();
  }

  void _updateConnected() {
    _hasSensorsConnected = !(
      _recorders.isEmpty ||
      _recorders.values.every((sensors) => sensors.isEmpty)
    );

    notifyListeners();
  }
}
