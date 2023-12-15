import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_earable/apps/driving_assistant/driving_assistant_notifier.dart';

class DrivingTime extends StatefulWidget {

  const DrivingTime ({required Key key}) : super(key: key);

  @override
  DrivingTimeState createState() => DrivingTimeState();
}

class DrivingTimeState extends State<DrivingTime> {
  bool manualPause = false;
  late Stream<int>? timerStream;
  late StreamSubscription<int> timerSubscription;
  String hoursStr = '00';
  String minutesStr = '00';
  String secondsStr = '00';

  Stream<int> stopWatchStream() {
    late StreamController<int> streamController;
    late Timer? timer;
    Duration timerInterval = Duration(seconds: 1);
    int counter = 0;

    void stopTimer() {
      if (timer != null) {
        timer!.cancel();
        timer = null;
        counter = 0;
        streamController.close();
      }
    }

    void tick(_) {
      if(!manualPause){
        counter++;
      }
      streamController.add(counter);
    }

    void startTimer() {
      timer = Timer.periodic(timerInterval, tick);
    }

    streamController = StreamController<int>(
      onListen: startTimer,
      onCancel: stopTimer,
      onResume: startTimer,
      onPause: stopTimer,
    );

    return streamController.stream;
  }

  void startTimer(){
    timerStream = stopWatchStream();
    timerSubscription = timerStream!.listen((int newTick) {
      setState(() {
        hoursStr = ((newTick / (60 * 60)) % 60)
            .floor()
            .toString()
            .padLeft(2, '0');
        minutesStr = ((newTick / 60) % 60)
            .floor()
            .toString()
            .padLeft(2, '0');
        secondsStr =
            (newTick % 60).floor().toString().padLeft(2, '0');
      });
    });
  }

  void stopTimer(){
    timerSubscription.cancel();
    timerStream = null;
    setState(() {
      hoursStr = '00';
      minutesStr = '00';
      secondsStr = '00';
    });
  }

  void pauseTimer(){
    if(!manualPause){
      manualPause = true;
    } else {
      manualPause = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Time driven",
          style: TextStyle(
            fontSize: 40,
          ),
        ),
        Text(
          "$hoursStr:$minutesStr:$secondsStr",
          style: TextStyle(
            fontSize: 70.0,
          ),
        ),
      ],
    );
  }
}