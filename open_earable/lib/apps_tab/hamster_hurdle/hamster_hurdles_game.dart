import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';

import 'package:flame/components.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_earable/apps_tab/hamster_hurdle/playing_time.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:simple_kalman/simple_kalman.dart';

import 'hamster_hurdles_world.dart';

enum HamsterPosture {
  normal,
  ducking,
}

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.openEarable});

  /// Instance of OpenEarable device.
  final OpenEarable openEarable;

  @override
  State<StatefulWidget> createState() => GamePageState();
}

class GamePageState extends State<GamePage> {
  late final HamsterHurdle game;

  /// Subscription to the IMU sensor.
  StreamSubscription? _imuSubscription;

  DateTime? _timeOfLanding;
  DateTime? _timeOfGettingUp;

  /// Z-axis acceleration.
  double _accX = 0.0;

  /// Y-axis acceleration.
  double _accY = 0.0;

  /// Z-axis acceleration.
  double _accZ = 0.0;

  /// Kalman-Filter for acceleration Z-axis;
  late SimpleKalman _kalmanX, _kalmanY, _kalmanZ;

  Queue<double> latestAccZValues = Queue<double>.from(List.filled(5, 0));

  ///The error measurement used in the Kalman-Filter for acceleration
  final double _errorMeasureAcc = 5.0;

  /// Standard gravity in m/s^2.
  final double _gravity = 9.81;

  GameAction currentAction = GameAction.running;

  final ValueNotifier<String> _timeNotifier = ValueNotifier("0:00");

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

  void _determineAction() {
    double jumpThreshold = 0.8;
    double duckThreshold = 1.5;
    if (_accZ < 0 + jumpThreshold &&
        primaryUpwardsMovement() &&
        currentAction != GameAction.jumping) {
      game.onJump(currentAction);
      currentAction = GameAction.jumping;
    } else if (_accZ > _gravity + duckThreshold &&
        currentAction != GameAction.jumping &&
        !_recentlyLanded() &&
        !_recentlyGotUp()) {
      game.onDuck();
      currentAction = GameAction.ducking;
    } else if (currentAction == GameAction.jumping && game.hamsterOnGround()) {
      _timeOfLanding = DateTime.now();
      currentAction = GameAction.running;
    } else if (currentAction == GameAction.ducking && _isUpwardsMotion()) {
      game.onGetUp();
      _timeOfGettingUp = DateTime.now();
      currentAction = GameAction.running;
    }
  }

  bool primaryUpwardsMovement() {
    double maximumMovementInYXPlane = 8;
    return sqrt(_accX * _accX + _accY * _accY) < maximumMovementInYXPlane;
  }

  bool _isUpwardsMotion() {
    int counter = 0;
    double threshold = 0.3;
    for (double data in latestAccZValues) {
      if (data + threshold < _accZ) {
        counter++;
      }
    }
    return counter > 3;
  }

  bool _recentlyLanded() {
    if (_timeOfLanding == null) {
      return false;
    } else {
      return DateTime.now().difference(_timeOfLanding!) <
          Duration(milliseconds: 300);
    }
  }

  bool _recentlyGotUp() {
    if (_timeOfGettingUp == null) {
      return false;
    } else {
      return DateTime.now().difference(_timeOfGettingUp!) <
          Duration(milliseconds: 200);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(
            game: game,
            overlayBuilderMap: {
              PlayState.playing.name: (context, game) => ActiveGameOverlay(
                    gameTimer: GameTimer(
                      timeNotifier: _timeNotifier,
                    ),
                  ),
              PlayState.gameOver.name: (context, game) => GameOverOverlay(
                    finalTime:_timeNotifier.value,
                  ),
            },
            initialActiveOverlays: [PlayState.playing.name],
          ),
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
                label: buildOverlayText("End Game", 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActiveGameOverlay extends StatelessWidget {
  const ActiveGameOverlay({super.key, required this.gameTimer});

  final Widget gameTimer;

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Column(
      children: [
        SizedBox(height: screenHeight / 9),
        Center(child: gameTimer),
      ],
    );
  }
}

class HamsterHurdle extends FlameGame<HamsterHurdleWorld>
    with HasCollisionDetection, TapDetector, KeyboardEvents {
  HamsterHurdle()
      : super(
          world: HamsterHurdleWorld(),
        );

  late Vector2 currentViewPortSize;

  DateTime? duckingStartTime;

  PlayState _playState = PlayState.playing;

  PlayState get playState => _playState;

  set playState(PlayState playState) {
    switch (playState) {
      case PlayState.gameOver:
        overlays.add(playState.name);
        overlays.remove(PlayState.playing.name);
      case PlayState.playing:
        overlays.add(playState.name);
        overlays.remove(PlayState.gameOver.name);
    }
    _playState = playState;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
  }

  @override
  void update(double dt) {
    currentViewPortSize = camera.viewport.size;
    super.update(dt);
  }

  void onJump(GameAction lastAction) {
    world.hamster.jump(lastAction);
  }

  void onDuck() {
    world.hamster.duck();
    duckingStartTime = DateTime.now();
  }

  void onGetUp() {
    world.hamster.getUp();
  }

  bool hamsterOnGround() {
    return world.hamster.isTouchingGround();
  }

  Duration calculateDuckingTime() {
    return DateTime.now().difference(duckingStartTime!);
  }

  @override
  void onTap() {
    super.onTap();
    _restartGame();
  }

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

  void _restartGame() {
    if (_playState == PlayState.gameOver) {
      world.startGame();
      playState = PlayState.playing;
    }
  }

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
  }
}

enum GameAction {
  ducking,
  jumping,
  running,
}

enum PlayState { playing, gameOver }

class GameOverOverlay extends StatelessWidget {
  final String finalTime;

  const GameOverOverlay({
    required this.finalTime,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    return Container(
      alignment: const Alignment(0, -0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildOverlayText("Game Over", 48),
          const SizedBox(height: 16),
          buildOverlayText("Tab to play again", 24),
          SizedBox(height: 20),
          buildOverlayText("Time played: $finalTime", 48)
        ],
      ),
    );
  }
}

///Selects custom font for Text in game.
Widget buildOverlayText(String message, double fontSize) {
  return Text(
    message,
    style: TextStyle(fontFamily: 'HamsterHurdleFont', fontSize: fontSize),
  );
}
