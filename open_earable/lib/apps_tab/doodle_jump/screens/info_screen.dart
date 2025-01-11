import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/doodle_jump/widgets/top_bar.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

/// A screen that displays information about the Doodle Jump app and provides
/// options to view controls or test the OpenEarable device.
///
/// The [InfoScreen] has two main states:
/// - `_showControls`: Displays the control view with an animated icon.
/// - `_showTest`: Displays the test view with a bar that moves based on sensor data.
///
/// The [InfoScreen] class contains the following methods:
/// - `initState`: Initializes the animation controller and starts the animation.
/// - `dispose`: Disposes the animation controller.
/// - `build`: Builds the UI of the screen.
/// - `_getTestView`: Returns the widget for the test view.
/// - `_getControlView`: Returns the widget for the control view.
/// - `_buildTestBar`: Builds the bar widget for the test view that moves based on sensor data.
class InfoScreen extends StatefulWidget {
  final OpenEarable openEarable;

  const InfoScreen(this.openEarable, {super.key});

  @override
  InfoScreenState createState() => InfoScreenState();
}

class InfoScreenState extends State<InfoScreen>
    with SingleTickerProviderStateMixin {
  bool _showControls = false;
  bool _showTest = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  double roll = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animation = Tween<double>(begin: -0.8, end: 0.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _controller.forward();
        }
      });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _showControls
                    ? <Widget>[_getControlView()]
                    : _showTest
                        ? <Widget>[_getTestView()]
                        : <Widget>[
                            const SizedBox(height: 10),
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.blue,
                              child: ClipOval(
                                child: Image.asset(
                                  'lib/apps_tab/doodle_jump/assets/player.png',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Welcome to Doodle Jump! \nUse the OpenEarable device to control your character and jump to new heights.',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'This Sub-App was developed by:\nUnbekannt',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _showControls = true;
                                    });
                                  },
                                  child: const Text('Steuerung'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _showTest = true;
                                    });
                                    if (widget
                                        .openEarable.bleManager.connected) {
                                      widget.openEarable.sensorManager
                                          .subscribeToSensorData(0)
                                          .listen((data) {
                                        setState(() {
                                          roll = data["EULER"]["ROLL"];
                                        });
                                      });
                                    }
                                  },
                                  child: const Text('Test'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getTestView() {
    return Column(
      children: [
        const Text(
          'Test mode:\n Tilt your head left or right',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Stack(
          children: [
            TopBar(openEarable: widget.openEarable),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _showTest = false;
            });
          },
          child: const Text('Zurück'),
        ),
      ],
    );
  }

  Widget _getControlView() {
    return Column(
      children: [
        const Text(
          'Tilt your head left or right \nto move the player.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _animation.value,
              child: const Icon(
                Icons.face,
                size: 100,
                color: Colors.blue,
              ),
            );
          },
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _showControls = false;
            });
          },
          child: const Text('Zurück'),
        ),
      ],
    );
  }
}
