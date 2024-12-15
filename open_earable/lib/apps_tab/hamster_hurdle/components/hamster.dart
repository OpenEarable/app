import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../hamster_hurdles_game.dart';
import '../hamster_hurdles_world.dart';

class Hamster extends PositionComponent
    with
        HasGameRef<HamsterHurdle>,
        HasWorldReference<HamsterHurdleWorld>,
        CollisionCallbacks {
  Hamster({required super.size})
      : super(
          anchor: Anchor.bottomCenter,
          priority: 3,
        );

  late Sprite _hamsterSprite;
  double _velocity = 0;
  final double _gravity = 30;
  final double _jumpForce = -14;
  late double _maxJumpHeight;
  late double ground;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _hamsterSprite = await Sprite.load("hamster.png");
    add(RectangleHitbox()..collisionType = CollisionType.active);
    position.y = world.groundLevel;
    _maxJumpHeight = world.size.y / 2.5 - size.y;
  }

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

  void duck() {
    size = Vector2(size.x, 80.0);
  }

  void getUp() {
    size = Vector2(size.x, 160.0);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is ScreenHitbox) {}
    super.onCollision(intersectionPoints, other);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _velocity += _gravity * dt;
    position.y += _velocity;
    bool belowGround = position.y > world.groundLevel;
    if (belowGround) {
      position.y = world.groundLevel;
      _velocity = 0;
    }
    if (position.y < world.groundLevel - _maxJumpHeight) {
      position.y = world.groundLevel - _maxJumpHeight;
      _velocity = 0; // Stop upward velocity when max height is reached
    }
  }

  bool isTouchingGround() {
    return position.y >= world.groundLevel;
  }
}
