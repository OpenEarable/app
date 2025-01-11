import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

/// A widget that represents a top bar with a moving indicator based on sensor data.
///
/// The [TopBar] widget displays a top bar with a moving red indicator that
/// shifts based on the roll value received from the connected OpenEarable device.
/// It also displays labels "Left", "0", and "Right" to indicate the position
/// of the indicator.
///
/// The [TopBarState] class handles the state management and UI updates for the
/// [TopBar] widget. It subscribes to sensor data from the [OpenEarable] device
/// and updates the roll value, which in turn updates the position of the red
/// indicator in the top bar.
class TopBar extends StatefulWidget {
  final OpenEarable openEarable;

  const TopBar({super.key, required this.openEarable});

  @override
  TopBarState createState() => TopBarState();
}

class TopBarState extends State<TopBar> {
  double roll = 0.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.black.withValues(alpha: 0.5),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 5,
            spreadRadius: 2,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double maxOffset = (constraints.maxWidth - 10) / 2;
          double offset = (roll * maxOffset).clamp(-maxOffset, maxOffset);

          return Stack(
            children: [
              Center(
                child: Transform.translate(
                  offset: Offset(offset, 0),
                  child: Container(
                    width: 10,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                child: Text(
                  'Left',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 2,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: Text(
                  '0',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 2,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 10,
                child: Text(
                  'Right',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 2,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loadSensor();
  }

  void loadSensor() {
    if (widget.openEarable.bleManager.connected) {
      widget.openEarable.sensorManager.subscribeToSensorData(0).listen((data) {
        setState(() {
          roll = data["EULER"]["ROLL"];
        });
      });
    }
  }
}
