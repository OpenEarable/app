import 'package:flame/components.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/cupertino.dart';
import 'package:open_earable/apps_tab/hamster_hurdle/hamster_hurdles_game.dart';

class HurdleBackground extends ParallaxComponent<HamsterHurdle> {
  final double speed;
  HurdleBackground({required this.speed});

  @override
  Future<void> onLoad() async {
    anchor = Anchor.center;
    parallax = await game.loadParallax(
      [
        ParallaxImageData('background_soil.png'),
      ],
      baseVelocity: Vector2(speed, 0),
      repeat: ImageRepeat.repeatX,
    );
  }
}
