import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/apps/posture_tracker/model/earable_attitude_tracker.dart';
import 'package:open_earable/apps/posture_tracker/view/posture_tracker_view.dart';
import 'package:open_earable/apps/tightness.dart';
import 'package:open_earable/apps/recorder/lib/recorder.dart';
import 'package:open_earable/apps/jump_height_test/jump_height_test.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'global_theme.dart';
import 'package:open_earable/apps/jump_rope_counter.dart';
import 'apps/powernapper/home_screen.dart';

class AppInfo {
  final String logoPath;
  final String title;
  final String description;
  final VoidCallback onTap;

  AppInfo(
      {required this.logoPath,
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
          logoPath: "lib/apps/recorder/assets/REC.png",
          title: "Recorder",
          description: "Record data from OpenEarable.",
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => Material(
                        child: Theme(
                            data: materialTheme,
                            child: Recorder(_openEarable)))));
          }),
      AppInfo(
          logoPath:
              "lib/apps/posture_tracker/assets/logo.png", //iconData: Icons.face_6,
          title: "Posture Tracker",
          description: "Get feedback on bad posture.",
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => Material(
                        child: Theme(
                            data: materialTheme,
                            child: PostureTrackerView(
                                EarableAttitudeTracker(_openEarable),
                                _openEarable)))));
          }),
      AppInfo(
          logoPath: "lib/apps/recorder/assets/REC.png", //Icons.height,
          title: "Jump Height Test",
          description: "Test your maximum jump height.",
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => Material(
                        child: Theme(
                            data: materialTheme,
                            child: Material(
                                child: JumpHeightTest(_openEarable))))));
          }),
      AppInfo(
          logoPath:
              "lib/apps/recorder/assets/REC.png", //iconData: Icons.keyboard_double_arrow_up,
          title: "Jump Rope Counter",
          description: "Counter for rope skipping.",
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => Material(
                        child: Theme(
                            data: materialTheme,
                            child: JumpRopeCounter(_openEarable)))));
          }),
      AppInfo(
          logoPath:
              "lib/apps/recorder/assets/REC.png", //iconData: Icons.face_5,
          title: "Powernapper Alarm Clock",
          description: "Powernapping timer!",
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => Material(
                        child: Theme(
                            data: materialTheme,
                            child: SleepHomeScreen(_openEarable)))));
          }),
      AppInfo(
          logoPath:
              "lib/apps/recorder/assets/REC.png", //iconData: Icons.music_note,
          title: "Tightness Meter",
          description: "Track your headbanging.",
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => Material(
                        child: Theme(
                            data: materialTheme,
                            child: TightnessMeter(_openEarable)))));
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
                  color: Platform.isIOS
                      ? CupertinoTheme.of(context).primaryContrastingColor
                      : Theme.of(context).colorScheme.primary,
                  child: ListTile(
                    iconColor: Colors.white,
                    textColor: Colors.white,
                    leading: SizedBox(
                        height: 50.0,
                        width: 50.0,
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.asset(apps[index].logoPath,
                                fit: BoxFit.cover))),
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
