import 'package:flutter/cupertino.dart';

import 'hamster_hurdles_game.dart';

///A Widget representing what is being shown when the player loses.
class GameOverOverlay extends StatelessWidget {

  ///The final score achieved by the player during the game.
  final int finalScore;

  const GameOverOverlay({
    required this.finalScore,
    super.key,
  });


  /// A widget that displays a "Game Over" screen with the final score
  /// and a prompt to play again.
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