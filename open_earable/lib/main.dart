import 'package:flutter/material.dart';
import 'now_playing_tab.dart';
import 'sensor_data_tab.dart';
import 'ble.dart';
import 'apps_tab.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '🦻 OpenEarable',
      theme: ThemeData(primarySwatch: Colors.brown),
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
    _openEarable = OpenEarable();
    _widgetOptions = <Widget>[
      NowPlayingTab(),
      SensorDataTab(_openEarable),
      AppsTab(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🦻 OpenEarable'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.bluetooth),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => BLEPage(_openEarable)));
            },
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'Now Playing',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sensors),
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
