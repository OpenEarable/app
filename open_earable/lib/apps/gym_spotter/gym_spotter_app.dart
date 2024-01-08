import 'package:flutter/material.dart';
import 'package:circular_menu/circular_menu.dart';
import 'package:open_earable/apps/gym_spotter/model/model_states.dart';
import 'package:open_earable/apps/gym_spotter/view/how_to_use_view.dart';
import 'package:open_earable/apps/gym_spotter/model/data_handler.dart';
import 'package:open_earable/widgets/earable_not_connected_warning.dart';
import 'dart:async';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:open_earable/apps/gym_spotter/view/how_to_deadlift.dart';
import 'package:simple_kalman/simple_kalman.dart';

// Widget that handles gym spotter app
class Spot extends StatefulWidget {
  final OpenEarable _openEarable;
  Spot(this._openEarable);
  @override
  State<Spot> createState() => _SpotState(_openEarable);
}

class _SpotState extends State<Spot> {
  final OpenEarable _openEarable;
  StreamSubscription? _imuSubscription;

  DataHandler _dataHandler = DataHandler();

  // last transmitted model state
  late ModelState _state;

  /// Minimum time a  a repetition feedback ([ModelState.GoodRepetition] or [ModelState.BadRepetition]) stays on screen
  static const int _repetitionFeedbackFreezer = 2500;
  int _feedbackFreezeWaitTimer = 0;

  // whether the app is recording right now or not
  bool _recording = false;
  bool _recorderButtonPressed = false;
  bool _calibrationButtonPressed = false;

  late final SimpleKalman _kalmannX, _KalmanY, _KalmanZ;

  _SpotState(this._openEarable);

  @override
  void initState() {
    super.initState();
    _state = _dataHandler.getCurrentRestState();
    if (_openEarable.bleManager.connected) {
      _setupListener();
    }
  }

