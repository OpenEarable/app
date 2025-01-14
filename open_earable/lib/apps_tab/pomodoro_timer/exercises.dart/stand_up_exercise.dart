import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/utils/sensor_datatypes.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/widgets/assignment_text.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

import 'i_exercise.dart';


/// The StandUpExercise is an exercise where the user has to stand up.
/// The user has to stand up and stay in the standing position for a few seconds.
class StandUpExercise extends StatefulWidget implements IExercise {
  final OpenEarable openEarable;

  final Function onFinish;

  /// The constructor for the StandUpExercise.
  /// The [onFinish] function is called when the exercise is finished.
  const StandUpExercise(this.openEarable, this.onFinish, {super.key});

  @override
  void finished() {
    onFinish();
  }

  @override
  State<StandUpExercise> createState() => _StandUpExerciseState();
}

class _StandUpExerciseState extends State<StandUpExercise>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _imuSubscription;
  SensorDataType accelerationData = NullData();
  late AnimationController _animationController;
  late Animation<double> _animation;

  DateTime firstTimeOverThreshold = DateTime.now();
  bool movingUP = false;

  bool stoodUP = false;

  bool ready = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);

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

  void _setupListeners() {
    _imuSubscription = widget.openEarable.sensorManager
        .subscribeToSensorData(0)
        .listen(_processSensorData);
  }

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
    double progress = (accelerationData.z - 9) /
        (3);
    _animationController.animateTo(progress,
        duration: Duration(milliseconds: 50),);
  }

  /// Processes the nodding of the head
  void _processNod() {
    if (!ready) {
      if (accelerationData.z > 10) {
        setState(() {
          ready = true;
          movingUP = false;
        });
      }
    } else if (accelerationData.z < 8.5) {
      if (!movingUP) {
        setState(() {
          firstTimeOverThreshold = DateTime.now();
          movingUP = true;
        });
      } else if (DateTime
          .now()
          .difference(firstTimeOverThreshold)
          .inMilliseconds >
          800) {
        stoodUP = true;
        widget.openEarable.audioPlayer.jingle(6);
        widget.finished();        }
    }
  }



  /// Builds the sensor configuration for the exercise
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
        AssignmentText("Stand up!"),
        //Text("stand up: $stoodUP"),
        SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('lib/apps_tab/pomodoro_timer/assets/standup.png', height: 300),
            SizedBox(
              width: 20,
              height: 200,
              child: RotatedBox(
                quarterTurns: 3,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: _animation.value,
                      backgroundColor: movingUP ? Colors.green : Colors.red,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    );
                  },
                ),
              ),
            ),
          ],
        ),

        //ElevatedButton(onPressed: widget.finished, child: Text("skip")),
      ],
    );
  }
}
