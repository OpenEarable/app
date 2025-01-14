import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/utils/sensor_datatypes.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/widgets/assignment_text.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

import '../views/pomodoro_app_settings.dart';
import 'i_exercise.dart';

/// The NodExercise is an exercise where the user has to nod with their head.
/// The user has to nod back and forth the specified number of times.
class NodExercise extends StatefulWidget implements IExercise {
  final OpenEarable openEarable;
  final Function onFinish;
  final PomodoroAppSettings pomodoroAppSettings;

  /// The constructor for the NodExercise.
  /// The [pomodoroAppSettings] are the settings for the Pomodoro Timer App,
  /// which contain the amount of repetitions for the nod exercise.
  /// The [onFinish] function is called when the exercise is finished.
  const NodExercise(this.openEarable, this.pomodoroAppSettings, this.onFinish, {super.key});

  @override
  void finished() {
    onFinish();
  }

  @override
  State<NodExercise> createState() => _NodExerciseState();
}

class _NodExerciseState extends State<NodExercise>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _imuSubscription;
  SensorDataType accelerationData = NullData();
  late AnimationController _animationController;
  late Animation<double> _animation;
  late Animation<Color?> _colorAnimation;

  DateTime time = DateTime.now();
  int timesLeft = 10;
  double nodThreshold = 4.5;
  double nodMinThreshold = 1;
  bool ready = false;

  @override
  void initState() {
    super.initState();

    timesLeft = widget.pomodoroAppSettings.nodExerciseDefaultRepetitions;


    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    _colorAnimation = ColorTween(begin: Colors.red, end: Colors.green)
        .animate(_animationController);

    if (widget.openEarable.bleManager.connected) {
      print("connected");
      widget.openEarable.sensorManager.writeSensorConfig(_buildSensorConfig());
      _setupListeners();
    }
  }

  @override
  void dispose() {
    _imuSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  /// Sets up the listeners for the sensor data
  void _setupListeners() {
    _imuSubscription = widget.openEarable.sensorManager
        .subscribeToSensorData(0)
        .listen(_processSensorData);
  }

  /// Processes the sensor data and save it in state
  void _processSensorData(Map<String, dynamic> data) {
    Acceleration accelerationData = Acceleration(data);
    setState(() {
      this.accelerationData = accelerationData;
    });

    _processNod();
    _updateProgress();
  }

  /// Updates the progress bar
  void _updateProgress() {
    double progress = (accelerationData.x - nodMinThreshold) /
        (nodThreshold + nodMinThreshold);
    _animationController.animateTo(progress,
        duration: Duration(milliseconds: 50),);
  }

  /// Process sensor input for nodding
  void _processNod() {
    if (!ready) {
      if (accelerationData.x < nodMinThreshold &&
          _animationController.value < 0.03) {
        widget.openEarable.audioPlayer.jingle(7);

        setState(() {
          ready = true;
          timesLeft--;
        });
      }
    } else if (accelerationData.x > nodThreshold + nodMinThreshold &&
        _animationController.value > 0.97) {
      widget.openEarable.audioPlayer.jingle(6);
      setState(() {
        timesLeft--;
        ready = false;
        if (timesLeft <= 0) {
          widget.finished();
        }
      });
      if (timesLeft == 0) {
        print("done");
      }
    }
  }

  /// Builds the sensor config for the nod exercise
  OpenEarableSensorConfig _buildSensorConfig() {
    return OpenEarableSensorConfig(
      sensorId: 0,
      samplingRate: 30,
      latency: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AssignmentText("Nod with your head! "
            "First move it back until you hear a sound to activate the recognition, then move it forward until you hear a sound!"),
        Padding(
          padding: const EdgeInsets.all(3.0),
          child: Container(
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Text(
                "Times left: $timesLeft",
                style: TextStyle(
                  fontSize: 20, // Increase the font size
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 30,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "lib/apps_tab/pomodoro_timer/assets/nodhead.png",
              height: 300,
            ),
            SizedBox(
              width: 20,
              height: 300,
              child: RotatedBox(
                quarterTurns: 3,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      borderRadius: BorderRadius.circular(10),
                      value: _animation.value,
                      valueColor: _colorAnimation,
                      backgroundColor: Colors.blue,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        //ElevatedButton(onPressed: widget.finished, child: Text("skipskip")),
      ],
    );
  }
}
