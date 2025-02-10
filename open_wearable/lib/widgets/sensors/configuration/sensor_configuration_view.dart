import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_device_row.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_values_page.dart';
import 'package:provider/provider.dart';

/// A view that displays the sensor configurations of all connected wearables.
/// 
/// The specific sensor configurations should be made available via the [SensorConfigurationProvider].
class SensorConfigurationView extends StatelessWidget {
  const SensorConfigurationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WearablesProvider>(
      builder: (context, wearablesProvider, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return _buildSmallScreenLayout(context, wearablesProvider);
            } else {
              return _buildLargeScreenLayout(context, wearablesProvider);
            }
          },
        );
      },
    );
  }

  Widget _buildSmallScreenLayout(BuildContext context, WearablesProvider wearablesProvider) {
    if (wearablesProvider.wearables.isEmpty) {
      return Center(
        child: Text("No devices connected", style: Theme.of(context).textTheme.titleLarge),
      );
    }

    return Padding(
      padding: EdgeInsets.all(10),
      child: wearablesProvider.wearables.isEmpty
        ? Center(
          child: Text("No devices connected", style: Theme.of(context).textTheme.titleLarge),
        )
        : ListView(
          children: [
            ...wearablesProvider.wearables.map((wearable) {
              return SensorConfigurationDeviceRow(device: wearable);
            }),
            PlatformElevatedButton(
              onPressed: () {
                SensorConfigurationProvider sensorConfigurationProvider = Provider.of<SensorConfigurationProvider>(context, listen: false);
                sensorConfigurationProvider.sensorConfigurations.forEach((config, value) {
                  config.setConfiguration(value);
                });
                Navigator.of(context).push(
                  platformPageRoute(
                    context: context,
                    builder: (context) => SensorValuesPage(),
                  ),
                );
              },
              child: const Text('Set sensor configurations'),
            )
          ],
        )
    );
  }

  Widget _buildLargeScreenLayout(BuildContext context, WearablesProvider wearablesProvider) {
    return Padding(
      padding: EdgeInsets.all(10),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 500,
          childAspectRatio: 1,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: wearablesProvider.wearables.length,
        itemBuilder: (context, index) {
          return SensorConfigurationDeviceRow(device: wearablesProvider.wearables[index]);
        },
      ),
    );
  }
}