import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_value_card.dart';
import 'package:provider/provider.dart';

class SensorValuesPage extends StatelessWidget {
  const SensorValuesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text('Sensor Values'),
      ),
      body: Consumer<WearablesProvider>(
        builder: (context, wearablesProvider, child) {
          return Padding(
            padding: EdgeInsets.all(10),
            child: ListView(
              children:
                wearablesProvider.wearables.map<List<Widget>?>((wearable) {
                  if (wearable is SensorManager) {
                    return (wearable as SensorManager).sensors.map<Widget>((sensor) {
                      //FIXME: disabling a sensor results in a weird graph for this sensor
                      return SensorValueCard(sensor: sensor, wearable: wearable,);
                    }).toList();
                  } else {
                    return null;
                  }
                }).where((element) => element != null).map((e) => e!,).expand<Widget>((e) => e).toList(),
            )
          );
        },
      )
    );
  }
}