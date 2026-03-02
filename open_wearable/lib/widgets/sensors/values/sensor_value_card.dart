import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_data_provider.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_chart.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_value_detail.dart';
import 'package:provider/provider.dart';

class SensorValueCard extends StatelessWidget {
  final Sensor sensor;
  final Wearable wearable;

  const SensorValueCard({super.key, required this.sensor, required this.wearable});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
          final provider = context.read<SensorDataProvider>();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider.value(
                value: provider,
                child: SensorValueDetail(sensor: sensor, wearable: wearable),
              ),
            ),
          );
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              Row(
                children: [
                  PlatformText(sensor.sensorName, style: Theme.of(context).textTheme.bodyLarge),
                  Spacer(),
                  PlatformText(wearable.name, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                  child: SizedBox(
                  height: 200,
                  child: SensorChart(allowToggleAxes: false,),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
