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
  late double _gameSpeed;
  double get gameSpeed => _gameSpeed;
  final double hamsterPosition = 0;
  late double tunnelHeight;
  late double rootHeight;
  late double nutHeight;
  late Obstacle _lastObstacle;
  late HurdleBackground _background;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    startGame();
  }

  void stopGame() {
    _gameSpeed = 0;
    _removeAllObstacles();
  }

  void startGame() {
    //removes all instances from previous game.
    removeAll(children.whereType<Obstacle>());
    removeAll(children.whereType<Hamster>());
    removeAll(children.whereType<HurdleBackground>());

    _gameSpeed = 270;
    tunnelHeight = size.y / 4;
    rootHeight = tunnelHeight*0.7;
    nutHeight = tunnelHeight*0.3;
    add(hamster = Hamster(
        size: Vector2(size.y / 9, size.y / 9), xPosition: hamsterPosition));
    add(HamsterTunnel(tunnelHeight: tunnelHeight));
    add(_background = HurdleBackground());
    //generate the first random obstacle
    add(_lastObstacle = Obstacle(
        gameSpeed: _gameSpeed,
        initialXPosition: size.x,
        obstacleType: _randomizeObstacleType()));
  }



  void _generateObstacle() {
    double maximumDistanceBetweenObstacles = hamster.size.x * 9;
    double randomizedXPosition =
        (Random().nextDouble() * maximumDistanceBetweenObstacles) + size.x;
    add(_lastObstacle = Obstacle(
        obstacleType: _randomizeObstacleType(),
        initialXPosition: randomizedXPosition,
        gameSpeed: _gameSpeed));
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

  void _removeAllObstacles() {
    removeAll(children.whereType<Obstacle>());
  }

  @override
  void update(double dt) {
    super.update(dt);
    //only generate new obstacles when game is being played.
    if(game.playState == PlayState.playing) {
      double minDistanceBetweenObstacles =
          _lastObstacle.size.x + hamster.size.x * 5;
      if (_lastObstacle.x <= game.size.x - minDistanceBetweenObstacles) {
        _generateObstacle();
      }
      _removeObstacles();
      game.camera.viewfinder.zoom = 1.0;
    }
    _background.parallax?.baseVelocity = Vector2(gameSpeed, 0);
  }



}


