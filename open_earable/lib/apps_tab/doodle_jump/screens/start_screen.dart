import 'package:flutter/material.dart';

/// A stateless widget that represents the start screen of the Doodle Jump game.
///
/// This widget displays a background image, a start button, and optionally a
/// connection error message if the `showConnectionError` flag is set to true.
///
/// The `onStartPressed` callback is triggered when the start button is pressed.

class StartScreen extends StatelessWidget {
  final VoidCallback onStartPressed;
  final bool showConnectionError;

  const StartScreen(
      {super.key,
      required this.showConnectionError,
      required this.onStartPressed});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
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
                        'Press Start to begin the game!',
                        style: TextStyle(fontSize: 24, color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: onStartPressed,
                        child: const Text('Start'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (showConnectionError)
          Positioned(top: 0, left: 0, right: 0, child: _buildConnectionError()),
      ],
    );
  }

  /// Builds a connection error message.
  Widget _buildConnectionError() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.red,
      child: const Text(
        'OpenEarable device not connected.',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
