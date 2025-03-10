import 'package:flutter/material.dart';

/// A stateless widget that represents the game over screen.
///
/// This screen displays a "Game Over!" message and a restart button.
/// When the restart button is pressed, the provided [onRestartPressed] callback is called.
///
class GameOverScreen extends StatelessWidget {
  final VoidCallback onRestartPressed;

  const GameOverScreen({super.key, required this.onRestartPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'lib/apps_tab/doodle_jump/assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Game Over!',
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: onRestartPressed,
                    child: const Text('Restart'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
