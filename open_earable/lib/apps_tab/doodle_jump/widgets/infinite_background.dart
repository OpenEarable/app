import 'package:flutter/material.dart';

/// A widget that creates an infinite scrolling background effect.
///
/// The [InfiniteBackground] widget takes a [playerPosition] parameter which
/// determines the vertical position of the player. The background image
/// scrolls infinitely based on the player's position.
///
/// The widget uses a [Stack] to position two instances of the background
/// image, one above the screen and one within the screen. As the player
/// moves, the backgrounds are repositioned to create the illusion of
/// continuous scrolling.
class InfiniteBackground extends StatelessWidget {
  final double playerPosition;

  const InfiniteBackground({super.key, required this.playerPosition});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final offset = playerPosition % screenHeight;

    return Stack(
      children: [
        Positioned(
          top: -screenHeight + offset,
          child: _buildBackground(context),
        ),
        Positioned(
          top: offset,
          child: _buildBackground(context),
        ),
      ],
    );
  }

  Widget _buildBackground(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('lib/apps_tab/doodle_jump/assets/background.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