  _setupListener() {
    _kalmannX = SimpleKalman(
      errorMeasure: 5.0,
      errorEstimate: 5.0,
      q: 0.9,
    );
    _KalmanY = SimpleKalman(
      errorMeasure: 5.0,
      errorEstimate: 5.0,
      q: 0.9,
    );
    _KalmanZ = SimpleKalman(
      errorMeasure: 5.0,
      errorEstimate: 5.0,
      q: 0.9,
    );
    _imuSubscription =
        _openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
      if (!_recording) {
        return;
      }
      int timeStamp = data["timestamp"];
      double accX = _kalmannX.filtered(data["ACC"]["X"]);
      double accY = _KalmanY.filtered(data["ACC"]["Y"]);
      double accZ = _KalmanZ.filtered(data["ACC"]["Z"]);
      double pitch = data["EULER"]["PITCH"];

      updateData(dataPoint(timeStamp, accX, accY, accZ, pitch));
    });
  }

  void updateData(dataPoint newDataPoint) {
    ModelState newState = _dataHandler.pipeLineData(newDataPoint);

    if (_feedbackFreezeWaitTimer > newDataPoint.timeStamp) {
      // wait until freeze is over
      return;
    }

    if (newState != _state) {
      // on state change rebuild ui
      if (newState == ModelState.BadRepetition ||
          newState == ModelState.GoodRepetition) {
        _feedbackFreezeWaitTimer =
            newDataPoint.timeStamp + _repetitionFeedbackFreezer;
      }
      if (newState == ModelState.Calibrated) {
        _openEarable.audioPlayer.jingle(2);
        // this only gets called once after a successful calibration recording
        _state = ModelState.Calibrated;
        pressCalibrationButton();
        return;
      }
      setState(() {
        _state = newState;
      });
    }
  }

  // called when calibration button is pressed
  void pressCalibrationButton() {
    if (_recorderButtonPressed) {
      // cant press when analysing already
      return;
    }
    if (_recording) {
      setState(() {
        switchDataRecording();
        _calibrationButtonPressed = false;
        _state = _dataHandler.getCurrentRestState();
      });
    } else {
      if (_dataHandler.calibrated) {
        // resets data handler if user wants to recalibrate app
        _dataHandler = DataHandler();
      }
      setState(() {
        _calibrationButtonPressed = true;
        switchDataRecording();
      });
    }
  }

  // called when recorder button is pressed
  void pressRecorderButton() {
    if (_calibrationButtonPressed || !_dataHandler.calibrated) {
      // cant record when its not calibrated or its calibrating right now
      return;
    }
    if (_recording) {
      setState(() {
        switchDataRecording();
        _recorderButtonPressed = false;
        _state = _dataHandler.getCurrentRestState();
      });
    } else {
      setState(() {
        _recorderButtonPressed = true;
        switchDataRecording();
      });
    }
  }

  // switches general data recording and resets datahandler if needed
  void switchDataRecording() {
    if (_recording) {
      _feedbackFreezeWaitTimer = 0;
      _dataHandler.stop();
    }
    _recording = !_recording;
  }

  Color getCalibrationButtonColor() {
    if (_calibrationButtonPressed) {
      return Colors.red;
    }
    return Theme.of(context).primaryColor;
  }

  Color getRecorderButtonColor() {
    if (_recorderButtonPressed) {
      return Colors.red;
    }
    return Theme.of(context).primaryColor;
  }

  IconData getRecorderButtonIcon() {
    if (_recorderButtonPressed) {
      return Icons.radio_button_on;
    }
    return Icons.radio_button_off;
  }

  /// widget to dispay repetition feedback to user is dependent on current value of [_state]
  Widget feedbackWidget(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.97,
        heightFactor: 0.97,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            color: getFeedBackColor(),
          ),
          child: Align(
            alignment: Alignment(0.0, -0.3),
            child: Text(
              (getFeedbackText()),
              style: TextStyle(fontSize: 32),
            ),
          ),
        ),
      ),
    );
  }

  Color getFeedBackColor() {
    switch (_state) {
      case ModelState.NotCalibrated:
        return Theme.of(context).colorScheme.primary;
      case ModelState.Calibrated:
        return Theme.of(context).colorScheme.primary;
      case ModelState.WaitForStart:
        return Theme.of(context).colorScheme.primary;
      case ModelState.Analysing:
        _openEarable.audioPlayer.jingle(4);
        return Theme.of(context).colorScheme.primary;
      case ModelState.GoodRepetition:
        _openEarable.audioPlayer.jingle(2);
        return Colors.green;
      case ModelState.BadRepetition:
        _openEarable.audioPlayer.jingle(3);
        return Colors.red;
    }
  }

  String getFeedbackText() {
    switch (_state) {
      case ModelState.NotCalibrated:
        return "Calibrate your Deadlift";
      case ModelState.Calibrated:
        return "Ready to Analyse";
      case ModelState.WaitForStart:
        return "Get in Position";
      case ModelState.Analysing:
        return "Analysing";
      case ModelState.GoodRepetition:
        return "Nice Repetition";
      case ModelState.BadRepetition:
        return "Bad Repetition";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text('Deadlift Spotter'),
      ),
      body: _openEarable.bleManager.connected
          ? feedbackWidget(context)
          : EarableNotConnectedWarning(),
      // Circular menu for easy one handed navigation
      floatingActionButton: CircularMenu(
        alignment: Alignment.bottomRight,
        items: [
          // Menu item for how to deadlift route
          CircularMenuItem(
            icon: Icons.lightbulb,
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => HowToDeadLift()));
            },
          ),
          // Menu item for dead lift analysis
          CircularMenuItem(
            icon: getRecorderButtonIcon(),
            color: getRecorderButtonColor(),
            onTap: () {
              setState(
                () {
                  pressRecorderButton();
                },
              );
            },
          ),
          // Menu item for calibration process
          CircularMenuItem(
            color: getCalibrationButtonColor(),
            icon: Icons.videocam,
            onTap: () {
              if (_calibrationButtonPressed) {
                // Dialog so calibration does not stop on accident
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) => AlertDialog(
                    title: Text("Stop Calibration ?"),
                    content: Text(
                        "By clicking Yes, you stop the calibration process. Click no to continue calibrating."),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          pressCalibrationButton();
                        },
                        child: Text("Yes"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("No"),
                      )
                    ],
                  ),
                );
              } else {
                if (_dataHandler.calibrated && !_recording) {
                  // Dialog so calibration does not get deleted accidentally
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => AlertDialog(
                      title: Text("Reset Calibration ?"),
                      content: Text(
                          "By clicking Yes, you reset your previous calibration and start a new one. Click No to continue with your current calibration."),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            pressCalibrationButton();
                          },
                          child: Text("Yes"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("No"),
                        )
                      ],
                    ),
                  );
                } else {
                  // make calibration if device was not calibrated before
                  pressCalibrationButton();
                }
              }
            },
          ),
          // Menu item for how to use the app route
          CircularMenuItem(
            icon: Icons.question_mark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (contex) => HowToUse()),
              );
            },
          ),
        ],
      ),
    );
  }
}
