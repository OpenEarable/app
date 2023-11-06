import 'package:flutter/material.dart';
import 'package:open_earable/apps/posture_tracker/model/earable_attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/model/mock_attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/view/posture_tracker_view.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

import './apps/step_counter.dart';

class AppInfo {
  final IconData iconData;
  final String title;
  final String description;
  final void Function(BuildContext, OpenEarable) onTap;

  AppInfo(
    {
      required this.iconData,
      required this.title,
      required this.description,
      required this.onTap
    }
  );
}

List<AppInfo> sampleApps = [
  AppInfo(
      iconData: Icons.directions_walk,
      title: "Step Counter",
      description: "Counts number of steps taken.",
      onTap: (_, openEarable) {
        // Action when the card is tapped, for example:
        // Navigator.push(context, MaterialPageRoute(builder: (context) => PostureTracker()));
      }),
  AppInfo(
      iconData: Icons.face_6,
      title: "Posture Tracker",
      description: "Get feedback on bad posture.",
      onTap: (context, OpenEarable openEarable) {
        // Action when the card is tapped, for example:
        Navigator.push(context, MaterialPageRoute(builder: (context) => PostureTrackerView(EarableAttitudeTracker(openEarable))));
      }),
  AppInfo(
      iconData: Icons.lunch_dining,
      title: "Asissted Dietary Monitoring",
      description: "Detect eating episodes.",
      onTap: (_, openEarable) {
        // Action when the card is tapped, for example:
        // Navigator.push(context, MaterialPageRoute(builder: (context) => PostureTracker()));
      }),
  AppInfo(
      iconData: Icons.height,
      title: "Jump Height Test",
      description: "Test your maximum jump height.",
      onTap: (_, openEarable) {
        // Action when the card is tapped, for example:
        // Navigator.push(context, MaterialPageRoute(builder: (context) => PostureTracker()));
      }),
  // ... similarly for other apps
];

class AppsTab extends StatelessWidget {
  final OpenEarable _openEarable;

  AppsTab(this._openEarable);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: sampleApps.length,
      itemBuilder: (BuildContext context, int index) {
        return Card(
          color: Theme.of(context).colorScheme.primary,
          margin: EdgeInsets.all(8.0),
          child: ListTile(
            leading: Icon(sampleApps[index].iconData, size: 40.0),
            title: Text(sampleApps[index].title),
            subtitle: Text(sampleApps[index].description),
            trailing: Icon(Icons.arrow_forward_ios,
                size: 16.0), // Arrow icon on the right
            onTap: () { sampleApps[index].onTap(context, _openEarable); }, // Callback when the card is tapped
          ),
        );
      },
    );
  }
}
