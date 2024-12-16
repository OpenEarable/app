import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:open_earable/apps_tab/hamster_hurdle/hamster_hurdles_world.dart';

class Obstacle extends PositionComponent
    with HasWorldReference<HamsterHurdleWorld> {
  late Sprite _obstacleSprite;
  final ObstacleType obstacleType;

  Obstacle({required this.obstacleType, required super.position})
      : super(priority: 2);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    double height;
    String imageSource;
    switch (obstacleType) {
      case ObstacleType.root:
        imageSource = "root_obstacle.png";
        anchor = Anchor.topCenter;
        height = world.tunnelHeight*0.7;
        break;
      case ObstacleType.nuts:
        imageSource = "nut_obstacle.png";
        anchor = Anchor.bottomCenter;
        height = world.tunnelHeight*0.3;
        break;
    }
    _obstacleSprite = await Sprite.load(imageSource);
    final ratio = _obstacleSprite.srcSize.x / _obstacleSprite.srcSize.y;
    size = Vector2(height * ratio, height);
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _obstacleSprite.render(
      canvas,
      size: size,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x -= dt* 100;
  }

}

enum ObstacleType {
  root,
  nuts,
}
