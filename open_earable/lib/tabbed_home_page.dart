import 'dart:async';
import 'package:flutter/material.dart';
import 'package:open_earable/ble/ble_tab_bar_page.dart';
import 'package:open_earable/controls_tab/models/open_earable_settings_v2.dart';
import 'package:open_earable/shared/open_earable_icon_icons.dart';
import 'package:provider/provider.dart';
import 'controls_tab/controls_tab.dart';
import 'sensor_data_tab/sensor_data_tab.dart';
import 'package:open_earable/ble/ble_controller.dart';
import 'apps_tab/apps_tab.dart';
import 'shared/global_theme.dart';

class TabbedHomePage extends StatefulWidget {
  const TabbedHomePage({super.key});

  @override
  State<TabbedHomePage> createState() => _TabbedHomePageState();
}

class _TabbedHomePageState extends State<TabbedHomePage> {
  int _selectedIndex = 0;
  late bool alertOpen;
  late List<Widget> _widgetOptions;
  StreamSubscription? blePermissionSubscription;

  @override
  void initState() {
    super.initState();
    alertOpen = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!alertOpen) {
      Provider.of<BluetoothController>(context, listen: false).setupListeners();
    }
    _widgetOptions = <Widget>[
      ControlTab(),
      Material(child: Theme(data: materialTheme, child: SensorDataTab())),
      AppsTab(
        Provider.of<BluetoothController>(context).openEarableLeft,
      ), // TODO support two earables for apps
    ];
  }

  @override
  void dispose() {
    super.dispose();
    blePermissionSubscription?.cancel();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 50),
              Image.asset(
                'assets/earable_logo.png',
                width: 24,
                height: 24,
              ),
              SizedBox(width: 8),
              Text('OpenEarable'),
            ],
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.bluetooth,
              color: Theme.of(context).colorScheme.secondary,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => BLETabBarPage(
                    index: OpenEarableSettingsV2().selectedButtonIndex,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 3.0),
              child: Icon(
                OpenEarableIcon.icon,
                size: 20.0,
              ),
            ),
            label: 'Controls',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart_outlined),
            label: 'Sensor Data',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apps),
            label: 'Apps',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
