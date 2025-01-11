import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/doodle_jump/widgets/top_bar.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import '../models/doodle.dart';
import '../models/platform.dart';
import '../widgets/infinite_background.dart';

/// A screen that displays the Doodle Jump game.
///
/// The [GameScreen] requires an [OpenEarable] instance, a [Doodle] player, and
/// a list of [Platform] objects to be provided.
///
/// The top bar displays a tilt indicator that shows the current roll value
/// obtained from the sensor data of the [OpenEarable] device.
///
/// The [loadSensor] method subscribes to the sensor data from the [OpenEarable]
/// device and updates the roll value accordingly.
class GameScreen extends StatefulWidget {
  final Doodle player;
  final List<Platform> platforms;
  final OpenEarable openEarable;
  const GameScreen(
    this.openEarable, {
    super.key,
    required this.player,
    required this.platforms,
  });

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
  double roll = 0.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InfiniteBackground(playerPosition: widget.player.position),
        ..._generatePlatforms(),
        _buildPlayer(),
        TopBar(openEarable: widget.openEarable),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
  }

  Widget _buildPlayer() {
    return Positioned(
      left: widget.player.horizontalPosition,
      bottom: widget.player.position,
      child: Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('lib/apps_tab/doodle_jump/assets/player.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  List<Widget> _generatePlatforms() {
    return widget.platforms.map((platform) {
      return Positioned(
        left: platform.x,
        bottom: platform.y,
        child: Container(
          width: platform.width,
          height: platform.height,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image:
                  AssetImage('lib/apps_tab/doodle_jump/assets/platform1.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }).toList();
  }
}
