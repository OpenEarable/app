import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/views/pomodoro_app_settings.dart';
import 'package:open_earable/apps_tab/pomodoro_timer/widgets/assignment_text.dart';

/// The view for the Pomodoro App settings.
class PomodoroAppSettingsView extends StatefulWidget {
  final PomodoroAppSettings pomodoroAppSettings;

  const PomodoroAppSettingsView(this.pomodoroAppSettings, {super.key});

  @override
  State<PomodoroAppSettingsView> createState() => _PomodoroAppSettingsViewState();
}

class _PomodoroAppSettingsViewState extends State<PomodoroAppSettingsView> {
  int _currentRepetitions = 0;

  @override
  void initState() {
    super.initState();
    _currentRepetitions = widget.pomodoroAppSettings.nodExerciseDefaultRepetitions;
  }


  /// Save the settings and close the settings view.
  void _saveSettings() {
    setState(() {
      widget.pomodoroAppSettings.nodExerciseDefaultRepetitions = _currentRepetitions;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            AssignmentText('Select the number of repetitions for the nod exercise:'),
            NumberPicker(
              axis: Axis.horizontal,
              value: _currentRepetitions,
              minValue: 0,
              maxValue: 100,
              onChanged: (value) => setState(() => _currentRepetitions = value),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveSettings,
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
