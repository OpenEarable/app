import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/widgets/devices/connect_devices_page.dart';
import 'package:open_wearable/widgets/devices/devices_page.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_view.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_values_page.dart';

/// The home page of the app.
/// 
/// The home page contains a tab bar and an AppBar.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static final titles = ["Devices", "Sensors"];
  
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
      SensorConfigurationView(),
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
        title: Text("OpenWearable"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: ListView(
          children: [
            Text(
              "Connected Devices",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.surfaceTint),
            ),
            DevicesPage(),
            Text(
              "Sensor Configuration",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.surfaceTint),
            ),
            SensorConfigurationView(),
            Text(
              "Sensor Values",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.surfaceTint),
            ),
            SensorValuesPage(),
          ],
        )
      )
    );
  }

  Widget _buildSmallScreenLayout(BuildContext context) {
    return PlatformTabScaffold(
      tabController: _controller,
      appBarBuilder: (context, index) => PlatformAppBar(
        title: Text(titles[index]),
        trailingActions: [
            PlatformIconButton(
            icon: Icon(context.platformIcons.bluetooth),
            onPressed: () {
              if (Theme.of(context).platform == TargetPlatform.iOS) {
                showCupertinoModalPopup(
                  context: context,
                  builder: (context) => ConnectDevicesPage(),
                );
              } else {
                Navigator.of(context).push(
                  platformPageRoute(
                    context: context,
                    builder: (context) => const Material(
                      child: ConnectDevicesPage(),
                    ),
                  )
                );
              }
            }
          ),
        ]
      ),
      bodyBuilder: (context, index) => IndexedStack(
        index: index,
        children: _tabs,
      ),
      items: items(context),
    );
  }
}
