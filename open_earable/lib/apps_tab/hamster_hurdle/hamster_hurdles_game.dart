import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';

import 'package:flame/components.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_earable/apps_tab/hamster_hurdle/game_score.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:simple_kalman/simple_kalman.dart';

import '../../shared/earable_not_connected_warning.dart';
import 'gameOverOverlay.dart';
import 'hamster_hurdles_world.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.openEarable});

  /// Instance of OpenEarable device.
  final OpenEarable openEarable;

  @override
  State<StatefulWidget> createState() => GamePageState();
}

class GamePageState extends State<GamePage> {
  ///the instance of the game.
  late final HamsterHurdle game;

  /// Subscription to the IMU sensor.
  StreamSubscription? _imuSubscription;

  ///last time of hamster landing after jump.
  DateTime? _timeOfLanding;

  ///last time hamster got up from ducking position.
  DateTime? _timeOfGettingUp;

  /// Z-axis acceleration.
  double _accX = 0.0;

  /// Y-axis acceleration.
  double _accY = 0.0;

  /// Z-axis acceleration.
  double _accZ = 0.0;

  /// Kalman-Filter for acceleration Z-axis;
  late SimpleKalman _kalmanX, _kalmanY, _kalmanZ;

  ///The last five measured z-axis acceleration values.
  Queue<double> latestAccZValues = Queue<double>.from(List.filled(5, 0));

  ///The error measurement used in the Kalman-Filter for acceleration
  final double _errorMeasureAcc = 5.0;

  /// Standard gravity in m/s^2.
  final double _gravity = 9.81;

  ///the current action of the player during the game.
  GameAction currentAction = GameAction.running;

  ///the current score of the game.
  final ValueNotifier<int> _scoreNotifier = ValueNotifier(0);

  /// Builds the sensor config.
  OpenEarableSensorConfig _buildOpenEarableConfig() {
    return OpenEarableSensorConfig(sensorId: 0, samplingRate: 30, latency: 0);
  }

  /// Processes the sensor data.
  void _processSensorData(Map<String, dynamic> data) {
    _accX = _kalmanX.filtered(data["ACC"]["X"]);
    _accY = _kalmanY.filtered(data["ACC"]["Y"]);
    _accZ = _kalmanZ.filtered(data["ACC"]["Z"]);
    addSensorData(_accZ);
    _determineAction();
  }

  ///adds the newData to the latest measured z-axis acceleration values.
  void addSensorData(double newData) {
    latestAccZValues.addLast(newData);
    if (latestAccZValues.length > 5) {
      latestAccZValues.removeFirst();
    }
  }

  /// Sets up listeners for sensor data.
  void _setupListeners() {
    _imuSubscription = widget.openEarable.sensorManager
        .subscribeToSensorData(0)
        .listen(_processSensorData);
  }

  ///determines which player action should be shown on screen based on
  /// current sensory data.
  void _determineAction() {
    double jumpThreshold = 0.5;
    double duckThreshold = 1.5;
    if (_accZ < 0 + jumpThreshold &&
        primaryVerticalMovement() &&
        currentAction != GameAction.jumping) {
      game.onJump(currentAction);
      currentAction = GameAction.jumping;
    } else if (_accZ > _gravity + duckThreshold &&
        currentAction != GameAction.jumping &&
        !_recentlyLanded() &&
        !_recentlyGotUp()) {
      game.onDuck();
      currentAction = GameAction.ducking;
    } else if (currentAction == GameAction.jumping &&
        game.hamsterTouchesGround()) {
      _timeOfLanding = DateTime.now();
      currentAction = GameAction.running;
    } else if (currentAction == GameAction.ducking && _isUpwardsMotion()) {
      game.onGetUp();
      _timeOfGettingUp = DateTime.now();
      currentAction = GameAction.running;
    }
  }

  ///checks if current measured  acceleration is primary along the z-axis.
  bool primaryVerticalMovement() {
    double maximumMovementInYXPlane = 6;
    return sqrt(_accX * _accX + _accY * _accY) < maximumMovementInYXPlane;
  }

  ///checks if sensory data indicates a gradual upwards motion by checking if
  ///the latest measured z-Axis acceleration values are greater than currently
  ///measured z-Axis acceleration value.
  bool _isUpwardsMotion() {
    int counter = 0;
    int thresholdCount = 3;
    double threshold = 0.3;
    for (double data in latestAccZValues) {
      if (data + threshold < _accZ) {
        counter++;
      }
    }
    return counter > thresholdCount;
  }

