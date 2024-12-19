import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:open_earable/apps_tab/hamster_hurdle/hamster_hurdles_game.dart';

class GameScore extends StatefulWidget {

  ///Notifies its listeners when the score of the game changes.
  final ValueNotifier<int> scoreNotifier;

  const GameScore({super.key, required this.scoreNotifier});

  @override
  State<StatefulWidget> createState() => _GameScoreState();
}

class _GameScoreState extends State<GameScore> {
  late Timer _timer;

  ///The time that the current game has been played.
  int _timePlayed = 0;

  ///Starts timer.
  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  ///Sets the timer to repeat periodically each 100ms and updates the score
  ///according to the time played.
  void _startTimer() {
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      setState(() {
        _timePlayed++;
        widget.scoreNotifier.value = _calculateScore();
      });
    });
  }

  ///Calculates the score of the game using the timePlayed. The longer the playing
  ///time the faster the score is increased.
  int _calculateScore() {
    int score = pow(_timePlayed, 1.15).floor();
    return score;
  }

  ///Stops the timer.
  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  ///Builds a widget that renders the current score as a Text with the custom
  ///font for Hamster Hurdles, and positions the texts on the screen relative to
  ///the current screen height.
  @override
  Widget build(BuildContext context) {
    int score = _calculateScore();

      double screenHeight = MediaQuery.of(context).size.height;
      return Column(
        children: [
          SizedBox(height: screenHeight / 9),
          Center(child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
            child: GameText(text: "Score: $score", fontSize: 36,),)),
        ],
      );
    }
}
