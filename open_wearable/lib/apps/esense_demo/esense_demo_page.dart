import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class EsenseDemoPage extends StatelessWidget {
  final Wearable wearable;

  const EsenseDemoPage({super.key, required this.wearable});

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText("eSense Demo"),
      ),
      body: (wearable is SensorManager)
          ? SensorValueView(
              sensor: (wearable as SensorManager).sensors.first,
            )
          : Center(
              child: PlatformText("No eSense device connected"),
            ),
    );
  }
}

class SensorValueView extends StatelessWidget {
  final Sensor sensor;
  
  const SensorValueView({super.key, required this.sensor});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        StreamBuilder(
          stream: sensor.sensorStream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return PlatformListTile(
                title: Text("Sensor Values"),
                trailing: Text(snapshot.data!.valueStrings.join(", ")),
              );
            } else {
              return PlatformListTile(
                title: Text("Sensor Values"),
                trailing: Text("No data"),
              );
            }
          }),
          PlatformElevatedButton(
            child: PlatformText("Start Streaming"),
            onPressed: () {
              SensorConfiguration config = sensor.relatedConfigurations.first;
              if (config is ConfigurableSensorConfiguration) {
                List<ConfigurableSensorConfigurationValue> values = config.values;
                if (config.availableOptions.any((o) => o is StreamSensorConfigOption)) {
                  ConfigurableSensorConfigurationValue streamValue =
                    values.firstWhere((v) => v.options.any((o) => o is StreamSensorConfigOption));

                  config.setConfiguration(streamValue);
                }
              }
            },
          ),
      ],
    );
  }
}
