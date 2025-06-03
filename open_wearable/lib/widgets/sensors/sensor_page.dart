import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_view.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_values_page.dart';


class SensorPage extends StatelessWidget {
  const SensorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
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
            ],
          ),
        ),
      ),
    );
  }
}
