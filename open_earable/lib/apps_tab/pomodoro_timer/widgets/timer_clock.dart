import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/model/timer_configuration.dart';

class TimerClock extends StatefulWidget {
  final int minutes;
  final Function timerFinished;
  const TimerClock(this.minutes, this.timerFinished, {super.key});

  @override
  State<TimerClock> createState() => _TimerClockState();
}

class _TimerClockState extends State<TimerClock> {
  late TimerConfiguration _timerConfiguration;

  late Timer _timer;
  late Stopwatch _stopwatch;
  int _secondsPassed = 0;

  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _timerConfiguration = TimerConfiguration(0, widget.minutes)..run();
    _stopwatch = Stopwatch()..start();

    print("widgetminutes: ${widget.minutes}");

    _timer = Timer.periodic(
      Duration(milliseconds: 30),
      (_) => setState(() {
        if (_timerConfiguration.isRunning) {
          int elapsed = _stopwatch.elapsed.inSeconds;
          if (elapsed > _secondsPassed) {
            _secondsPassed++;
            if (_timerConfiguration.allSecondsLeft > 0) {
              print("decreasing seconds");
              _timerConfiguration.decreaseSeconds(1);
            } else {
              _timerConfiguration.stop();
              widget.timerFinished();
            }
          }
        } else {
          _stopwatch.stop();
          _stopwatch.reset();
          _secondsPassed = 0;
          widget.timerFinished();
          _timerConfiguration.stop();
        }
      }),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
    _stopwatch.stop();
    _stopwatch.reset();
  }

  /// Returns a round text box with the given text.
  Widget roundTextBox(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(width: 0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(text, style: TextStyle(fontSize: 80)),
        ),
      ),
    );
  }

  /// Returns a string representation of a number with two digits.
  String getDoubleDigitString(int number) {
    if (number < 10) {
      return "0$number";
    } else {
      return number.toString();
    }
  }

  /// Pauses or continues the timer depending on the current state.
  void _pause() {
    if (_paused) {
      _stopwatch.start();
    } else {
      _stopwatch.stop();
    }
    _paused = !_paused;
  }

  /// Returns a pause button with the text "Pause" or "Continue"
  /// depending on the current state.
  Widget getPauseButton() {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: SizedBox(
        width: 120, // Set a fixed width for the button
        child: FilledButton(
          onPressed: _pause,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all<Color>(
                _paused ? Colors.green : Colors.red),
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
            _paused ? "Continue" : " Pause ",
            style: TextStyle(fontSize: 20), // Increase the font size
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Flex(
        direction: Axis.vertical,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(60),
                border: Border.all(width: 1),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        roundTextBox(
                            getDoubleDigitString(_timerConfiguration.minutes)),
                        roundTextBox(':'),
                        roundTextBox(
                            getDoubleDigitString(_timerConfiguration.seconds)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10),
          getPauseButton(),
        ],
      ),
    );
  }
}
