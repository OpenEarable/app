import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'package:open_earable/shared/earable_not_connected_warning.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';

class TightnessMeter extends StatefulWidget {
  final OpenEarable openEarable;

  const TightnessMeter(this.openEarable, {super.key});

  @override
  State<TightnessMeter> createState() => _TightnessMeterState();
}

class _TightnessMeterState extends State<TightnessMeter> {
  StreamSubscription? _imuSubscription;
  bool _monitoring = false;
  int lastTime = 0;
  double x = 0;
  double y = 0;
  double z = 0;
  double magnitude = 0;
  double difficulty = 0;
  int bpm = 80;
  int score = 0;
  int streak = 0;
  int tightness = 0;
  double nodThreshold = 4; // Time frame in milliseconds to consider for a nod
  final List<int> bpmList = [80, 100, 120, 170, 200];

  // Variables to keep track of nodding
  DateTime lastNodTime = DateTime.now();

  @override
  void dispose() {
    super.dispose();
    _imuSubscription?.cancel();
  }

  void _setupListeners() {
    _imuSubscription = widget.openEarable.sensorManager
        .subscribeToSensorData(0)
        .listen((data) {
      if (!_monitoring) {
        return;
      }
      int timestamp = data["timestamp"];
      setState(() {
        lastTime = timestamp;
        x = data["ACC"]["X"];
        y = data["ACC"]["Y"];
        z = data["ACC"]["Z"];
      });
      _processAccelerometerData(x, y, z);
    });
  }

  void _processAccelerometerData(double x, double y, double z) {
    // Calculate the overall acceleration magnitude
    //print(x.toString() + y.toString() + z.toString());
    magnitude = _calculateMagnitude(x, y, z);
    //print(magnitude);

    // Check if the magnitude exceeds the nodding threshold
    if (magnitude > nodThreshold) {
      DateTime now = DateTime.now();
      //print("Nod detected! 00000000000000000000000000000000");
      // Check if the last nod was within the time frame
      if (now.difference(lastNodTime).inMilliseconds >
          _bpmToMilliseconds(bpm) * 0.7) {
        // Detected a nod
        _isNodTight(lastNodTime, now);
        lastNodTime = now;
      }
    }
  }

  // Calculate the magnitude of the acceleration vector
  double _calculateMagnitude(double x, double y, double z) {
    return math.sqrt(x * x);
  }

  // Check if the nod is tight
  void _isNodTight(DateTime last, DateTime secondToLast) {
    int difference = last.difference(secondToLast).inMilliseconds.abs();
    int expected = _bpmToMilliseconds(bpm);
    if (_isWithinMargin(difference, expected, 25.0 - difficulty)) {
      setState(() {
        streak += 1;
      });
      _updateScore();
    } else {
      setState(() {
        streak = 0;
        tightness = 0;
      });
    }
  }

  void _updateScore() {
    setState(() {
      score = score + (((10 * streak) + difficulty) / tightness.abs()).round();
    });
  }

  bool _isWithinMargin(
    int givenInterval,
    int expectedInterval,
    double marginPercentage,
  ) {
    double margin = expectedInterval * marginPercentage / 100;
    // Calculate the acceptable range
    double lowerBound = expectedInterval - margin;
    double upperBound = expectedInterval + margin;
    setState(() {
      tightness =
          math.min(_bpmToMilliseconds(bpm), (givenInterval - expectedInterval));
    });
    return givenInterval >= lowerBound && givenInterval <= upperBound;
  }

  int _bpmToMilliseconds(int bpm) {
    if (bpm <= 0) {
      throw ArgumentError("BPM must be greater than 0.");
    }
    return (60000 / bpm).round();
  }

  void startStopMonitoring() async {
    if (_monitoring) {
      setState(() {
        _monitoring = false;
      });
      widget.openEarable.audioPlayer.setState(AudioPlayerState.stop);
    } else {
      _setupListeners();
      setState(() {
        _monitoring = true;
        streak = 0;
      });
      //start playing music
      _setWAV(bpm.toString());
    }
  }

