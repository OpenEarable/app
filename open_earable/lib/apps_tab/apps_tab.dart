import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/posture_tracker/model/earable_attitude_tracker.dart';
import 'package:open_earable/apps_tab/posture_tracker/view/posture_tracker_view.dart';
import 'package:open_earable/apps_tab/neck_stretch/view/stretch_app_view.dart';
import 'package:open_earable/apps_tab/step_counter/step_counter.dart';
import 'package:open_earable/apps_tab/tightness/tightness.dart';
import 'package:open_earable/apps_tab/recorder/lib/recorder.dart';
import 'package:open_earable/apps_tab/jump_height_test/jump_height_test.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import '../shared/global_theme.dart';
import 'package:open_earable/apps_tab/jump_rope_counter/jump_rope_counter.dart';
import 'powernapper/home_screen.dart';

class AppInfo {
  final String logoPath;
  final String title;
  final String description;
  final VoidCallback onTap;

  AppInfo({
    required this.logoPath,
    required this.title,
    required this.description,
    required this.onTap,
  });
}

class AppsTab extends StatelessWidget {
  final OpenEarable _openEarable;

  const AppsTab(this._openEarable, {super.key});

  List<AppInfo> sampleApps(BuildContext context) {
    return [
      AppInfo(
        logoPath: "lib/apps_tab/recorder/assets/logo.png",
        title: "Recorder",
        description: "Record data from OpenEarable",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Material(
                child: Theme(
                  data: materialTheme,
                  child: Recorder(_openEarable),
                ),
              ),
            ),
          );
        },
      ),
      AppInfo(
        logoPath: "lib/apps_tab/posture_tracker/assets/logo.png",
        //iconData: Icons.face_6,
        title: "Posture Tracker",
        description: "Get feedback on bad posture",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Material(
                child: Theme(
                  data: materialTheme,
                  child: PostureTrackerView(
                    EarableAttitudeTracker(_openEarable),
                    _openEarable,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      AppInfo(
        logoPath:
            "lib/apps_tab/jump_height_test/assets/logo.png", //Icons.height,
        title: "Jump Height Test",
        description: "Measure the height of your jumps",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Material(
                child: Theme(
                  data: materialTheme,
                  child: Material(
                    child: JumpHeightTest(_openEarable),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      AppInfo(
        logoPath: "lib/apps_tab/jump_rope_counter/assets/logo.png",
        //iconData: Icons.keyboard_double_arrow_up,
        title: "Jump Rope Counter",
        description: "Count your rope skips",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Material(
                child: Theme(
                  data: materialTheme,
                  child: JumpRopeCounter(_openEarable),
                ),
              ),
            ),
          );
        },
      ),
      AppInfo(
        logoPath: "lib/apps_tab/step_counter/assets/logo.png",
        title: "Step Counter",
        description: "Count your Steps",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Material(
                child: Theme(
                  data: materialTheme,
                  child: StepCounter(_openEarable),
                ),
              ),
            ),
          );
        },
      ),
      AppInfo(
        logoPath:
            "lib/apps_tab/powernapper/assets/logo.png", //iconData: Icons.face_5,
        title: "Powernapper",
        description: "Time starts when you're asleep",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Material(
                child: Theme(
                  data: materialTheme,
                  child: SleepHomeScreen(_openEarable),
                ),
              ),
            ),
          );
        },
      ),
      AppInfo(
        logoPath: "lib/apps_tab/tightness/assets/logo.png",
        //iconData: Icons.music_note,
        title: "Tightness Meter",
        description: "Practice your sense of rythm",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Material(
                child: Theme(
                  data: materialTheme,
                  child: TightnessMeter(_openEarable),
                ),
              ),
            ),
          );
        },
      ),
      AppInfo(
        logoPath: "lib/apps_tab/neck_stretch/assets/logo.png",
        title: "Guided Neck Stretch",
        description: "Relax your neck with a stretch.",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Material(
                child: Theme(
                  data: materialTheme,
                  child: StretchAppView(
                    EarableAttitudeTracker(_openEarable),
                    _openEarable,
                  ),
                ),
              ),
            ),
          );
        },
      ),
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
                iconColor: Colors.white,
                textColor: Colors.white,
                leading: SizedBox(
                  height: 50.0,
                  width: 50.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.asset(
                      apps[index].logoPath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                title: Text(apps[index].title),
                subtitle: Text(apps[index].description),
                trailing: Icon(Icons.arrow_forward_ios, size: 16.0),
                // Arrow icon on the right
                onTap: apps[index].onTap, // Callback when the card is tapped
              ),
            ),
          );
        },
      ),
    );
  }
}
