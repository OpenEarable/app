import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:provider/provider.dart';

/// A row that displays a sensor configuration and allows the user to select a value.
/// 
/// The selected value is added to the [SensorConfigurationProvider].
class SensorConfigurationValueRow extends StatefulWidget {
  final SensorConfiguration sensorConfiguration;

  const SensorConfigurationValueRow({super.key, required this.sensorConfiguration});

  @override
  State<SensorConfigurationValueRow> createState() => _SensorConfigurationValueRowState();
}

class _SensorConfigurationValueRowState extends State<SensorConfigurationValueRow> {
  SensorConfigurationValue? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.sensorConfiguration.values.first;
  }

  @override
  Widget build(BuildContext context) {
    return PlatformListTile(
      title: Text(widget.sensorConfiguration.name),
      trailing: DropdownButton<SensorConfigurationValue>(
        value: _selectedValue,
        items: widget.sensorConfiguration.values.map((value) {
          return DropdownMenuItem<SensorConfigurationValue>(
            value: value,
            child: Text(value.toString()),
          );
        }).toList(),
        onChanged: (newValue) {
          setState(() {
            _selectedValue = newValue;
          });
          if (_selectedValue != null) {
            Provider.of<SensorConfigurationProvider>(context, listen: false)
              .addSensorConfiguration(widget.sensorConfiguration, _selectedValue!);
          }
        },
      ),
    );
  }
}