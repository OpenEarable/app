import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/apps/widgets/apps_page.dart';
import 'package:open_wearable/widgets/devices/devices_page.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_view.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_values_page.dart';

import 'sensors/sensor_page.dart';

/// The home page of the app.
///
/// The home page contains a tab bar and an AppBar.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static final titles = ["Devices", "Sensors", "Apps"];

  List<BottomNavigationBarItem> items(BuildContext context) {
    return [
      BottomNavigationBarItem(
        icon: Icon(Icons.devices),
        label: titles[0],
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.ssid_chart_rounded),
        label: titles[1],
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.apps_rounded),
        label: titles[2],
      ),
    ];
  }

  late PlatformTabController _controller;

  late List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _controller = PlatformTabController(initialIndex: 0);
    _tabs = [
      DevicesPage(),
      SensorPage(),
      const AppsPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return _buildSmallScreenLayout(context);
        } else {
          return _buildLargeScreenLayout(context);
        }
      },
    );
  }

  Widget _buildLargeScreenLayout(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText("OpenWearable"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: ListView(
          children: [
            PlatformText(
              "Connected Devices",
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.surfaceTint),
            ),
            DevicesPage(),
            PlatformText(
              "Sensor Configuration",
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.surfaceTint),
            ),
            SensorConfigurationView(),
            PlatformText(
              "Sensor Values",
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.surfaceTint),
            ),
            SensorValuesPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallScreenLayout(BuildContext context) {
    return PlatformTabScaffold(
      tabController: _controller,
      bodyBuilder: (context, index) => IndexedStack(
        index: index,
        children: _tabs,
      ),
      items: items(context),
    );
  }
}
