import 'package:flutter/material.dart';
import 'package:open_earable/apps/fever_thermometer/settings.dart';
import '../../widgets/earable_not_connected_warning.dart';
import 'views/settings_view.dart';
import 'fever_thermometer.dart';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';

/// Entry point of the Fever Thermometer app.
class FeverThermometerMain extends StatefulWidget {
  final OpenEarable _openEarable;

  FeverThermometerMain(this._openEarable);

  @override
  State<FeverThermometerMain> createState() => _FeverThermometerMainState(_openEarable);
}

class _FeverThermometerMainState extends State<FeverThermometerMain> {
  final OpenEarable _openEarable;
  Settings _settings = Settings();
  FeverThermometer? _feverThermometer;
  Key _feverMainKey = UniqueKey();

  _FeverThermometerMainState(this._openEarable);

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fever Thermometer"),
        actions: [
          IconButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => SettingsView(_settings, _buildNew))),
              icon: Icon(Icons.settings)),
        ],
      ),
      body: _openEarable.bleManager.connected
          ? _feverThermometer
          : EarableNotConnectedWarning(),
      backgroundColor: Theme.of(context).colorScheme.background,
    );
  }

  @override
  void initState() {
    super.initState();
    _feverThermometer = FeverThermometer(
        key: _feverMainKey,
        openEarable: _openEarable,
        settings: _settings,
        referenceSet: null);
  }

  /// This function is called if the settings have changed.
  _buildNew() {
    setState(() {
      _feverMainKey = UniqueKey();
      _feverThermometer = FeverThermometer(
          key: _feverMainKey,
          openEarable: _openEarable,
          settings: _settings,
          referenceSet: false);
    });
  }
}
