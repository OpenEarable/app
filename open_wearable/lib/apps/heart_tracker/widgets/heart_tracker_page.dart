import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/heart_tracker/widgets/rowling_chart.dart';

class HeartTrackerPage extends StatelessWidget {
  final Sensor ppgSensor;

  HeartTrackerPage({super.key, required this.ppgSensor}) {
    SensorConfiguration configuration = ppgSensor.relatedConfigurations.first;
    if (configuration is StreamableSensorConfiguration) {
      (configuration as StreamableSensorConfiguration).streamData = true;
    }
    configuration.setConfiguration(configuration.values.first);
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text("Heart Tracker"),
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 300,
            child: RollingChart(
              dataSteam: ppgSensor.sensorStream.asyncMap(
                (data) {
                  return (data.timestamp, (data as SensorDoubleValue).values[2]);
                }
              ),
              timestampExponent: ppgSensor.timestampExponent,
              timeWindow: 5,
            ),
          ),
        ],
      ),
    );
  }
}