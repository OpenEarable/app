/// A Flutter widget that implements the Doodle Jump game using the OpenEarable package.
///
/// This widget manages the state of the game, including the player's position,
/// the platforms, and the game state. It also handles the connection to the
/// OpenEarable device and processes sensor data to control the player's movements.
///
/// The widget consists of the following components:
/// - An app bar with the title "Doodle Jump".
/// - A body that displays different screens based on the game state:
///   - Start screen: Shown when the game is not active.
///   - Game screen: Shown when the game is active.
///   - Game over screen: Shown when the game is over.
///   - Info screen: Displays information about the OpenEarable device.
/// - A bottom navigation bar to switch between the game and info screens.
///
/// The game logic includes:
/// - Initializing platforms at the start of the game.
/// - Resetting the game state.
/// - Starting the game and updating the game state periodically.
/// - Handling sensor data to move the player left or right.
/// - Updating the player's position and checking for collisions with platforms.
/// - Adding new platforms as the player progresses.
library;

import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'dart:async';
import 'dart:math';

import 'screens/game_screen.dart';
import 'screens/start_screen.dart';
import 'screens/game_over_screen.dart';
import 'screens/info_screen.dart';
import 'models/doodle.dart';
import 'models/platform.dart';

class DoodleJump extends StatefulWidget {
  final OpenEarable openEarable;

  const DoodleJump(this.openEarable, {super.key});

  @override
  State<DoodleJump> createState() => _DoodleJumpState();
}

class _DoodleJumpState extends State<DoodleJump> {
  int _currentIndex = 0;
  final String title = 'Doodle Jump';
  bool _gameActive = false;
  bool _gameOver = false;
  bool _showConnectionError = false;
  var _sensorSubscriptions;

  Doodle player = Doodle();
  Timer? timer;
  double roll = 0.0;
  double screenWidth = 0.0;
  double screenHeight = 0.0;
  List<Platform> platforms = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text(title),
    );
  }

  Widget _buildBottomNavBar() {
    if (_gameActive) return const SizedBox.shrink();

    return BottomNavigationBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      currentIndex: _currentIndex,
      onTap: _onNavBarItemTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.gamepad),
          label: 'Game',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.info),
          label: 'Info',
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_gameActive) {
      return GameScreen(
        widget.openEarable,
        player: player,
        platforms: platforms,
      );
    }

    switch (_currentIndex) {
      case 0:
        return _gameOver
            ? GameOverScreen(onRestartPressed: _startGame)
            : StartScreen(
                onStartPressed: _startGame,
                showConnectionError: _showConnectionError);

      case 1:
        return InfoScreen(widget.openEarable);
      default:
        return const Center(
          child: Text('Invalid Index'),
        );
    }
  }

  void _onNavBarItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _initializePlatforms() {
    for (int i = 0; i < 6; i++) {
      platforms.add(
        Platform(
          x: Random().nextDouble() * (screenWidth - 100),
          y: screenHeight - (i * 150),
        ),
      );
    }
  }

  void _resetGame() {
    setState(() {
      _gameActive = false;
      _gameOver = false;
      player = Doodle();
      platforms = [];
      _initializePlatforms();
    });
  }

  void _startGame() {
    if (widget.openEarable.bleManager.connected) {
      didChangeDependencies();
      _resetGame();

      setState(() {
        _gameActive = true;
      });
      timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
        if (!_gameActive) {
          timer.cancel();
        } else {
          setState(() {
            _updateGame();
            if (!player.playerActive) {
              _gameActive = false;
              _gameOver = true;
            }
          });
        }
      });
    } else {
      setState(() {
        _showConnectionError = true;
      });

      Future.delayed(const Duration(seconds: 3), () {
        setState(() {
          _showConnectionError = false;
        });
      });
    }
  }

  void loadSensor() {
    widget.openEarable.sensorManager.writeSensorConfig(_buildSensorConfig());
    _sensorSubscriptions = widget.openEarable.sensorManager
        .subscribeToSensorData(0)
        .listen((data) {
      roll = data["EULER"]["ROLL"];
      double thresholdLeft = 0.45;
      double threshholdRight = 0.1;
      if (roll > threshholdRight) {
        player.moveRight();
      } else if (roll < -thresholdLeft) {
        player.moveLeft();
      }
    });
  }

  void _updateGame() {
    player.update(context);
    player.checkPlatformCollisions(platforms);

    for (var platform in platforms) {
      platform.y -= player.velocity * player.timeSlice;
    }

    platforms.removeWhere((platform) => platform.y < 0);

    if (platforms.isEmpty || platforms.length < 6) {
      platforms.add(Platform(
        x: Random().nextDouble() * (screenWidth - 100),
        y: screenHeight + 100,
      ));
    }

    if (player.position > screenHeight / 2) {
      double offset = player.position - screenHeight / 2;
      player.position = screenHeight / 2;
      for (var platform in platforms) {
        platform.y -= offset;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.openEarable.bleManager.connected) {
      loadSensor();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    if (widget.openEarable.bleManager.connected) {
      _sensorSubscriptions.cancel();
    }
    super.dispose();
  }

  OpenEarableSensorConfig _buildSensorConfig() {
    return OpenEarableSensorConfig(
      sensorId: 0,
      samplingRate: 30,
      latency: 0,
    );
  }
}
