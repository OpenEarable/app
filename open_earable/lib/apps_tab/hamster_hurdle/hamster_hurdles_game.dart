import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';

import 'package:flame/components.dart';

import 'package:flutter/material.dart';
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

  /// Builds the sensor config.
  OpenEarableSensorConfig _buildOpenEarableConfig() {
    return OpenEarableSensorConfig(sensorId: 0, samplingRate: 30, latency: 0);
  }

  /// Processes the sensor data.
  void _processSensorData(Map<String, dynamic> data) {
    _accX = _kalmanY.filtered(data["ACC"]["X"]);
    _accY = _kalmanY.filtered(data["ACC"]["Y"]);
    _accZ = _kalmanZ.filtered(data["ACC"]["Z"]);
    addData(_accZ);
    _determineAction();
  }

  void addData(double newData) {
    // Add new data to the queue
    latestAccZValues.addLast(newData);

    // Remove the oldest element if the queue exceeds size 5
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
    if (_accZ < 0 + jumpThreshold && primaryUpwardsMovement() &&
        currentAction != GameAction.jumping) {
      game.onJump(currentAction);
      setState(() {
        currentAction = GameAction.jumping;
      });
    } else if (_accZ > _gravity + duckThreshold &&
        currentAction != GameAction.jumping &&
        !_recentlyLanded() &&
        !_recentlyGotUp()) {
      setState(() {
        currentAction = GameAction.ducking;
        game.onDuck();
      });
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
    double maximumMovementInYXPlane = 10;
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
        body: GameWidget(
      game: game,
      overlayBuilderMap: {
        PlayState.playing.name: (context, game) => StopButton(),
        PlayState.gameOver.name: (context, game) => GameOverOverlay(),
      },
    ));
  }
}

class StopButton extends StatelessWidget {
  const StopButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: const Icon(Icons.arrow_back_rounded),
        style: ElevatedButton.styleFrom(backgroundColor: Color(0xff8d4223)),
        label: Text("End Game"));
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
    _playState = playState;
    switch (playState) {
      case PlayState.gameOver:
      case PlayState.playing:
        overlays.add(playState.name);
    }
  }

  @override
  Future<void> onLoad() async {
    return super.onLoad();
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
  const GameOverOverlay({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: const Alignment(0, -0.15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Game Over",
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Return"))
        ],
      ),
    );
  }
}
