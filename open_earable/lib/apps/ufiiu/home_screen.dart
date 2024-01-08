import 'package:flutter/material.dart';
import 'package:open_earable/apps/ufiiu/timerscreen.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';

import 'interact.dart';


/// Homescreen class for the movement timer application.
class SleepHomeScreen extends StatefulWidget {
  final OpenEarable _openEarable;
  SleepHomeScreen(this._openEarable);
  @override
  _HomeScreenState createState() => _HomeScreenState(_openEarable);
}

/// State for the HomeScreenApplication.
///
/// Needs the [OpenEarable]-Object to interact.
class _HomeScreenState extends State<SleepHomeScreen> {

  final OpenEarable _openEarable;

  //Constructor
  _HomeScreenState(this._openEarable);

  //Bottom-Navigation-Bar index.
  int _currentIndex = 0;



  //Build main Widget.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Timer App'),
      ),

      //Body for the widget
      body: _getBody(),

      //Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavBarItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Timer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info),
            label: 'Info',
          ),
        ],
      ),
    );
  }

  ///Body-Widget for Main Widget.
  Widget _getBody() {
    switch (_currentIndex) {
      case 0:

        //HomeScreenTab
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              //Image-Source
              Text(
                'Mit der Powernapping App können Sie einen Timer starten, der ganz automatisch an Ihren Bewegungen erkennt, '
                    'wann Sie wirklich eingeschlafen sind. Der Timer wird automatisch restartet, wenn Sie sich bewegen, '
                    'so können Sie effektiv powernappen und eine gemütliche Position finden ohne das schon die Zeit abläuft!',
                style: TextStyle(fontSize: 24),
              ),
              SizedBox(height: 20),
            ],
          )
        );
      case 1:

        //Timer Tab
        return Center(
          child: Text('Wird weitergeleitet...')
        );
      case 2:

        //Information Tab
        return Center(
          child: Text('Diese Sub-App wurde entwickelt von: Philipp Ochs, Matrikelnummer 2284828'),
        );
      default:

        //Default
        return Center(
          child: Text('Ungültiger Index'),
        );

    }
    return Container();
  }

  ///Navigation-Bar interaction
  ///
  /// [Index] is the tab index activated.
  void _onNavBarItemTapped(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 1) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TimerScreen(Interact(_openEarable)),
          ),
        );
      }
    });
  }
}