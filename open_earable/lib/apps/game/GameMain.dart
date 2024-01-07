import 'package:flutter/material.dart';
import 'package:open_earable/apps/game/pixel.dart';
import 'package:open_earable/apps/game/Player.dart';
import 'package:open_earable/apps/game/ewma.dart';
import 'dart:async';
import 'dart:math';
import 'dart:core';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class MazeRace extends StatefulWidget {
  final OpenEarable _openEarable;
  MazeRace(this._openEarable);

  @override
  State<MazeRace> createState() => _MazeRaceState(_openEarable);
}

class _MazeRaceState extends State<MazeRace> {

  //Variables used for the grid
  static int numberInRow = 11;
  int numberOfSquares = numberInRow * 19;
  List<int> barriers = [
    0, 1, 2, 3, 4, 5, 6, 7, 9, 10,
    11, 20, 21,
    22, 24, 25, 26, 27, 28, 29, 30, 31, 32,
    33, 38, 43,
    44, 45, 46, 47, 49, 51, 52, 53, 54,
    55, 60, 65,
    66, 68, 69, 70, 71, 72, 73, 74, 76,
    77, 87,
    88, 89, 90, 91, 92, 94, 96, 98,
    99, 105, 107, 109,
    110, 112, 113, 114, 115, 116, 120,
    121, 123, 124, 125, 126, 127, 128, 129, 131,
    132, 142,
    143, 144, 145, 146, 147, 148, 150, 151, 152, 153,
    154, 159, 164,
    165, 167, 168, 170, 171, 172, 173, 175,
    176, 179, 186,
    187, 188, 190, 191, 192, 193, 194, 195, 196, 197
  ];
  int playerPosition = numberInRow * 17 + 2;
  int winPosition = 8;

  String direction = "left";
  bool playerWins = false;

  final OpenEarable _openEarable;
  StreamSubscription? _imuSubscription;
  _MazeRaceState(this._openEarable);

  //Pitch vars (up and down movements)
  double _currentPitch = 0;
  EWMA _pitchEWMA = EWMA(0.15);
  double _initPitch = 0;

