import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_data_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_value_card.dart';
import 'package:provider/provider.dart';

class SensorValuesPage extends StatelessWidget {
  final Map<(Wearable, Sensor), SensorDataProvider> _sensorDataProvider = {};

  SensorValuesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WearablesProvider>(
      builder: (context, wearablesProvider, child) {
        List<Widget> charts = [];
        for (var wearable in wearablesProvider.wearables) {
          if (wearable is SensorManager) {
            for (Sensor sensor in (wearable as SensorManager).sensors) {
              if (!_sensorDataProvider.containsKey((wearable, sensor))) {
                _sensorDataProvider[(wearable, sensor)] = SensorDataProvider(sensor: sensor);
              }
              charts.add(
                ChangeNotifierProvider.value(
                  value: _sensorDataProvider[(wearable, sensor)],
                  child: SensorValueCard(sensor: sensor, wearable: wearable,),
                ),
              );
            }
          }
        }

        _sensorDataProvider.removeWhere((key, _) =>
          !wearablesProvider.wearables.any((device) => device is SensorManager
          && device == key.$1
          && (device as SensorManager).sensors.contains(key.$2),),
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return _buildSmallScreenLayout(context, charts);
            } else {
              return _buildLargeScreenLayout(context, charts);
            }
          },
        );
      },
    );
  }

  Widget _buildSmallScreenLayout(BuildContext context, List<Widget> charts) {
    return Padding(
      padding: EdgeInsets.all(10),
      child: charts.isEmpty
        ? Center(
          child: PlatformText("No sensors connected", style: Theme.of(context).textTheme.titleLarge),
        )
        : ListView(
          children: charts,
        ),
    );
  }

  Widget _buildLargeScreenLayout(BuildContext context, List<Widget> charts) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 500,
        childAspectRatio: 1.5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: charts.isEmpty ? 1 : charts.length,
      itemBuilder: (context, index) {
        if (charts.isEmpty) {
          return Card(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: Colors.grey,
                width: 1,
                style: BorderStyle.solid,
                strokeAlign: -1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: PlatformText("No sensors available", style: Theme.of(context).textTheme.titleLarge),
            ),
          );
        }
        return charts[index];
      },
    );
  }
}
