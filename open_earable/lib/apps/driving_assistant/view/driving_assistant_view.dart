import 'package:flutter/material.dart';
import 'package:open_earable/apps/driving_assistant/controller/tiredness_monitor.dart';
import 'package:open_earable/apps/driving_assistant/view/observer.dart';
import 'package:open_earable/apps/driving_assistant/view/driving_settings_view.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:provider/provider.dart';
import 'package:open_earable/apps/driving_assistant/driving_assistant_notifier.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:open_earable/apps/driving_assistant/model/driving_time.dart';

import '../model/base_attitude_tracker.dart';

class DrivingAssistantView extends StatefulWidget implements Observer {
  GlobalKey<DrivingTimeState> _myKey = GlobalKey();
  final BaseAttitudeTracker _tracker;
  final OpenEarable _openEarable;
  Color mugColor = Colors.green;

  DrivingAssistantView(this._tracker, this._openEarable);

  @override
  void update(int tirednessCounter) {
    //Mug update
    switch (tirednessCounter) {
      case >= 4:
        mugColor = Colors.red;
        break;
      case >= 2:
        mugColor = Colors.yellow;
        break;
      case < 2:
        mugColor = Colors.green;
        break;
    }
  }

  @override
  State<DrivingAssistantView> createState() => _DrivingAssistantViewState();
}

class _DrivingAssistantViewState extends State<DrivingAssistantView> {
  late final DrivingAssistantNotifier _drivingNotifier;
  bool onDrive = false;
  bool onPause = false;

  @override
  void initState() {
    super.initState();
    this._drivingNotifier = DrivingAssistantNotifier(widget._tracker,
        new TirednessMonitor(widget._openEarable, widget._tracker));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DrivingAssistantNotifier>.value(
        value: _drivingNotifier,
        builder: (context, child) => Consumer<DrivingAssistantNotifier>(
            builder: (context, drivingAssistantNotifier, child) => Scaffold(
                  appBar: AppBar(
                    title: const Text("Driving Assistant"),
                    actions: [
                      IconButton(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) => DrivingSettingsView(
                                      this._drivingNotifier, widget))),
                          icon: Icon(Icons.settings)),
                    ],
                  ),
                  body: Center(
                    child: this._buildContentView(drivingAssistantNotifier),
                  ),
                )));
  }

  Widget _buildContentView(DrivingAssistantNotifier drivingAssistantNotifier) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 200),
          child: Icon(
            Icons.coffee,
            color: widget.mugColor,
            size: 150,
          ),
        ),
        DrivingTime(key: widget._myKey),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed:
              drivingAssistantNotifier.isAvailable && !onPause
                  ? () {
                drivingAssistantNotifier.isTracking
                    ? {this._drivingNotifier.stopTracking(widget),
                  widget._myKey.currentState?.stopTimer(),
                  onDrive = false}
                    : {this._drivingNotifier.startTracking(widget),
                  widget._myKey.currentState?.startTimer(),
                  onDrive = true};
              }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: !drivingAssistantNotifier.isTracking
                    ? Color(0xff77F2A1)
                    : Color(0xfff27777),
                foregroundColor: Colors.black,
              ),
              child: drivingAssistantNotifier.isTracking
                  ? const Text("Stop Driving")
                  : const Text("Start Driving"),
            ),
            SizedBox(width: 40.0),
            ElevatedButton(
              onPressed:
              drivingAssistantNotifier.isAvailable && onDrive
                  ? () {
                drivingAssistantNotifier.isTracking
                    ? {this._drivingNotifier.stopTracking(widget),
                  widget._myKey.currentState?.pauseTimer(),
                  onPause = true}
                    : {this._drivingNotifier.startTracking(widget),
                  widget._myKey.currentState?.pauseTimer(),
                  onPause = false};
              }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: !onPause
                    ? Color(0xff77F2A1)
                    : Color(0xfff27777),
                foregroundColor: Colors.black,
              ),
              child: onPause
                  ? const Text("Resume Driving")
                  : const Text("Pause Driving"),
            ),
          ],
        ),

        Visibility(
          visible: !drivingAssistantNotifier.isAvailable,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: Text(
            "No Earable Connected",
            style: TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          drivingAssistantNotifier.attitude.gyroY.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
