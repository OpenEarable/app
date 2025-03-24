import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_config_notifier.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_device_row.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_values_page.dart';
import 'package:provider/provider.dart';

/// A view that displays the sensor configurations of all connected wearables.
/// 
/// The specific sensor configurations should be made available via the [SensorConfigurationProvider].
class SensorConfigurationView extends StatelessWidget {
  final Map<Wearable, SensorConfigNotifier> _notifiers = {};
  
  SensorConfigurationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WearablesProvider>(
      builder: (context, wearablesProvider, child) {
        updateNotifiers(wearablesProvider.wearables);

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

  void updateNotifiers(List<Wearable> devices) {
    logger.d("Updating notifiers for devices: $devices");
    for (Wearable device in devices) {
      if (device is SensorConfigurationManager) {
        if (!_notifiers.containsKey(device)) {
          _notifiers[device] = SensorConfigNotifier();
        }

        SensorConfigNotifier notifier = _notifiers[device]!;
        for (SensorConfiguration config in (device as SensorConfigurationManager).sensorConfigurations) {
          if (!notifier.sensorConfigurationValues.containsKey(config)) {
            notifier.addSensorConfiguration(config, config.values.first);
          }
        }
      }
    }

    // remove all notifiers that are not in the devices list
    _notifiers.removeWhere((key, value) => !devices.contains(key));
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
              return ChangeNotifierProvider<SensorConfigNotifier>.value(
                value: _notifiers[wearable]!,
                child: SensorConfigurationDeviceRow(device: wearable),
              );
            }),
            PlatformElevatedButton(
              onPressed: () {
                for (SensorConfigNotifier notifier in _notifiers.values) {
                  logger.d("Setting sensor configurations for notifier: $notifier");
                  notifier.sensorConfigurationValues.forEach((config, value) {
                    config.setConfiguration(value);
                  });
                }
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
    final List<Wearable> devices = wearablesProvider.wearables;
    List<StaggeredGridTile> tiles = _generateTiles(devices);
    if (tiles.isNotEmpty) {
      tiles.add(
        StaggeredGridTile.extent(
          crossAxisCellCount: 1,
          mainAxisExtent: 100.0,
          child: PlatformElevatedButton(
            onPressed: () {
              SensorConfigurationProvider sensorConfigurationProvider = Provider.of<SensorConfigurationProvider>(context, listen: false);
              sensorConfigurationProvider.sensorConfigurations.forEach((config, value) {
                config.setConfiguration(value);
              });
            },
            child: const Text('Set sensor configurations'),
          ),
        )
      );
    }

    return StaggeredGrid.count(
      crossAxisCount: (MediaQuery.of(context).size.width / 250).floor().clamp(1, 4), // Adaptive grid
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: tiles.isNotEmpty ? tiles : [
        StaggeredGridTile.extent(
          crossAxisCellCount: 1,
          mainAxisExtent: 100.0,
          child: Card(
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
              child: Text("No devices connected", style: Theme.of(context).textTheme.titleLarge)
            ),
          )
        ),
      ],
    );
  }

  /// Generates a dynamic quilted grid layout based on the device properties
  List<StaggeredGridTile> _generateTiles(List<Wearable> devices) {
    // Sort devices by size dynamically for a balanced layout
    devices.sort((a, b) => _getGridSpanForDevice(b) - _getGridSpanForDevice(a));

    return devices.map((device) {
      int span = _getGridSpanForDevice(device);

      return StaggeredGridTile.extent(
        crossAxisCellCount: 1, // Dynamic width
        mainAxisExtent: span * 100.0, // Dynamic height based on content
        child: SensorConfigurationDeviceRow(device: device),
      );
    }).toList();
  }

  /// Determines how many columns a device should span
  int _getGridSpanForDevice(Wearable device) {
    if (device is! SensorConfigurationManager) {
      return 1; // Default size
    }

    int sensorConfigCount = (device as SensorConfigurationManager).sensorConfigurations.length;

    return sensorConfigCount.clamp(1, 4);
  }
}