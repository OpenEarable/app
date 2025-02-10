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
    return Consumer<WearablesProvider>(
      builder: (context, wearablesProvider, child) {
        List<Widget> charts = [];
        for (var wearable in wearablesProvider.wearables) {
          if (wearable is SensorManager) {
            for (var sensor in (wearable as SensorManager).sensors) {
              charts.add(SensorValueCard(sensor: sensor, wearable: wearable,));
            }
          }
        }

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
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text('Sensor Values'),
      ),
      body: Padding(
        padding: EdgeInsets.all(10),
        child: ListView(
          children: charts
        )
      )
    );
  }

  Widget _buildLargeScreenLayout(BuildContext context, List<Widget> charts) {
    return Padding(
      padding: EdgeInsets.all(10),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 500,
          childAspectRatio: 1.5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: charts.length,
        itemBuilder: (context, index) {
          return charts[index];
        },
      )
    );
  }
}