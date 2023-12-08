import 'package:flutter/material.dart';
import 'package:open_earable/apps/driving_assistant/controller/tiredness_monitor.dart';
import 'package:open_earable/apps/driving_assistant/view/observer.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:provider/provider.dart';
import 'package:open_earable/apps/driving_assistant/driving_assistant_notifier.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';


class DrivingAssistantView extends StatefulWidget implements Observer {

  final AttitudeTracker _tracker;
  final OpenEarable _openEarable;
  Color mugColor = Colors.white;

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

  @override
  void initState() {
    super.initState();
    this._drivingNotifier = DrivingAssistantNotifier(widget._tracker, new TirednessMonitor(widget._openEarable, widget._tracker));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DrivingAssistantNotifier>(
        create: (_) => _drivingNotifier,
        builder: (context, child) => Consumer<DrivingAssistantNotifier>(
            builder: (context, drivingAssistantNotifier, child) => Scaffold(
              appBar: AppBar(
                title: const Text("Driving Assistant"),
              ),
              body: Center(
                child: this._buildContentView(drivingAssistantNotifier),
              ),
            )
        )
    );
  }

  Widget _buildContentView(DrivingAssistantNotifier drivingAssistantNotifier){
    return Column(children: [
      Padding(
          padding: const EdgeInsets.only(top: 200),
        child: Icon(
          Icons.coffee,
          color: widget.mugColor,
          size: 150,
        ),
      ),
      ElevatedButton(
        onPressed: drivingAssistantNotifier.isAvailable
            ? () { drivingAssistantNotifier.isTracking ? this._drivingNotifier.stopTracking(widget) : this._drivingNotifier.startTracking(widget); }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: !drivingAssistantNotifier.isTracking ? Color(0xff77F2A1) : Color(0xfff27777),
          foregroundColor: Colors.black,
        ),
        child: drivingAssistantNotifier.isTracking ? const Text("Stop Tracking") : const Text("Start Tracking"),
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
      )
    ]);
  }

}
