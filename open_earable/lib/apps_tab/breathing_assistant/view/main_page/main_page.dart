import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import '../breathing_session/breathing_session_view.dart';
import '../settings_view.dart';
import '../tutorial_view.dart';
import 'menu_button.dart';
import '../../model/breathing_session_model.dart';
import '../../model/breathing_sensor_tracker.dart';
import 'package:open_earable/shared/earable_not_connected_warning.dart';

/// A [MainPage] widget that serves as the central navigation hub for the
/// Breathing Assistant application.
///
/// This page provides the following options:
/// 1. Start a breathing exercise.
/// 2. Access a tutorial on how to use the app.
/// 3. Open the settings for customization.
///
/// The [MainPage] initializes a [BreathingSessionModel] and configures sensors
/// on launch if the device is connected.
class MainPage extends StatelessWidget {
  /// The OpenEarable instance used for managing BLE connections and data.
  final OpenEarable openEarable;

  /// The model for managing breathing sessions and related state.
  final BreathingSessionModel model;

  /// Constructor for the [MainPage].
  ///
  /// Initializes the [model] and sets up the sensor tracker if the device is connected.
  MainPage(this.openEarable, {super.key})
      : model = BreathingSessionModel() {

    model.sensorTracker = BreathingSensorTracker(openEarable);

    // Configure sensors on launch if connected
    if (openEarable.bleManager.connected) {
      model.sensorTracker?.configureSensors();
    } else {
      print("Device not connected. Cannot configure sensors.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The top AppBar with a back button and page title.
      appBar: AppBar(
        title: const Text("Breathing Assistant"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      // Main body of the page
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 38, 38, 38),
              Color.fromARGB(255, 70, 78, 88),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Button to start a breathing exercise.
              MenuButton(
                label: 'Start Breathing Exercise',
                icon: Icons.play_circle,
                color: const Color(0xFF8FBFE0),
                onPressed: () {
                  if (openEarable.bleManager.connected) {
                    // Configure sensors before starting the session
                    model.sensorTracker?.configureSensors();

                    // Show a dialog for position selection
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        title: const Center(
                          child: Text(
                            'Select Position',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        content: const Text(
                          'Are you sitting or lying down for this exercise?',
                          textAlign: TextAlign.center,
                        ),
                        actionsAlignment: MainAxisAlignment.spaceEvenly,
                        actions: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BreathingSessionView(
                                    model,
                                    positionMode: 'sitting',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Sitting'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BreathingSessionView(
                                    model,
                                    positionMode: 'lying',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Lying Down'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Navigate to the error screen if the device is not connected.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(
                            title: const Text("Error"),
                            leading: IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                            ),
                          ),
                          body: const Center(
                            child: EarableNotConnectedWarning(),
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 20),

              // Button to navigate to the tutorial screen.
              MenuButton(
                label: 'How to Use',
                icon: Icons.help,
                color: const Color.fromARGB(255, 207, 187, 171),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HowToUseScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Button to navigate to the settings screen.
              MenuButton(
                label: 'Settings',
                icon: Icons.settings,
                color: const Color.fromARGB(255, 186, 195, 209),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsView(model),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
