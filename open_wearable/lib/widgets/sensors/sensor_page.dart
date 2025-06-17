import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_view.dart';
import 'package:open_wearable/widgets/sensors/local_recorder/local_recorder_view.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_values_page.dart';
import 'package:provider/provider.dart';

import '../../view_models/sensor_recorder_provider.dart';


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
                title: const Text("Sensors"),
                pinned: true,
                floating: true,
                snap: true,
                forceElevated: innerBoxIsScrolled,
                bottom: TabBar(
                  tabs: const [
                    Tab(text: 'Configuration'),
                    Tab(text: 'Charts'),
                    Tab(
                      child: Row(
                        children: [
                          _RecordingIndicator(),
                          Text('Recorder'),
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

class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator();

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorRecorderProvider>(
      builder: (context, recorderProvider, child) {
        return Icon(
          recorderProvider.isRecording ? Icons.fiber_manual_record : Icons.fiber_manual_record_outlined,
          color: recorderProvider.isRecording ? Colors.red : Colors.grey,
        );
      },
    );
  }
}
