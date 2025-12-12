import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/audio_response_measure/audio_response_measurement_view.dart';
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
          wearable.requireCapability<SensorManager>(),
          sensorConfigProvider,
          wearable.name.endsWith("L"),
        ),
      );
    },),
  ),
  AppInfo(
    logoPath: "lib/apps/heart_tracker/assets/logo.png",
    title: "Heart Tracker",
    description: "Track your heart rate and other vitals",
    widget: SelectEarableView(
      startApp: (wearable, _) {
        if (wearable.hasCapability<SensorManager>()) {
          //TODO: show alert if no ppg sensor is found
          Sensor ppgSensor = wearable.requireCapability<SensorManager>().sensors.firstWhere(
            (s) => s.sensorName.toLowerCase() == "photoplethysmography".toLowerCase(),
          );

          return HeartTrackerPage(ppgSensor: ppgSensor);
        }
        return PlatformScaffold(
          appBar: PlatformAppBar(
            title: PlatformText("Heart Tracker"),
          ),
          body: Center(
            child: PlatformText("No PPG Sensor Found"),
          ),
        );
      },
    ),
  ),
  AppInfo(
    logoPath: "",
    title: "Audio Response",
    description: "Measure and store audio responses",
    widget: SelectEarableView(
      startApp: (wearable, _) {
        if (wearable is AudioResponseManager) {
          return AudioResponseMeasurementView(manager: wearable as AudioResponseManager);
        } else {
          return PlatformScaffold(
            appBar: PlatformAppBar(
              title: PlatformText("Audio Response Measurement"),
            ),
            body: Center(
              child: PlatformText("Audio Response Measurement not supported on this device."),
            ),
          );
        }
      },
    ),
  ),
];

class AppsPage extends StatelessWidget {
  const AppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText("Apps"),
        trailingActions: [
            PlatformIconButton(
            icon: Icon(context.platformIcons.bluetooth),
            onPressed: () {
              context.push('/connect-devices');
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(10),
        child: ListView.builder(
          itemCount: _apps.length,
          itemBuilder: (context, index) {
            return AppTile(app: _apps[index]);
          },
        ),
      ),
    );
  }
}
