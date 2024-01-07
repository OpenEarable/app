import 'package:flutter/material.dart';
import 'package:open_earable/apps/posture_tracker/model/earable_attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/view/posture_tracker_view.dart';
import 'package:open_earable/apps/recorder.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'apps/endless_runner/view/endless_runner_view.dart';
import 'apps/endless_runner/model/earable_attitude_tracker.dart' as earable_attitude_tracker_endless_runner;


class AppInfo {
  final IconData iconData;
  final String title;
  final String description;
  final VoidCallback onTap;

  AppInfo(
      {required this.iconData,
        required this.title,
        required this.description,
        required this.onTap});
}

class AppsTab extends StatelessWidget {
  final OpenEarable _openEarable;

  AppsTab(this._openEarable);

  List<AppInfo> sampleApps(BuildContext context) {
    return [
      AppInfo(
          iconData: Icons.face_6,
          title: "Posture Tracker",
          description: "Get feedback on bad posture.",
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => PostureTrackerView(
                        EarableAttitudeTracker(_openEarable), _openEarable)));
          }),
      AppInfo(
          iconData: Icons.fiber_smart_record,
          title: "Recorde",
          description: "Record data from OpenEarable.",
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => Recorder(_openEarable)));
          }),
      AppInfo(
          iconData: Icons.follow_the_signs,
          title: "Endless Runner",
          description: "Get as far as possible.",
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => EndlessRunnerView(earable_attitude_tracker_endless_runner.EarableAttitudeTracker(_openEarable), _openEarable)));
          }),
      // ... similarly for other apps
    ];
  }

  @override
  Widget build(BuildContext context) {
    List<AppInfo> apps = sampleApps(context);

    return Padding(
        padding: const EdgeInsets.only(top: 5),
        child: ListView.builder(
          itemCount: apps.length,
          itemBuilder: (BuildContext context, int index) {
            return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Card(
                  color: Theme.of(context).colorScheme.primary,
                  child: ListTile(
                    leading: Icon(apps[index].iconData, size: 40.0),
                    title: Text(apps[index].title),
                    subtitle: Text(apps[index].description),
                    trailing: Icon(Icons.arrow_forward_ios,
                        size: 16.0), // Arrow icon on the right
                    onTap:
                    apps[index].onTap, // Callback when the card is tapped
                  ),
                ));
          },
        ));
  }
}