  void _setWAV(String bpm) {
    String fileName = "$bpm.wav";
    print("Setting source to wav file with file name '$fileName'");
    widget.openEarable.audioPlayer.wavFile(fileName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Tightness Meter'),
      ),
      body: Provider.of<BluetoothController>(context).connected
          ? SingleChildScrollView(
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(40.0),
                      bottomRight: Radius.circular(40.0),
                      topLeft: Radius.circular(40.0),
                      bottomLeft: Radius.circular(40.0),
                    ),
                  ),
                  width: 500,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Card(
                        margin: EdgeInsets.all(20),
                        color: Colors.black,
                        child: Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(20.0),
                                    bottomRight: Radius.circular(20.0),
                                    topLeft: Radius.circular(20.0),
                                    bottomLeft: Radius.circular(20.0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Score:',
                                      style: TextStyle(fontSize: 20),
                                    ),
                                    Spacer(),
                                    Padding(
                                      padding: EdgeInsets.all(5),
                                      child: Text(
                                        _monitoring ? score.toString() : '0',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      (streak > 0) ? Colors.green : Colors.red,
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(20.0),
                                    bottomRight: Radius.circular(20.0),
                                    topLeft: Radius.circular(20.0),
                                    bottomLeft: Radius.circular(20.0),
                                  ),
                                ),
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Text(
                                      'Streak:',
                                      style: TextStyle(fontSize: 20),
                                    ),
                                    Spacer(),
                                    Padding(
                                      padding: EdgeInsets.all(5),
                                      child: Text(
                                        _monitoring ? streak.toString() : '0',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(20.0),
                                    bottomRight: Radius.circular(20.0),
                                    topLeft: Radius.circular(20.0),
                                    bottomLeft: Radius.circular(20.0),
                                  ),
                                ),
                                padding: EdgeInsets.only(
                                  top: 16,
                                  right: 16,
                                  left: 16,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Tightness:',
                                      style: TextStyle(fontSize: 20),
                                    ),
                                    Spacer(),
                                    Padding(
                                      padding: EdgeInsets.all(5),
                                      child: Text(
                                        _monitoring
                                            ? tightness.toString()
                                            : '0',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(20.0),
                                    bottomRight: Radius.circular(20.0),
                                    topLeft: Radius.circular(20.0),
                                    bottomLeft: Radius.circular(20.0),
                                  ),
                                ),
                                child: Slider(
                                  thumbColor: Colors.purple,
                                  activeColor: Colors.grey,
                                  secondaryActiveColor: Colors.purpleAccent,
                                  inactiveColor: Colors.grey,
                                  value: tightness.toDouble(),
                                  min: -_bpmToMilliseconds(bpm).toDouble(),
                                  max: _bpmToMilliseconds(bpm).toDouble(),
                                  divisions: 2000,
                                  label: tightness.toString(),
                                  onChanged: (double value) {
                                    setState(() {});
                                  },
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20.0),
                              child: Row(
                                children: [
                                  Spacer(),
                                  Text('Early'),
                                  Spacer(flex: 5),
                                  Text('Tight'),
                                  Spacer(flex: 5),
                                  Text('Late'),
                                  Spacer(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Card(
                        margin: EdgeInsets.all(20),
                        color: Colors.black,
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(20),
                              child: ElevatedButton(
                                onPressed: startStopMonitoring,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size(1000, 80),
                                  backgroundColor: _monitoring
                                      ? Color(0xfff27777)
                                      : Theme.of(context).colorScheme.secondary,
                                  foregroundColor: Colors.black,
                                ),
                                child: Text(
                                  _monitoring ? 'Stop' : 'Start',
                                  style: TextStyle(fontSize: 30),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Card(
                        margin: EdgeInsets.all(20),
                        color: Colors.black,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Spacer(),
                                  Text('BPM', style: TextStyle(fontSize: 30)),
                                  Spacer(flex: 5),
                                  DropdownButton<int>(
                                    style: TextStyle(
                                      fontSize: 30,
                                    ),
                                    value: bpm,
                                    icon: const Icon(Icons.arrow_drop_down),
                                    onChanged: _monitoring
                                        ? null
                                        : (int? newValue) {
                                            setState(() {
                                              bpm = newValue!;
                                            });
                                          },
                                    items: bpmList.map<DropdownMenuItem<int>>(
                                        (int value) {
                                      return DropdownMenuItem<int>(
                                        value: value,
                                        child: Text(value.toString()),
                                      );
                                    }).toList(),
                                  ),
                                  Spacer(),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: 20),
                              child: Text(
                                'Sensitivity',
                                style: TextStyle(fontSize: 20),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Slider(
                                    thumbColor: Colors.purple,
                                    activeColor: Colors.purpleAccent,
                                    secondaryActiveColor: Colors.purpleAccent,
                                    inactiveColor: Colors.grey,
                                    value: nodThreshold,
                                    min: 1,
                                    max: 20,
                                    divisions: 10,
                                    label: nodThreshold.round().toString(),
                                    onChanged: (double value) {
                                      setState(() {
                                        nodThreshold = value;
                                      });
                                    },
                                  ),
                                  Row(
                                    children: [
                                      Spacer(),
                                      Text('Cool Nodding'),
                                      Spacer(flex: 10),
                                      Text('Headbanging'),
                                      Spacer(),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Text(
                                'Difficulty',
                                style: TextStyle(fontSize: 20),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Slider(
                                    thumbColor: Colors.purple,
                                    activeColor: Colors.purpleAccent,
                                    secondaryActiveColor: Colors.purpleAccent,
                                    inactiveColor: Colors.grey,
                                    value: difficulty,
                                    min: 0,
                                    max: 25,
                                    divisions: 10,
                                    label: difficulty.round().toString(),
                                    onChanged: (double value) {
                                      setState(() {
                                        difficulty = value;
                                      });
                                    },
                                  ),
                                  Row(
                                    children: [
                                      Spacer(),
                                      Text('Beginner'),
                                      Spacer(flex: 10),
                                      Text('Impossible'),
                                      Spacer(),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            )
          : EarableNotConnectedWarning(),
    );
  }
}
