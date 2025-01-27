import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_chart.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_value_detail.dart';

class SensorValueCard extends StatelessWidget {
  final Sensor sensor;
  final Wearable wearable;

  const SensorValueCard({super.key, required this.sensor, required this.wearable});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => SensorValueDetail(sensor: sensor, wearable: wearable),
        ));
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              Row(
                children: [
                  Text(sensor.sensorName, style: Theme.of(context).textTheme.bodyLarge),
                  Spacer(),
                  Text(wearable.name, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              SizedBox(
                height: 200,
                child: SensorChart(sensor: sensor, allowToggleAxes: false,),
              ),
            ],
          ),
        ),
      ),
    );
  }
}