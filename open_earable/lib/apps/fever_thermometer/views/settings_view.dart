import 'package:flutter/material.dart';
import 'package:open_earable/apps/fever_thermometer/settings.dart';

class SettingsView extends StatefulWidget {
  final Settings _settings;
  final VoidCallback? _buildNew;

  SettingsView(this._settings, this._buildNew);

  @override
  State<SettingsView> createState() => _SettingsViewState(_settings, _buildNew);
}

class _SettingsViewState extends State<SettingsView> {
  final Settings _settings;
  final VoidCallback? _buildNew;

  _SettingsViewState(this._settings, this._buildNew);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Fever Thermometer Settings")),
      body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("Reference measured Temperature: "),
                Text(
                  _settings.getReferenceMeasuredTemperature() == null
                      ? "  -  "
                      : _settings
                          .getReferenceMeasuredTemperature()
                          .toStringAsFixed(2),
                  style: TextStyle(fontSize: 40),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("Reference real Temperature: "),
                Text(
                  _settings.getReferenceRealTemperature() == null
                      ? "  -  "
                      : _settings.getReferenceRealTemperature().toString(),
                  style: TextStyle(fontSize: 40),
                ),
              ],
            ),
            Container(
              child: (_settings.getTemperature(0) == null)
                  ? Text("Reference not set",
                      style: TextStyle(color: Colors.red, fontSize: 40))
                  : null,
            ),
            ElevatedButton(
                onPressed: () {
                  _deleteData();
                },
                child: Text("Delete Data"))
          ]),
      backgroundColor: Theme.of(context).colorScheme.background,
    );
  }

  /// Deletes the data from the settings.
  _deleteData() {
    setState(() {
      _settings.deleteData();

      _buildNew!();
      _buildNew!();
    });
  }
}
