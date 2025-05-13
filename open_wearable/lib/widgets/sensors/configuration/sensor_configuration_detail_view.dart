import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:provider/provider.dart';

import 'sensor_config_option_icon_factory.dart';

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
    SensorConfigurationProvider sensorConfigNotifier = Provider.of<SensorConfigurationProvider>(context);
    _selectedValue = sensorConfigNotifier.sensorConfigurations[widget.sensorConfiguration];

    return ListView(
      children: [
        if (widget.sensorConfiguration is ConfigurableSensorConfiguration)
          ...(widget.sensorConfiguration as ConfigurableSensorConfiguration).availableOptions.map((option) {
            return PlatformListTile(
              leading: Icon(getSensorConfigurationOptionIcon(option)),
              title: Text(option.name),
              trailing: PlatformSwitch(
                value: sensorConfigNotifier.sensorConfigurationOptions[widget.sensorConfiguration]?.contains(option) ?? false,
                onChanged: (value) {
                  setState(() {
                    if (value) {
                      if (sensorConfigNotifier.sensorConfigurationOptions[widget.sensorConfiguration] == null) {
                        sensorConfigNotifier.sensorConfigurationOptions[widget.sensorConfiguration] = [];
                      }
                      sensorConfigNotifier.sensorConfigurationOptions[widget.sensorConfiguration]?.add(option);
                    } else {
                      sensorConfigNotifier.sensorConfigurationOptions[widget.sensorConfiguration]?.remove(option);
                    }
                  });
                  sensorConfigNotifier.addSensorConfiguration(widget.sensorConfiguration, _selectedValue!);
                },
              ),
            );
          }),
        PlatformListTile(
          leading: Icon(Icons.speed_outlined),
          title: Text("Sampling Rate"),
          trailing: DropdownButton<SensorConfigurationValue>(
            value: _selectedValue,
            items: widget.sensorConfiguration is SensorFrequencyConfiguration
              ? () {
                List<SensorFrequencyConfigurationValue> values = [];

                for (SensorConfigurationValue value in widget.sensorConfiguration.values) {
                  double freq = (value as SensorFrequencyConfigurationValue).frequencyHz;
                  if (!values.any((v) => v.frequencyHz == freq)) {
                    values.add(value);
                  }
                }
                return values.map((value) {
                  return DropdownMenuItem<SensorConfigurationValue>(
                    value: value,
                    child: Text(value.key),
                  );
                }).toList();
              }()
              : widget.sensorConfiguration.values.map((value) {
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