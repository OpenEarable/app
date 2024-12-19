import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:open_earable/apps_tab/hamster_hurdle/hamster_hurdles_game.dart';

class GameScore extends StatefulWidget {
  final ValueNotifier<int> scoreNotifier;

  const GameScore({super.key, required this.scoreNotifier});

  @override
  State<StatefulWidget> createState() => _GameScoreState();
}

class _GameScoreState extends State<GameScore> {
  late Timer _timer;

  ///the time that the current game has been played.
  int _timePlayed = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  ///
  void _startTimer() {
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      setState(() {
        _timePlayed++;
        widget.scoreNotifier.value = _calculateScore();
      });
    });
  }

  int _calculateScore() {
    int score = pow(_timePlayed, 1.15).floor();
    return score;
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
    int score = _calculateScore();
    return Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
        child: GameText(text: "Score: $score", fontSize: 36,),);
  }
}
