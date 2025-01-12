import 'package:flutter/material.dart';
import '../model/breathing_session_model.dart';

/// A [SettingsView] widget that provides customization options for the Breathing Assistant app.
///
/// ### Features:
/// - Adjust the breathing session duration using radio buttons.
/// - Toggle between light and night mode.
/// - Save the settings to the [BreathingSessionModel] and return to the main page.
class SettingsView extends StatefulWidget {
  /// The [BreathingSessionModel] instance that stores session data and settings.
  final BreathingSessionModel model;

  /// Constructor for the [SettingsView].
  ///
  /// Takes a required [model] parameter to manage and persist settings.
  const SettingsView(this.model, {super.key});

  @override
  _SettingsViewState createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late int _selectedDuration; // Selected duration for the breathing session in minutes.
  bool _isNightMode = false; // State variable for the night mode toggle.

  @override
  void initState() {
    super.initState();
    // Initialize the state with values from the model.
    _selectedDuration = widget.model.sessionDuration ~/ 60; // Convert duration to minutes.
    _isNightMode = widget.model.isNightMode;
  }

  @override
  Widget build(BuildContext context) {
    // Determine if the device is in landscape orientation.
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Navigate back to the previous screen.
          },
        ),
      ),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment:
                  isLandscape ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                // Card to select the breathing session duration.
                _buildCard(
                  title: "Select Breathing Session Duration",
                  child: Column(
                    children: [4, 6, 10, 12].map((duration) {
                      return RadioListTile<int>(
                        activeColor: const Color(0xFF8FBFE0),
                        title: Text(
                          "$duration minutes",
                          style: const TextStyle(color: Colors.white),
                        ),
                        value: duration,
                        groupValue: _selectedDuration,
                        onChanged: (value) {
                          setState(() {
                            _selectedDuration = value!;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Card to toggle night mode.
                _buildCard(
                  title: "Enable Night Mode",
                  child: SwitchListTile(
                    activeColor: const Color(0xFF8FBFE0),
                    title: const Text(
                      "Night Mode",
                      style: TextStyle(color: Colors.white),
                    ),
                    value: _isNightMode,
                    onChanged: (value) {
                      setState(() {
                        _isNightMode = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Save button to persist settings and return to the main page.
                ElevatedButton(
                  onPressed: () {
                    // Save the updated settings to the model.
                    widget.model.sessionDuration = _selectedDuration * 60; // Convert to seconds.
                    widget.model.isNightMode = _isNightMode;

                    // Navigate back to the main page.
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 20,
                    ),
                    backgroundColor: const Color(0xFF8FBFE0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: const Text(
                    "Save",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Helper method to create styled cards for each setting option.
  ///
  /// Takes a [title] for the card header and a [child] widget for the card content.
  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      color: const Color.fromARGB(255, 30, 34, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
