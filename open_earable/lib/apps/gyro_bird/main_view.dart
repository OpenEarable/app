import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:open_earable/apps/gyro_bird/barrier.dart';
import 'package:open_earable/apps/gyro_bird/bird.dart';
import 'package:open_earable/apps/gyro_bird/ewma.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:wakelock/wakelock.dart';
import 'package:flutter/services.dart';

class GyroBird extends StatefulWidget {
  final OpenEarable _openEarable;

  GyroBird(this._openEarable);

  @override
  State<GyroBird> createState() => _GyroBirdState(_openEarable);
}

class _GyroBirdState extends State<GyroBird> {
  final OpenEarable _openEarable;

  _GyroBirdState(this._openEarable);

  StreamSubscription? _imuSubscription;

  EWMA _pitchEWMA = EWMA(0.2);
  double _offset = 0;

  late Timer _gameTimer = Timer(Duration(seconds: 0), () {});

  double _currentPitch = 0;
  double _previousPitch = 0;
  double _calibratedPitch = 0;
  double _sensitivity = 4;
  double _birdPosition = 0;
  bool collision = false;
  double _rotationAngle = 0;

  Random random = Random();
  List<double> barrierPositions = [];
  List<double> barrierHeights = [];

  int score = 0;
  int highScore = 0;

