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
  ///the hamster that is the player in this game.
  late Hamster hamster;

  ///The current size of the game.
  Vector2 get size => game.size;

  ///the level at which the ground should appear in game.
  late final double groundLevel = 3 * size.y / 15;

  ///The speed at which obstacles and the parallax pass through the screen.
  late double _gameSpeed;

  double get gameSpeed => _gameSpeed;

  ///The initial position of the hamster at loading.
  final double hamsterPosition = 0;

  ///The height of the hamster tunnel.
  late double tunnelHeight;

  ///The height of a root obstacle.
  late double rootHeight;

  ///The height of a nut obstacle.
  late double nutHeight;

  ///The latest generated obstacle.
  late Obstacle _lastObstacle;

  ///The background of the game.
  late HurdleBackground _background;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    startGame();
  }

  ///Stops the speed of the game and removes all obstacles from the world.
  void stopGame() {
    _gameSpeed = 0;
    removeAll(children.whereType<Obstacle>());
  }

  ///Starts the game by removing all instances from previous games and adding
  ///the hamster, hamster tunnel, background and obstacles to the game world.
  void startGame() {
    //removes all instances from previous game.
    removeAll(children.whereType<Obstacle>());
    removeAll(children.whereType<Hamster>());
    removeAll(children.whereType<HurdleBackground>());

    _gameSpeed = 270;
    tunnelHeight = size.y / 4;
    rootHeight = tunnelHeight * 0.7;
    nutHeight = tunnelHeight * 0.3;
    add(hamster = Hamster(
        size: Vector2(size.y / 9, size.y / 9),
        initialXPosition: hamsterPosition));
    add(HamsterTunnel(tunnelHeight: tunnelHeight));
    add(_background = HurdleBackground());
    //generate the first random obstacle
    add(_lastObstacle = Obstacle(
        gameSpeed: _gameSpeed,
        initialXPosition: size.x,
        obstacleType: _randomizeObstacleType()));
  }

  ///Generates obstacles at random intervals.
  void _generateObstacle() {
    double maximumDistanceBetweenObstacles = hamster.size.x * 9;
    double randomizedXPosition =
        (Random().nextDouble() * maximumDistanceBetweenObstacles) + size.x;
    add(_lastObstacle = Obstacle(
        obstacleType: _randomizeObstacleType(),
        initialXPosition: randomizedXPosition,
        gameSpeed: _gameSpeed));
  }

  ///Randomly  puts out an obstacle type used to randomly generate obstacles in
  ///game.
  ObstacleType _randomizeObstacleType() {
    Random rand = Random();
    int randomNumber = rand.nextInt(ObstacleType.values.length);
    return ObstacleType.values[randomNumber];
  }

  ///Removes obstacles when they are no longer seen on screen.
  void _removeObstacles() {
    final obstacles = children.whereType<Obstacle>();
    for (var obstacle in obstacles) {
      if (obstacle.position.x < -size.x / 2 - obstacle.size.x) {
        obstacle.removeFromParent();
      }
    }
  }

  ///generates and removes Obstacles if game is being played and updates the
  ///speed at which the background parallax moves.
  @override
  void update(double dt) {
    super.update(dt);
    //only generate new obstacles when game is being played.
    if (game.playState == PlayState.playing) {
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
