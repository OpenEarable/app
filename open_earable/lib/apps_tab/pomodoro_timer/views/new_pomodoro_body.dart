import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/exercises.dart/stand_up_exercise.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/model/pomodoro_config.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/views/pomodoro_config_showcase.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/views/pomodoro_app_settings.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/widgets/pomodoro_configurator.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/widgets/timer_clock.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

import '../exercises.dart/nod_exercise.dart';
import '../widgets/assignment_text.dart';

/// The app body for the Pomodoro Timer app.
/// This widget contains the main logic for the Pomodoro Timer app.
/// It contains the timer logic and the logic for the different states of the app.
class PomodoroAppBody extends StatefulWidget {
  final OpenEarable openEarable;
  final PomodoroAppSettings pomodoroAppSettings;

  const PomodoroAppBody(this.openEarable, this.pomodoroAppSettings,{super.key});

  @override
  State<PomodoroAppBody> createState() => _PomodoroAppBodyState();
}

enum PomodoroState {
  workState,
  breakState,
  configurationState,
  pendingBreakState,
  pendingWorkState
}

class _PomodoroAppBodyState extends State<PomodoroAppBody> {
  PomodoroConfig pomodoroConfig = PomodoroConfig();
  bool isRunning = false;

  PomodoroState _pomodoroState = PomodoroState.configurationState;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> startTimer() async {
    _pomodoroState = PomodoroState.workState;
    print("start timer");
  }

  /// This method changes the state to WORKING
  void workTimerFinished() {
    widget.openEarable.audioPlayer.jingle(1);
    setState(() {
      if (pomodoroConfig.repetitions > 0) {
        print("work finished");
        _pomodoroState = PomodoroState.pendingBreakState;
      } else {
        _pomodoroState = PomodoroState.configurationState;
      }
    });
  }

  /// Runs the timer
  void runTimer() {
    print("run timer");
    setState(() {
      _pomodoroState = PomodoroState.workState;
    });
  }

  /// This method plays a sound and changes the state to PENDING_WORK
  void breakTimerFinished() {
    print("break finished");
    widget.openEarable.audioPlayer.jingle(3);
    setState(() {
      _pomodoroState = PomodoroState.pendingWorkState;
      pomodoroConfig.repetitions--;
    });
  }

  /// This method returns a random exercise
  /// with an exerciseFinished callback that changes the state to nextState
  Widget getRandomExercise(PomodoroState nextState) {
    print("NEXTSTATE: ${nextState.toString()}");
    void exerciseFinished() {
      setState(() {
        _pomodoroState = nextState;
      });
    }
    List<Widget> exercises = [
      StandUpExercise(widget.openEarable, exerciseFinished),
      NodExercise(widget.openEarable, widget.pomodoroAppSettings, exerciseFinished),
    ];
    return exercises[Random().nextInt(exercises.length)];
  }

  /// This method returns the TimerClock widget based on the current state
  /// if the state is WORKING it returns a TimerClock with the workMinutes
  /// if the state is BREAK it returns a TimerClock with the breakMinutes
  /// if the state is CONFIGURATION it returns a PomodoroConfigurator
  /// if the state is PENDING_BREAK or PENDING_WORK it returns a random exercise
  Widget getTimerClock() {
    switch (_pomodoroState) {
      case PomodoroState.workState:
        print("working");
        return Column(
          children: [
            AssignmentText("Work ✍️"),
            TimerClock(pomodoroConfig.workMinutes, workTimerFinished),
          ],
        );
      case PomodoroState.breakState:
        print("break");
        return Column(
          children: [
            AssignmentText("Break ☕ ᝰ.ᐟ"),
            TimerClock(pomodoroConfig.breakMinutes, breakTimerFinished),
          ],
        );
      case PomodoroState.pendingBreakState:
        return getRandomExercise(PomodoroState.breakState);

      case PomodoroState.pendingWorkState:
        return getRandomExercise(PomodoroState.workState);
      default:
        return Column(
          children: [
            PomodoroConfigurator(pomodoroConfig),
            SizedBox(height: 20,),
            Padding(
              padding: const EdgeInsets.all(5.0),
              child: FilledButton(
                onPressed: runTimer,
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all<Color>(Colors.green),
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                  padding: WidgetStateProperty.all<EdgeInsets>(
                    EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
                  ),
                ),
                child: Text(
                  "Start Timer",
                  style: TextStyle(fontSize: 20), // Increase the font size
                ),
              ),
            ),
          ],
        );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PomodoroConfigShowcase(pomodoroConfig),
        getTimerClock(),
      ],
    );
  }


  /// this method is for Test purposes only and can be used to get a
  /// navigation button for the Exercises
  ElevatedButton getNavigatorButton(Widget widget) {
    return ElevatedButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => Scaffold(appBar: AppBar(), body: widget),
          ),);
        },
        child: Text("navigate to ${widget.toString()}"),);
  }
}
