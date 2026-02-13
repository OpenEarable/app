import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:open_wearable/widgets/recording_activity_indicator.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_view.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_view.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_values_page.dart';

class SensorPage extends StatelessWidget {
  const SensorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: PlatformScaffold(
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return [
              SliverAppBar(
                title: PlatformText("Sensors"),
                actions: [
                  const AppBarRecordingIndicator(),
                  PlatformIconButton(
                    icon: Icon(context.platformIcons.bluetooth),
                    onPressed: () {
                      context.push('/connect-devices');
                    },
                  ),
                ],
                pinned: true,
                floating: true,
                snap: true,
                forceElevated: innerBoxIsScrolled,
                bottom: TabBar(
                  tabs: [
                    const Tab(text: 'Configure'),
                    const Tab(text: 'Live Data'),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const RecordingActivityIndicator(size: 14),
                          const SizedBox(width: 4),
                          PlatformText('Recorder'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              Builder(
                builder: (tabCtx) => SensorConfigurationView(
                  onSetConfigPressed: () {
                    DefaultTabController.of(tabCtx).animateTo(1);
                  },
                ),
              ),
              SensorValuesPage(),
              LocalRecorderView(),
            ],
          ),
        ),
      ),
    );
  }
}
