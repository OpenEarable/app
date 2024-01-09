import 'dart:math';

import 'package:flutter/material.dart';
import 'package:open_earable/apps/mental_performance_tracker/view/configuration_page.dart';
import 'package:three_dart/three_dart.dart';
import '../model/session.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'dart:async';
import '../model/utility.dart';
import 'dart:ui' as ui;

class SessionPage extends StatefulWidget {
  SessionPage(this.openEarable, this.currentSession);
  final OpenEarable openEarable;
  final Session currentSession;
  final String title = "Learning Session";

  @override
  State<SessionPage> createState() => _SessionPageState(openEarable, currentSession);
}

class _SessionPageState extends State<SessionPage> {
  final OpenEarable openEarable;
  final Session currentSession;
  _SessionPageState(this.openEarable, this.currentSession);
  bool paused = false;
  StreamSubscription? _imuSubscription;
  StreamSubscription? _barometerSubscription;
  bool _recording = true;
  List<double> temperatures = List.empty(growable: true);
  List<List<double>> movement = List.empty(growable: true);
  bool initializationPhase = true;
  bool currentlyMoving = false;
  late double ax = 0;
  late double ay = 0;
  late double az = 0;
  late double timestampAcc = 0;
  late double timestampBar = 0;
  late double temperature = 0;
  late double currentScore = 0;
  late int timeWithoutMovement = currentSession.notMovedFor.toInt();
  late Timer scoreTimer, temperatureConstantTimer, movementTimer, temperatureTimer, movementLogTimer;
  late double estimatedCurrentPhase, initialTemperature;
  late TimeOfDay startetMoving, stoppedMoving = TimeOfDay.now();

  // calculate the color based on the current score(score of 0 --> red, score of 100 --> green)
  ui.Color calculateColor(double score) {
    int green = (255.0 * (score / 100)).toInt();
    int red = (255.0 * (1 - (score / 100))).toInt();
    int alpha = 255;
    num result = alpha * pow(2, 24).toInt() + green * pow(2, 8) + red * pow(2, 16);
    return ui.Color(result.toInt());
  }

  // initialization function for the page
  void initState() {
    super.initState();
    // timer to update the score Value
    scoreTimer = Timer.periodic(Duration(milliseconds: 1000), (Timer t) => updateScore());
    // timer to check regularly if the temperature has stabelized
    temperatureConstantTimer = Timer.periodic(Duration(milliseconds: 100), (Timer t) => checkTemperatureConstant());
    // timer to log the current "activitylevel"
    movementLogTimer = Timer.periodic(Duration(milliseconds: 1000), (Timer t) => logMovement());
    // timer to check for movement
    movementTimer = Timer.periodic(Duration(milliseconds: 100), (Timer t) => checkMovement(currentSession.setup));
    _setupListeners();
  }

  // add the current imu data to the movement-list
  logMovement() {
    movement.add([ax, az, ay]);
  }

  // function to update the score
  updateScore() {
    // differenciate between initialization phase, where the reference temperature is set and measuring phase
    if (!initializationPhase) {
      if (currentlyMoving) {
        setState(() {
          timeWithoutMovement = 0;
        });
      } else {
        setState(() {
          // calculate time without movement(current time - time when movement was above threshhold last time)
          timeWithoutMovement = Math.abs((stoppedMoving.minute - TimeOfDay.now().minute) + (stoppedMoving.hour - TimeOfDay.now().hour) * 60.0).toInt();
        });
        // 40 minutes without movement is maximum penalty for the score
        if (timeWithoutMovement > 40) {
          setState(() {
            timeWithoutMovement = 40;
          });
        }
      }
      int interval = 5;
      double sum = 0;
      // cleanup the tempeartures list to reduce memory cost
      temperatures = temperatures.sublist(temperatures.length - (interval));
      // smoother temperature curve
      for (var i = 0; i < interval; i++) {
        sum += temperatures[i];
      }
      temperature = Math.round((sum / interval) * 100) / 100.0;

      // actual score calculation
      double differenceTimeNotMoved = (40.0 - timeWithoutMovement) / 40.0;
      estimatedCurrentPhase = currentSession.estimatedStartPhase;
      List<double> ratios = [0.70, 0.30]; // ScoreImpact of timeWithoutMovement and temperature
      double temperatureDifference = initialTemperature - temperature;
      double temperatureResult = estimatedCurrentPhase - (temperatureDifference / 0.3); // normalize (0.3 is the maximum temperature difference)
      // clip the results to the max(1) /min (0)
      if (temperatureResult > 1) {
        temperatureResult = 1.0;
      } else if (temperatureResult < 0) {
        temperatureResult = 0.0;
      }
      setState(() {
        currentScore = (differenceTimeNotMoved * 100) * ratios[0] + (temperatureResult * 100) * ratios[1];
        currentScore = (currentScore).round().toDouble();
      });
    } else {
      checkTemperatureConstant();
    }
  }

