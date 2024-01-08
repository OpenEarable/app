import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  final TextEditingController stoppedTimeController;
  final TextEditingController countedStepsController;

  SettingsPage(this.stoppedTimeController, this.countedStepsController);

  /**
   * Erstellt die Grundstruktur der Einstellungsseite.
   */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text('Developer-Settings'),
      ),
      body: SafeArea(
        child: _StepCounterSettingWidget(
          stoppedTimeController: stoppedTimeController,
          countedStepsController: countedStepsController,
        ),
      ),
    );
  }
}

class _StepCounterSettingWidget extends StatelessWidget {
  final TextEditingController stoppedTimeController;
  final TextEditingController countedStepsController;

  _StepCounterSettingWidget({
    required this.stoppedTimeController,
    required this.countedStepsController,
  });

  /**
   * Die Funktion stellt ein Einstellungswidget bereit, dieses ermöglicht die Bearbeitung der Werte des Schrittzählers ohne Eareable,
   * somit kann die App sogar ohne Earable weiterentwickelt werden.
   */
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTextField(
              "Stopped Time", stoppedTimeController, TextInputType.datetime),
          _buildTextField(
              "Counted Steps", countedStepsController, TextInputType.text),
          ElevatedButton(
            onPressed: () {
              // Hier wird eine Map erstellt zur Übertragung der in den Einstellungen gesetzten Werten.
              Map<String, String> updatedValues = {
                'stoppedTime': stoppedTimeController.text,
                'countedSteps': countedStepsController.text,
              };

              // Hier werden die Werte an die App übergeben
              Navigator.pop(context, updatedValues);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  /**
   * Erstellt aus einem Bezeichner, einem Controller und einem Typ des Textinputs ein Textfeld
   */
  Widget _buildTextField(
      String labelText, TextEditingController controller, TextInputType type) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: labelText,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}
