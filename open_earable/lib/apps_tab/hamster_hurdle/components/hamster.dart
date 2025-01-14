import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:open_earable/apps_tab/hamster_hurdle/components/obstacle.dart';

import '../hamster_hurdles_game.dart';
import '../hamster_hurdles_world.dart';

///The player in the game.
class Hamster extends PositionComponent
    with
        HasGameRef<HamsterHurdle>,
        HasWorldReference<HamsterHurdleWorld>,
        CollisionCallbacks {
  Hamster({required this.initialXPosition, required super.size})
      : super(
          anchor: Anchor.bottomCenter,
          priority: 3,
        );

  ///The x-coordinate the hamster appears on on the screen after loading the game.
  final double initialXPosition;

  ///gravity used to calculate falling movement for jump.
  final double _gravity = 2.3;

  ///the upwards movement used to calculate velocity during jump.
  final double _jumpForce = -15;

  ///The maximum height the hamster can jump.
  late double _maxJumpHeight;

  ///the size the hamster has at loading the game.
  late double initialSize;

  ///The Sprite of the hamster used to render the character.
  late Sprite _hamsterSprite;

  ///Used for calculating the jump movement.
  double _velocity = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _hamsterSprite = await Sprite.load("hamster.png");
    add(CircleHitbox(
        radius: size.y * 0.35,
        anchor: Anchor.center,
        position: Vector2(position.x + size.x / 2, position.y + size.y / 2),)
      ..collisionType = CollisionType.active,);
    position.y = world.groundLevel;
    position.x = initialXPosition;
    _maxJumpHeight = world.tunnelHeight - size.y;
    initialSize = size.y;
  }

  ///Updates velocity to match a jump movement and updates the posture of
  ///the hamster, if hamster was previously ducking.
  void jump(GameAction lastAction) {
    if (lastAction == GameAction.ducking) {
      getUp();
    }
    _velocity = _jumpForce;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _hamsterSprite.render(
      canvas,
      size: size,
    );
  }

  ///Updates the vertical size of the hamster to show a ducking motion.
  void duck() {
    size = Vector2(size.x, initialSize / 2);
  }

  ///Sets the vertical size of the hamster back to the initial size.
  void getUp() {
    size = Vector2(size.x, initialSize);
  }

  ///checks if the hamster is currently touching the ground.
  bool isTouchingGround() {
    return position.y >= world.groundLevel;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Obstacle) {
      game.playState = PlayState.gameOver;
      world.stopGame();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_velocity < 0 &&
        position.y > world.groundLevel - world.tunnelHeight * 0.3) {
      _velocity += (_gravity * 0.7) * dt; // Reduced gravity when rising and
      // hamster position in y direction is lower than height of ground obstacles.
      // This is for a good playing experience, the player rises relatively
      // quickly over the obstacle but then stays in the air long enough to get
      // over the obstacle
    } else {
      _velocity += _gravity * dt;
    }
    position.y += _velocity;
    bool belowGround = position.y > world.groundLevel;
    if (belowGround) {
      position.y = world.groundLevel;
      _velocity = 0;
    }
    //Prevents hamster from jumping outside the tunnel
    if (position.y < world.groundLevel - _maxJumpHeight) {
      position.y = world.groundLevel - _maxJumpHeight;
      _velocity = 0; // Stop upward velocity when max height is reached
    }
  }
}