  ///Checks whether player has recently landed from a jump.
  bool _recentlyLanded() {
    if (_timeOfLanding == null) {
      return false;
    } else {
      return DateTime.now().difference(_timeOfLanding!) <
          Duration(milliseconds: 300);
    }
  }

  ///Checks whether player has recently gotten up from ducking.
  bool _recentlyGotUp() {
    if (_timeOfGettingUp == null) {
      return false;
    } else {
      return DateTime.now().difference(_timeOfGettingUp!) <
          Duration(milliseconds: 200);
    }
  }

  ///Initializes the Kalman-Filters.
  void _initKalman() {
    _kalmanZ = SimpleKalman(
      errorMeasure: _errorMeasureAcc,
      errorEstimate: _errorMeasureAcc,
      q: 0.9,
    );
    _kalmanY = SimpleKalman(
      errorMeasure: _errorMeasureAcc,
      errorEstimate: _errorMeasureAcc,
      q: 0.9,
    );
    _kalmanX = SimpleKalman(
      errorMeasure: _errorMeasureAcc,
      errorEstimate: _errorMeasureAcc,
      q: 0.9,
    );
  }

  /// Initializes state and sets up listeners for sensor data.
  @override
  void initState() {
    super.initState();
    _initKalman();
    game = HamsterHurdle();
    if (widget.openEarable.bleManager.connected) {
      widget.openEarable.sensorManager
          .writeSensorConfig(_buildOpenEarableConfig());
      _setupListeners();
    }
  }

  /// Cancels the subscription to the IMU sensor when the widget is disposed.
  @override
  void dispose() {
    super.dispose();
    _imuSubscription?.cancel();
  }

  ///The widget displaying the hamster hurdle game with the current overlays
  ///based on the state of the game.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          widget.openEarable.bleManager.connected
              ? GameWidget(
                  game: game,
                  overlayBuilderMap: {
                    PlayState.playing.name: (context, game) => GameScore(
                          scoreNotifier: _scoreNotifier,
                        ),
                    PlayState.gameOver.name: (context, game) => GameOverOverlay(
                          finalScore: _scoreNotifier.value,
                        ),
                  },
                  initialActiveOverlays: [PlayState.playing.name],
                )
              : EarableNotConnectedWarning(),
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back_rounded),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xff8d4223)),
                label: GameText(
                  text: "End Game",
                  fontSize: 18,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

///The Hamster Hurdle game.
class HamsterHurdle extends FlameGame<HamsterHurdleWorld>
    with HasCollisionDetection, TapDetector, KeyboardEvents {
  HamsterHurdle()
      : super(
          world: HamsterHurdleWorld(),
        );


  ///The current state of the play.
  PlayState _playState = PlayState.playing;
  PlayState get playState => _playState;

  set playState(PlayState playState) {
    switch (playState) {
      case PlayState.gameOver:
        world.stopGame();
        overlays.add(playState.name);
        overlays.remove(PlayState.playing.name);
      case PlayState.playing:
        overlays.add(playState.name);
        overlays.remove(PlayState.gameOver.name);
    }
    _playState = playState;
  }

  ///Starts jumping motion for hamster.
  void onJump(GameAction lastAction) {
    world.hamster.jump(lastAction);
  }

  ///Makes hamster get into a ducking position.
  void onDuck() {
    world.hamster.duck();
  }

  ///Makes hamster return to initial position.
  void onGetUp() {
    world.hamster.getUp();
  }

  ///Checks if hamster touches the ground of the hamster tunnel.
  bool hamsterTouchesGround() {
    return world.hamster.isTouchingGround();
  }


  ///Restarts game on tapping motion, when playState is GameOver.
  @override
  void onTap() {
    super.onTap();
    _restartGame();
  }

  ///Restarts the game when space or enter is pressed and playState is GameOver.
  @override
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    super.onKeyEvent(event, keysPressed);
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.enter:
        _restartGame();
    }
    return KeyEventResult.handled;
  }

  ///Starts the game and resets the playState to playing if playState is
  ///GameOver.
  void _restartGame() {
    if (_playState == PlayState.gameOver) {
      world.startGame();
      playState = PlayState.playing;
    }
  }
}

///Encapsulates the different actions a player can make in a game.
enum GameAction {
  ducking,
  jumping,
  running,
}

///Encapsulates the different states a Hamster Hurdles game can be in.
enum PlayState { playing, gameOver }

///Selects custom font for Text in game.
class GameText extends StatelessWidget {
  ///The text to render.
  final String text;

  ///The size at which the text should be rendered.
  final double fontSize;

  const GameText({
    required this.text,
    this.fontSize = 24,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontFamily: 'HamsterHurdleFont', fontSize: fontSize),
    );
  }
}
