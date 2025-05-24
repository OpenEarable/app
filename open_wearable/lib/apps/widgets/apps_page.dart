import 'package:flutter/cupertino.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/heart_tracker/widgets/heart_tracker_page.dart';
import 'package:open_wearable/apps/posture_tracker/model/earable_attitude_tracker.dart';
import 'package:open_wearable/apps/posture_tracker/view/posture_tracker_view.dart';
import 'package:open_wearable/apps/widgets/select_earable_view.dart';
import 'package:open_wearable/apps/widgets/app_tile.dart';

class AppInfo {
  final String logoPath;
  final String title;
  final String description;
  final Widget widget;

  AppInfo({
    required this.logoPath,
    required this.title,
    required this.description,
    required this.widget,
  });
}

List<AppInfo> _apps = [
  AppInfo(
    logoPath: "lib/apps/posture_tracker/assets/logo.png",
    title: "Posture Tracker",
    description: "Get feedback on bad posture",
    widget: SelectEarableView(startApp: (wearable, sensorConfigProvider) {
      return PostureTrackerView(
        EarableAttitudeTracker(
          wearable as SensorManager,
          sensorConfigProvider,
          wearable.name.endsWith("L")
        )
      );
    }),
  ),
  AppInfo(
    logoPath: "lib/apps/heart_tracker/assets/logo.png",
    title: "Heart Tracker",
    description: "Track your heart rate and other vitals",
    widget: SelectEarableView(
      startApp: (wearable, _) {
        if (wearable is SensorManager) {
          //TODO: show alert if no ppg sensor is found
          Sensor ppgSensor = (wearable as SensorManager).sensors.firstWhere(
            (s) => s.sensorName.toLowerCase() == "photoplethysmography".toLowerCase()
          );

          return HeartTrackerPage(ppgSensor: ppgSensor);
        }
        return PlatformScaffold(
          appBar: PlatformAppBar(
            title: Text("Heart Tracker"),
          ),
          body: Center(
            child: Text("No PPG Sensor Found"),
          ),
        );
      }
    ),
  )
];

class AppsPage extends StatelessWidget {
  const AppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(10),
      child: ListView.builder(
        itemCount: _apps.length,
        itemBuilder: (context, index) {
          return AppTile(app: _apps[index]);
        },
      )
    );
  }
}