  // checks if there was strong enough movement in the specified time Intervall, differenciating between sitting and standig acitvity.
  checkMovement(Setup? setup) {
    int interval = 10;
    double sum = 0;
    if (movement.length >= interval + 5) {
      movement = movement.sublist(movement.length - (interval + 5));
      if (setup == Setup.sitting) {
        // calculate general movement indicator sum of all movement directions
        for (var i = movement.length - interval; i < movement.length; i++) {
          for (var j = 0; j < 3; j++) {
            if (j == 2) {
              sum += Math.abs(movement[i][j]) * 2; //when sitting, set greater focus on vertical movements
            } else {
              sum += Math.abs(movement[i][j]);
            }
          }
          sum -= 9.81;
        }
      } else {
        // calculate general movement indicator sum of all movement directions
        for (var i = movement.length - interval; i < movement.length; i++) {
          for (var j = 0; j < 3; j++) {
            if (j == 2) {
              sum += Math.abs(movement[i][j]);
            } else {
              sum += Math.abs(movement[i][j]);
            }
            sum = -9.81;
          }
        }
      }
      double mean = sum / interval;
      if (mean > 12.0) {
        // 12 is the threshhold for movement
        if (!currentlyMoving) {
          setState(() {
            currentlyMoving = true;
            startetMoving = TimeOfDay.now();
          });
        }
      } else {
        if (currentlyMoving) {
          setState(() {
            currentlyMoving = false;
            stoppedMoving = TimeOfDay.now();
          });
        }
      }
    }
  }

  // checks if the temperature of the last 50 values stays within a range of +- 0,01°C =>roughly constant
  void checkTemperatureConstant() {
    bool result = false;
    int interval = 50;
    // wait until at least 50 values are present
    if (temperatures.length > interval) {
      double reference = temperatures[temperatures.length - interval];
      temperatures = temperatures.sublist(temperatures.length - interval);
      for (var i = 0; i < interval; i++) {
        if (temperatures[i] < reference + 0.01 && temperatures[i] > reference - 0.01) {
          result = true;
        } else {
          result = false;
          break;
        }
      }
      // if temperature is constant, set referenceTemperature to monitor later changes
      if (result) {
        initialTemperature = reference;
        temperatureConstantTimer.cancel();
      }
    }
    // end the initialization phase
    setState(() {
      initializationPhase = !result;
    });
  }

  // end the learning- / monitoringsession
  _endSession() {
    _recording = false;
    Navigator.push(context, MaterialPageRoute(builder: (context) => ConfigPage(openEarable)));
  }

  // pause the learning- / monitoringsession
  _pauseSession() {
    setState(() {
      _recording = false;
      paused = true;
    });
  }

  // resume the learning- / monitoringsession
  _resumeSession() {
    setState(() {
      _recording = true;
      paused = false;
    });
  }

  // setup the data listeners for the imu(accelerometer) and the barometer(temperature sensor)
  _setupListeners() {
    _imuSubscription = openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
      if (!_recording) {
        return;
      }
      timestampAcc = parseFloat(data["timestamp"].toString());

      ax = parseFloat(data["ACC"]["X"].toString());
      ay = parseFloat(data["ACC"]["Y"].toString());
      az = parseFloat(data["ACC"]["Z"].toString());
    });

    _barometerSubscription = openEarable.sensorManager.subscribeToSensorData(1).listen((data) {
      if (!_recording) {
        return;
      }

      // read Barometer/Temperature data
      timestampBar = parseFloat(data["timestamp"].toString());
      temperatures.add(parseFloat(data["TEMP"]["Temperature"].toString()));

      //smoothing the curve by applying the mean over 5 consecutive values
      int interval = 5;
      if (temperatures.length >= interval) {
        double sum = 0;
        for (var i = 0; i < interval; i++) {
          sum += temperatures[i];
        }
        temperature = Math.round((sum / interval) * 100) / 100.0;
      } else {
        double sum = 0;
        for (var value in temperatures) {
          sum += value;
        }
        temperature = Math.round((sum / temperatures.length) * 100) / 100.0;
      }
    });
  }

  // building the app layout
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(initializationPhase ? "initializing..." : currentScore.toString(),
                style: TextStyle(height: 1, fontSize: 100, color: calculateColor(currentScore))),
            Text("Temperature: $temperature"),
            Text("Time without movement: $timeWithoutMovement"),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.bottomRight,
                  child: ElevatedButton(onPressed: _endSession, child: Text("End Session")),
                ),
                Align(
                    alignment: Alignment.bottomLeft,
                    child: ElevatedButton(
                        onPressed: (!paused) ? _pauseSession : _resumeSession, child: (!paused) ? Text("Pause Session") : Text("Resume Session")))
              ],
            )
          ],
        )));
  }
}
