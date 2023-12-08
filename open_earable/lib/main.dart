import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:open_earable/open_earable_icon_icons.dart';
import 'controls_tab/controls_tab.dart';
import 'sensor_data_tab/sensor_data_tab.dart';
import 'ble.dart';
import 'apps_tab.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_earable/controls_tab/models/open_earable_settings.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '🦻 OpenEarable',
      theme: ThemeData(
          useMaterial3: false,
          colorScheme: ColorScheme(
              brightness: Brightness.dark,
              primary: Color.fromARGB(255, 22, 22, 24),
              onPrimary: Colors.white,
              secondary: Color.fromARGB(255, 119, 242, 161),
              onSecondary: Colors.white,
              error: Colors.red,
              onError: Colors.black,
              background: Color.fromARGB(255, 54, 53, 59),
              onBackground: Colors.white,
              surface: Color.fromARGB(255, 22, 22, 24),
              onSurface: Colors.white),
          secondaryHeaderColor: Colors.black),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  late OpenEarable _openEarable;

  late List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _checkBLEPermission();
    _openEarable = OpenEarable();
    _widgetOptions = <Widget>[
      ControlTab(_openEarable),
      SensorDataTab(_openEarable),
      AppsTab(_openEarable),
    ];
  }

  Future<void> _checkBLEPermission() async {
    PermissionStatus status = await Permission.bluetoothConnect.request();
    PermissionStatus status2 = await Permission.location.request();
    PermissionStatus status3 = await Permission.bluetoothScan.request();
    if (status.isGranted) {
      print("BLE is working");
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Center(
            child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 50),
            Image.asset(
              'assets/earable_logo.png', // Replace with your image path
              width: 24, // Adjust the width as needed
              height: 24, // Adjust the height as needed
            ),
            SizedBox(width: 8), // Add spacing between the image and text
            Text('OpenEarable'),
          ],
        )),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.bluetooth,
                color: Theme.of(context).colorScheme.secondary),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => BLEPage(_openEarable)));
            },
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(
                  bottom:
                      3.0), // Adjust the bottom padding to your desired value
              child: Icon(
                OpenEarableIcon.icon,
                size: 20.0, // Change the size to your desired value
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
