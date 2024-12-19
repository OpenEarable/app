import 'package:flutter/cupertino.dart';

import 'hamster_hurdles_game.dart';

class ActiveGameOverlay extends StatelessWidget {
  const ActiveGameOverlay({super.key, required this.gameScore});

  final Widget gameScore;

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    return Column(
      children: [
        SizedBox(height: screenHeight / 9),
        Center(child: gameScore),
      ],
    );
  }
}


class GameOverOverlay extends StatelessWidget {
  final int finalScore;

  const GameOverOverlay({
    required this.finalScore,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    return Column(children: [
      Container(
        height: screenHeight / 2,
        alignment: const Alignment(0, -0.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameText(text: "Game Over", fontSize: 48,),
            const SizedBox(height: 16),
            GameText(text: "Tap to play again", fontSize: 36,),
          ],
        ),
      ),
      Container(
        alignment: const Alignment(0, 0.5),
        height: screenHeight / 2,
        child: GameText(text: "Final Score: $finalScore", fontSize: 36,),
      )
    ]);
  }
}