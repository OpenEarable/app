import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:open_earable/apps_tab/hamster_hurdle/hamster_hurdles_world.dart';


///Class representing an obstacle in the game.
class Obstacle extends PositionComponent
    with HasWorldReference<HamsterHurdleWorld> {

  ///The image rendered to visually represent the obstacle.
  late Sprite _obstacleSprite;

  ///The type of the obstacle.
  final ObstacleType obstacleType;

  ///The initial x position that the obstacle is placed on on the screen.
  final double initialXPosition;

  ///The speed at which the obstacles move along the x-axis.
  final double gameSpeed;

  Obstacle(
      {required this.gameSpeed,
      required this.initialXPosition,
      required this.obstacleType,})
      : super(priority: 2);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    double height;
    String imageSource;
    switch (obstacleType) {
      case ObstacleType.root:
        imageSource = "root_obstacle.png";
        anchor = Anchor.topLeft;
        height = world.rootHeight;
        position.y = world.groundLevel - world.tunnelHeight;
        add(RectangleHitbox()..collisionType = CollisionType.passive);
        break;
      case ObstacleType.nuts:
        imageSource = "nut_obstacle.png";
        anchor = Anchor.bottomLeft;
        height = world.nutHeight;
        position.y = world.groundLevel;
        add(CircleHitbox()..collisionType = CollisionType.passive);
        break;
    }
    position.x = initialXPosition;
    _obstacleSprite = await Sprite.load(imageSource);
    final ratio = _obstacleSprite.srcSize.x / _obstacleSprite.srcSize.y;
    size = Vector2(height * ratio, height);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _obstacleSprite.render(
      canvas,
      size: size,
    );
  }

  ///Moves the obstacles along the x-axis according to gameSpeed.
  @override
  void update(double dt) {
    super.update(dt);
    position.x -= dt * gameSpeed;
  }
}

///Encapsulates the types an obstacle can be.
enum ObstacleType {
  root,
  nuts,
}
