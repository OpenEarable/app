
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/cupertino.dart';


import '../hamster_hurdles_game.dart';
import '../hamster_hurdles_world.dart';

class HamsterTunnel extends RectangleComponent
    with HasWorldReference<HamsterHurdleWorld>, HasGameRef<HamsterHurdle> {
  HamsterTunnel({
    required this.tunnelHeight,
  }) : super(
            paint: Paint()
              ..color = const Color(0xffad784c)
              ..style = PaintingStyle.fill,
            priority: 1,
            anchor: Anchor.bottomCenter);


  final double tunnelHeight;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    position.y = world.groundLevel;
    size = Vector2(game.size.x, tunnelHeight);
  }
  @override
  void render(Canvas canvas) {
    super.render(canvas);
  }
    @override
  void update(double dt) {
    size = Vector2(game.size.x, tunnelHeight);
    super.update(dt);
  }
}
