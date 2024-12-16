import 'dart:math';

import 'package:flame/camera.dart';
import 'package:flame/collisions.dart';
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
  late double tunnelHeight;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    tunnelHeight = size.y / 4;
    add(hamster = Hamster(size: Vector2(size.y / 8, size.y / 8)));
    add(HamsterTunnel(tunnelHeight: size.y / 4));
    add(HurdleBackground(speed: 100));
    add(Obstacle(
        obstacleType: ObstacleType.root,
        position: Vector2(size.x / 4, groundLevel - tunnelHeight)));
    debugMode = true;
  }

  void onEnterDown() {
    hamster.duck();
  }
}
