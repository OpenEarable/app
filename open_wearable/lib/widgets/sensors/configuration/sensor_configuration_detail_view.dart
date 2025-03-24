import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_config_notifier.dart';
import 'package:provider/provider.dart';

class SensorConfigurationDetailView extends StatefulWidget {
  final SensorConfiguration sensorConfiguration;

  const SensorConfigurationDetailView({
    super.key,
    required this.sensorConfiguration,
  });
  
  @override
  State<StatefulWidget> createState() {
    return _SensorConfigurationDetailViewState();
  }
}

class _SensorConfigurationDetailViewState extends State<SensorConfigurationDetailView> {
  SensorConfigurationValue? _selectedValue;

  @override
  Widget build(BuildContext context) {
    SensorConfigNotifier sensorConfigNotifier = Provider.of<SensorConfigNotifier>(context);
    _selectedValue = sensorConfigNotifier.sensorConfigurationValues[widget.sensorConfiguration];

    return ListView(
      children: [
        if (widget.sensorConfiguration is StreamableSensorConfiguration)
          PlatformListTile(
            leading: Icon(Icons.bluetooth),
            title: Text("Stream Data"),
            trailing: Switch(
              value: (widget.sensorConfiguration as StreamableSensorConfiguration).streamData,
              onChanged: (value) {
                setState(() {
                  (widget.sensorConfiguration as StreamableSensorConfiguration).streamData = value;
                });
                sensorConfigNotifier.addSensorConfiguration(widget.sensorConfiguration, _selectedValue!);
              }
            ),
          ),
        if (widget.sensorConfiguration is RecordableSensorConfig)
          PlatformListTile(
            leading: Icon(Icons.file_download_outlined),
            title: Text("Record Data to SD Card"),
            trailing: Switch(
              value: (widget.sensorConfiguration as RecordableSensorConfig).recordData,
              onChanged: (value) {
                setState(() {
                  (widget.sensorConfiguration as RecordableSensorConfig).recordData = value;
                });
                sensorConfigNotifier.addSensorConfiguration(widget.sensorConfiguration, _selectedValue!);
              }
            ),
          ),
        PlatformListTile(
          leading: Icon(Icons.speed_outlined),
          title: Text("Sampling Rate"),
          trailing: DropdownButton<SensorConfigurationValue>(
            value: _selectedValue,
            items: widget.sensorConfiguration.values.map((value) {
              return DropdownMenuItem<SensorConfigurationValue>(
                value: value,
                child: Text(value.key),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedValue = value;
              });
              if (_selectedValue != null) {
                sensorConfigNotifier.addSensorConfiguration(widget.sensorConfiguration, _selectedValue!);
              }
            },
          ),
        ),
      ],
    );
  }
}