import 'dart:async';

import 'package:flutter/cupertino.dart';

class GameTimer extends StatefulWidget {
  final ValueNotifier<String> timeNotifier;
  const GameTimer({super.key, required this.timeNotifier});

  @override
  State<StatefulWidget> createState() => _GameTimerState();
}

class _GameTimerState extends State<GameTimer> {
  late Timer _timer;
  ///the time that the current game has been played.
  int _secondsPlayed = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  ///
  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _secondsPlayed++;
        widget.timeNotifier.value = _formatTime();
      });
    });
  }

  String _formatTime() {
    final minutes = (_secondsPlayed ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsPlayed % 60).toString().padLeft(2, '0');
    if(_secondsPlayed >= 59) {
      return "${minutes}m :${seconds}s";
    }
    else {
      return "${seconds}s";
    }
  }

  void stopTimer() {
    _timer.cancel();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    String formattedTime = _formatTime();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
      child: Text("Time: $formattedTime",
        style: TextStyle(fontFamily: 'HamsterHurdleFont', fontSize: 36),
      ),
    );
  }
}