  //Roll vars (left and right movements)
  double _currentRoll = 0;
  EWMA _rollEWMA = EWMA(0.15);
  double _initRoll = 0;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    Future.delayed(Duration.zero, () {
      startGame();
    });
  }

  @override
  void dispose() {
    super.dispose();
    _imuSubscription?.cancel();
  }

  //Method for taking up-to-date data from the sensor
  _setupListeners() {
    _imuSubscription =
        _openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
          setState(() {
            //initial position of the player`s head (used for more accuracy)
            if(_initPitch == 0){
              _initPitch = _currentPitch;
            }
            _currentPitch = _pitchEWMA.update(data["EULER"]["PITCH"]);
            if(_initRoll == 0){
              _initRoll = _currentRoll;
            }
            _currentRoll = _rollEWMA.update(data["EULER"]["ROLL"]);
            startTimer();
            startGame();
          });
        });
  }

  void startGame() {

    setState(() {
    double actualPitch = _currentPitch - _initPitch;
    double actualRoll = _currentRoll - _initRoll;

    //Check if player already won
    if(direction != "stopped"){
      // Important proportion: 0.17radian = 10grad
      //Check whether to use pitch values or roll values for the mouse movement
      if(actualPitch.abs() > actualRoll.abs()){
        if(actualPitch.abs() > 0.07) {
          if (actualPitch < 0) {
            direction = "up";
          } else {
            direction = "down";
          }
        }
      } else {
        if(actualRoll.abs() > 0.07) {
          if (actualRoll < 0) {
            direction = "left";
          } else {
            direction = "right";
          }
        }
      }

      switch (direction) {
        case "left":
          moveLeft();
          break;
        case "right":
          moveRight();
          break;
        case "up":
          moveUp();
          break;
        case "down":
          moveDown();
          break;
        default:
          break;
      }
    }
    });
  }

  void moveLeft() {
    if (!barriers.contains(playerPosition - 1) && checkIfMouseCanMove()) {
      setState(() {
        playerPosition--;
      });
    }
  }

  void moveRight() {
    if (!barriers.contains(playerPosition + 1) && checkIfMouseCanMove()) {
      setState(() {
        playerPosition++;
      });
    }
  }

  void moveUp() {
    if (!barriers.contains(playerPosition - numberInRow) &&
        checkIfMouseCanMove()) {
      setState(() {
        playerPosition -= numberInRow;
      });
    }
  }

  void moveDown() {
    if (!barriers.contains(playerPosition + numberInRow) &&
        checkIfMouseCanMove()) {
      setState(() {
        playerPosition += numberInRow;
      });
    }
  }

  bool checkIfMouseCanMove() {
    bool mouseCanMove = false;

    switch (direction) {
      case "left":
        if (playerPosition - 1 > -1 && playerPosition - 1 < 198) {
          mouseCanMove = true;
        }
        break;
      case "right":
        if (playerPosition + 1 > -1 && playerPosition + 1 < 198) {
          mouseCanMove = true;
        }
        break;
      case "up":
        if (playerPosition - 11 > -1 && playerPosition - 11 < 198) {
          mouseCanMove = true;
        }
        break;
      case "down":
        if (playerPosition + 11 > -1 && playerPosition + 11 < 198) {
          mouseCanMove = true;
        }
        break;
      case "stopped":
        break;
      default:
        break;
    }

    return mouseCanMove;
  }

  Stopwatch stopwatch = Stopwatch();

  void startTimer() {
    Timer.periodic(Duration(seconds: 1), (timer) {
      if (direction == "stopped") {
        timer.cancel();
      } else {
        setState(() {
          stopwatch..start();
        });
      }
    });
  }

  String formattedTime(Duration duration) {
    int minutes = duration.inMinutes;
    int seconds = duration.inSeconds % 60;
    int milliseconds = (duration.inMilliseconds % 1000) ~/ 10;

    String minutesStr = minutes.toString().padLeft(2, '0');
    String secondsStr = seconds.toString().padLeft(2, '0');
    String millisStr = milliseconds.toString().padLeft(2, '0');

    return '$minutesStr:$secondsStr:$millisStr';
  }

  void showAlertDialog(BuildContext context) {
    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {

          return AlertDialog(
            backgroundColor: Color.fromRGBO(255, 247, 212, 1),
            title: Text(
                "Are you sure you want to start new game?",
                style: TextStyle(color: Color.fromRGBO(238, 199, 89, 1), fontSize: 20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
            ),
            actions: [
              TextButton(
                child: Text(
                    "Yes",
                    style: TextStyle(color: Color.fromRGBO(238, 199, 89, 1), fontSize: 20),
                ),
                onPressed: () {
                  setState(() {
                    playerPosition = 189;
                    direction = "left";
                    playerWins = false;
                    stopwatch.reset();
                  });
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text(
                    "No",
                    style: TextStyle(color: Color.fromRGBO(238, 199, 89, 1), fontSize: 20),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color.fromRGBO(255, 247, 212, 1),
        appBar: AppBar(
            title: Text('Maze Race'),
            centerTitle: true,
            backgroundColor: Color.fromRGBO(238, 199, 89, 1)
        ),
        body: Column(
          children: [
            Expanded(
                flex: 5,
                child: Container(
                    child: GridView.builder(
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: numberOfSquares,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: numberInRow),
                        itemBuilder: (BuildContext context, int index) {
                          //Winning: Mouse eating the cheese
                          if (index == playerPosition &&
                              playerPosition == winPosition) {
                              direction = "stopped";
                              stopwatch.stop();
                              playerWins = true;
                            return Image.asset(
                                'lib/apps/game/images/mouse-winner.jpg');
                          }
                          //Position of the cheese
                          if (index == winPosition &&
                              playerPosition != winPosition) {
                            return Image.asset(
                                'lib/apps/game/images/cheese.jpg');
                          }

                          //Movements of the mouse
                          if (playerPosition == index) {
                            switch (direction) {
                              case "right":
                                return Transform.flip(flipX: true,
                                  child: Player(),);
                              case "left":
                                return Player();
                              case "down":
                                return Transform.rotate(angle: 3 * pi / 2,
                                  child: Player(),);
                              case "up":
                                return Transform.rotate(
                                  angle: pi / 2, child: Player(),);
                              case "stopped":
                                return Player();
                              default:
                                break;
                            }
                          }

                          //Barriers of the maze
                          if (barriers.contains(index)) {
                            return Pixel(
                              color: Color.fromRGBO(155, 184, 205, 1),
                            );
                          } else {
                            //Path of the maze
                            return Pixel(
                              color: Color.fromRGBO(177, 195, 129, 1),
                              );
                          }
                        }),
                  ),
                //)
            ),
            Expanded(
              child: Container(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text(
                            "Time: ",
                            style: TextStyle(color: Color.fromRGBO(238, 199, 89, 1), fontSize: 20),
                          ),
                          Text(
                            formattedTime(stopwatch.elapsed),
                            style: TextStyle(color: Color.fromRGBO(238, 199, 89, 1), fontSize: 20),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        showAlertDialog(context);
                      },
                      child: Text(
                          "New game",
                          style: TextStyle(color: Color.fromRGBO(238, 199, 89, 1), fontSize: 20),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        )
    );
  }
}