  _setupListeners() {
    _imuSubscription = _openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
      setState(() {
        _previousPitch = _currentPitch;
        _currentPitch = _pitchEWMA.update(data["EULER"]["PITCH"]);
        setBirdHeight();
        setRotationAngle();
      });
    });
  }

  // Determine bird position according to the pitch data.
  // sensitivity coefficient is used regulate the length of the head motion needed to move the bird.
  setBirdHeight() {
    _calibratedPitch = _currentPitch - _offset;
    if ((_calibratedPitch * _sensitivity > 0.97) && !collision) {
      _birdPosition = 0.97;
    } else if (!collision) {
      _birdPosition = _calibratedPitch * _sensitivity;
    }
  }

  // A rotation angle is calculated, which is used to create more realistic movement of the bird.
  void setRotationAngle() {
    double _delta = 0;
    if (!collision) {
      _delta = _currentPitch - _previousPitch;
      _rotationAngle = _delta * 20;
    }
  }

  @override
  void initState() {
    super.initState();
    _setupListeners();
    Wakelock.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
      SystemUiOverlay.bottom,
    ]);
    startGame();
  }

  void exit() {
    _imuSubscription?.pause();
    _gameTimer.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    Navigator.of(context).pop();
    Wakelock.disable();
  }

  @override
  void dispose() {
    super.dispose();
    _gameTimer.cancel();
    _imuSubscription?.cancel();
  }

  // Convert the bird height to barrier height, to that they can be compared later to determine collision.
  double mapBirdToBarrierScale(double birdHeight) {
    double _barrierHeight = 1 - (birdHeight + 1) / 2;
    return _barrierHeight;
  }

  // Generate random barrier heights.
  generateHeights() {
    barrierHeights = List.generate(5, (index) => random.nextDouble() * 0.6 + 0.15); // Generate a number between 0,15 and 0,75
  }

  initPositions() {
    barrierPositions = [2.0, 4.0, 6.0, 8.0, 10.0];
  }

  // This function is called when the "Calibrate" button is pressed;
  // maps the current position of the head to the neutral position of the bird on the screen.
  void calibrate() {
    _offset = _currentPitch;
  }

  // Determine if the bird has hit a barrier by checking if the height of the bird is less than the bottom barrier
  // or more than the top barrier.
  checkCollision(index) {
    double _bottomBarrierHeight = barrierHeights[index];
    double _topBarrierHeight = 1.0 - (0.8 - barrierHeights[index]);
    double _birdHeight = mapBirdToBarrierScale(_birdPosition);
    double _adjustmentHeightBottom = 0.08 * _bottomBarrierHeight;
    double _adjustmentHeightTop = 0.06 * (1 - _topBarrierHeight);

    if ((_birdHeight <= _bottomBarrierHeight + _adjustmentHeightBottom) || (_birdHeight >= _topBarrierHeight - _adjustmentHeightTop)) {
      collision = true;
    }
  }

  // Move the barriers across the screen; if a barrier goes outside of screen to the left, bring it back to the right and generate new height.
  void moveBarriers(index) {
    if (barrierPositions[index] < -2) {
      barrierPositions[index] += 10;
      barrierHeights[index] = random.nextDouble() * 0.4 + 0.15;
    } else {
      barrierPositions[index] -= 0.02;
    }
  }

  void startGame() {
    if (_imuSubscription?.isPaused ?? false) {
      _imuSubscription?.resume();
    }

    setState(() {
      initPositions();
      collision = false;
      score = 0;
      generateHeights();
    });

    // A timer that refreshes all moving UI elements and values every 30ms.
    _gameTimer = Timer.periodic(Duration(milliseconds: 30), (timer) {
      setState(() {
        for (int i = 4; i >= 0; i--) {
          double _barrierPosition = barrierPositions[i];
          if (_barrierPosition > -0.01 && _barrierPosition <= 0.01) {
            score++;
            if (score > highScore) {
              highScore++;
            }
          }
          if ((_barrierPosition > -0.40) && (_barrierPosition < 0.53)) {
            checkCollision(i);
          }
          if (collision) {
            _gameTimer.cancel();
          } else {
            moveBarriers(i);
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            height: 0.80 * MediaQuery.of(context).size.height,
            color: Colors.blue.shade400,
            child: Stack(
              children: [
                Stack(
                  children: generateBarriers(),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 25,
                    decoration: BoxDecoration(
                        color: Colors.green,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade800,
                            width: 4.0,
                          ),
                          top: BorderSide(
                            color: Colors.green.shade800,
                            width: 4.0,
                          ),
                        )),
                  ),
                ),
                Align(
                  alignment: Alignment(0, _birdPosition),
                  child: FractionallySizedBox(
                    heightFactor: 0.085,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 30),
                      child: Transform.rotate(angle: _rotationAngle, child: Bird()),
                    ),
                  ),
                ),
                Visibility(
                  visible: collision,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 50,
                        width: MediaQuery.of(context).size.width,
                      ),
                      Text(
                        'GAME OVER',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 50, color: Colors.red.shade800),
                      ),
                      SizedBox(
                        height: 150,
                        width: MediaQuery.of(context).size.width,
                      ),
                      Container(
                        margin: EdgeInsets.fromLTRB(50, 0, 50, 0),
                        width: MediaQuery.of(context).size.width,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              startGame();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.all(20),
                            backgroundColor: Colors.brown.shade800,
                          ),
                          child: Text('New Game'),
                        ),
                      ),
                      SizedBox(height: 20), // Add some space between the buttons
                      Container(
                        margin: EdgeInsets.fromLTRB(50, 0, 50, 0),
                        width: MediaQuery.of(context).size.width,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              calibrate();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.all(20),
                            backgroundColor: Colors.brown.shade800,
                          ),
                          child: Text('Calibrate'),
                        ),
                      ),
                      SizedBox(height: 20), // Add some space between the buttons
                    ],
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.brown.shade400,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'SCORE',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      Text('$score', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 40))
                    ],
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('BEST', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      SizedBox(
                        height: 15,
                      ),
                      Text('$highScore', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 40)),
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // Generate a list of 5 barriers.
  List<Widget> generateBarriers() {
    List<Widget> barriers = [];
    for (int i = 0; i < 5; i++) {
      barriers.add(
        Align(
          alignment: Alignment(barrierPositions[i], 1.0),
          child: FractionallySizedBox(
            heightFactor: barrierHeights[i],
            child: Barrier(),
          ),
        ),
      );
      barriers.add(
        Align(
          alignment: Alignment(barrierPositions[i], -1.0),
          child: FractionallySizedBox(
            heightFactor: 0.8 - barrierHeights[i],
            child: RotatedBox(
              quarterTurns: 2,
              child: Barrier(),
            ),
          ),
        ),
      );
    }
    return barriers;
  }
}
