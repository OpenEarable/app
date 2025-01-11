import 'package:flutter/widgets.dart';
import 'package:open_earable/apps_tab/doodle_jump/models/platform.dart';

/// Represents the player in the Doodle Jump game.
///
/// This class handles the player's position, velocity, and movement,
/// as well as interactions with platforms and the game environment.
class Doodle {
  /// The vertical position of the player.
  double position = 0.0;

  /// The vertical velocity of the player.
  double velocity = 0.0;

  /// The horizontal position of the player.
  double horizontalPosition = 180.0;

  /// The width of the player.
  double width = 30.0;

  /// The height of the player.
  double height = 50.0;

  /// The gravitational force applied to the player.
  final double gravity = -20;

  /// The strength of the player's jump.
  final double jumpStrength = 70.0;

  /// The time slice for each update cycle.
  final double timeSlice = 1 / 30.0;

  /// The horizontal speed of the player.
  final double horizontalSpeed = 5;

  /// Indicates whether the player has not hit any platform.
  bool noPlatformHit = true;

  /// Indicates whether the player is active in the game.
  bool playerActive = true;

  /// Makes the player jump by setting the vertical velocity to the jump strength.
  void jump() {
    velocity = jumpStrength;
  }

  /// Updates the player's position and velocity based on gravity and time slice.
  ///
  /// If the player reaches the bottom of the screen and no platform is hit,
  /// the player will jump again. If a platform is hit, the player becomes inactive.
  void update(BuildContext context) {
    velocity += gravity * timeSlice;
    position += velocity * timeSlice;

    if (position <= 0 && noPlatformHit) {
      position = 0;
      jump();
    } else if (position <= 0 && !noPlatformHit) {
      playerActive = false;
    }

    horizontalPosition %= MediaQuery.of(context).size.width;

    /*
    if (horizontalPosition < 0) {
      horizontalPosition = MediaQuery.of(context).size.width;
    } else if (horizontalPosition > MediaQuery.of(context).size.width) {
      horizontalPosition = 0;
    }
    */
  }

  /// Moves the player to the left by decreasing the horizontal position.
  void moveLeft() {
    horizontalPosition -= horizontalSpeed;
  }

  /// Moves the player to the right by increasing the horizontal position.
  void moveRight() {
    horizontalPosition += horizontalSpeed;
  }

  /// Checks for collisions with platforms and makes the player jump if a collision is detected.
  ///
  /// The player's position and dimensions are compared with each platform's position and dimensions.
  /// If a collision is detected, the player jumps and the `noPlatformHit` flag is set to false.
  void checkPlatformCollisions(List<Platform> platforms) {
    for (var platform in platforms) {
      if (horizontalPosition + width >= platform.x &&
          horizontalPosition + width <= platform.x + platform.width &&
          position >= platform.y &&
          position <= platform.y + platform.height) {
        jump();
        noPlatformHit = false;
      }
    }
  }
}
