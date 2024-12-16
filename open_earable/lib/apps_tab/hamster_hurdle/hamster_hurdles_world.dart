import 'dart:math';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:open_earable/apps_tab/hamster_hurdle/components/background_parallax.dart';
import 'package:open_earable/apps_tab/hamster_hurdle/components/obstacle.dart';

import 'components/hamster.dart';
import 'components/hamster_tunnel.dart';
import 'hamster_hurdles_game.dart';

class HamsterHurdleWorld extends World
    with HasGameReference<HamsterHurdle>, TapCallbacks {
  late Hamster hamster;

  Vector2 get size => game.size;
  late final double groundLevel = 3 * size.y / 15;
  final double gameSpeed = 250;
  final double hamsterPosition = 0;
  late double tunnelHeight;
  late Obstacle _lastObstacle;
  late double screenWidth;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    tunnelHeight = size.y / 4;
    screenWidth = size.x;
    add(hamster = Hamster(
        size: Vector2(size.y / 8, size.y / 8), xPosition: hamsterPosition));
    add(HamsterTunnel(tunnelHeight: size.y / 4));
    add(HurdleBackground(speed: gameSpeed));
    add(_lastObstacle = Obstacle(
        gameSpeed: gameSpeed,
        initialXPosition: screenWidth,
        obstacleType: _randomizeObstacleType()));
    debugMode = true;
  }

  void _generateObstacle() {
    double maximumDistanceBetweenObstacles = hamster.size.x * 3;
    double randomizedXPosition =
        (Random().nextDouble() * maximumDistanceBetweenObstacles) + screenWidth;
    add(_lastObstacle = Obstacle(
        obstacleType: _randomizeObstacleType(),
        initialXPosition: randomizedXPosition,
        gameSpeed: gameSpeed));
  }

  ObstacleType _randomizeObstacleType() {
    Random rand = Random();
    int randomNumber = rand.nextInt(ObstacleType.values.length);
    return ObstacleType.values[randomNumber];
  }

  void onDuckingMotion() {
    hamster.duck();
  }

  void _removeObstacles() {
    final obstacles = children.whereType<Obstacle>();
    for (var obstacle in obstacles) {
      if (obstacle.position.x < -size.x / 2 - obstacle.size.x) {
        obstacle.removeFromParent();
      }
    }
  }

  @override
  void update(double dt) {
    double minDistanceBetweenObstacles =
        _lastObstacle.size.x + hamster.size.x * 1.5;
    super.update(dt);
    if (_lastObstacle.x <= screenWidth - minDistanceBetweenObstacles) {
      _generateObstacle();
      print(children.whereType<Obstacle>().length);
    }
    _removeObstacles();
    game.camera.viewfinder.zoom = 1.0;
  }

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    screenWidth = canvasSize.x;
  }
}
