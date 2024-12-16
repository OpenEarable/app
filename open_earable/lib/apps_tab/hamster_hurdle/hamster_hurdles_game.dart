import 'dart:async';
import 'dart:collection';

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
  double _accZ = 0.0;

  /// Kalman-Filter for acceleration Z-axis;
  late SimpleKalman _kalmanZ;


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
    double jumpThreshold = 0.5;
    if (_accZ < 0 + jumpThreshold && currentAction != GameAction.jumping) {
      game.onJump(currentAction);
      setState(() {
        currentAction = GameAction.jumping;
      });
    } else if (_accZ > _gravity + 1.5 &&
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

  bool _isUpwardsMotion() {
    int counter = 0;
    double threshold = 0.6;
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
        'StopButton': (context, game) => StopButton(),
      },
      initialActiveOverlays: const ['StopButton'],
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


