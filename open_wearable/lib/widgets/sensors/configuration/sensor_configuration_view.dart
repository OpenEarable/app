import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_device_row.dart';
import 'package:provider/provider.dart';

/// A view that displays the sensor configurations of all connected wearables.
/// 
/// The specific sensor configurations should be made available via the [SensorConfigurationProvider].
class SensorConfigurationView extends StatelessWidget {
  final VoidCallback? onSetConfigPressed;

  const SensorConfigurationView({super.key, this.onSetConfigPressed});

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
        child: PlatformText("No devices connected", style: Theme.of(context).textTheme.titleLarge),
      );
    }

    return Padding(
      padding: EdgeInsets.all(10),
      child: wearablesProvider.wearables.isEmpty
        ? Center(
          child: PlatformText("No devices connected", style: Theme.of(context).textTheme.titleLarge),
        )
        : ListView(
          children: [
            ...wearablesProvider.wearables.map((wearable) {
              return ChangeNotifierProvider<SensorConfigurationProvider>.value(
                value: wearablesProvider.getSensorConfigurationProvider(wearable),
                child: SensorConfigurationDeviceRow(device: wearable),
              );
            }),
            _buildSetConfigButton(
              configProviders: wearablesProvider.wearables.map((wearable) => wearablesProvider.getSensorConfigurationProvider(wearable)).toList(),
            ),
          ],
        ),
    );
  }

  Widget _buildSetConfigButton({required List<SensorConfigurationProvider> configProviders}) {
    return PlatformElevatedButton(
      onPressed: () {
        for (SensorConfigurationProvider notifier in configProviders) {
          logger.d("Setting sensor configurations for notifier: $notifier");
          notifier.getSelectedConfigurations().forEach((entry) {
            SensorConfiguration config = entry.$1;
            SensorConfigurationValue value = entry.$2;
            config.setConfiguration(value);
          });
        }
        (onSetConfigPressed ?? () {})();
      },
      child: PlatformText('Set Sensor Configurations'),
    );
  }

  Widget _buildLargeScreenLayout(BuildContext context, WearablesProvider wearablesProvider) {
    final List<Wearable> devices = wearablesProvider.wearables;
    List<StaggeredGridTile> tiles = _generateTiles(devices, wearablesProvider.sensorConfigurationProviders);
    if (tiles.isNotEmpty) {
      tiles.add(
        StaggeredGridTile.extent(
          crossAxisCellCount: 1,
          mainAxisExtent: 100.0,
          child: _buildSetConfigButton(
            configProviders: devices.map((device) => wearablesProvider.getSensorConfigurationProvider(device)).toList(),
          ),
        ),
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
              child: PlatformText("No devices connected", style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
        ),
      ],
    );
  }

  /// Generates a dynamic quilted grid layout based on the device properties
  List<StaggeredGridTile> _generateTiles(List<Wearable> devices, Map<Wearable, SensorConfigurationProvider> notifiers) {
    // Sort devices by size dynamically for a balanced layout
    devices.sort((a, b) => _getGridSpanForDevice(b) - _getGridSpanForDevice(a));

    return devices.map((device) {
      int span = _getGridSpanForDevice(device);

      return StaggeredGridTile.extent(
        crossAxisCellCount: 1, // Dynamic width
        mainAxisExtent: span * 100.0, // Dynamic height based on content
        child: ChangeNotifierProvider<SensorConfigurationProvider>.value(
          value: notifiers[device]!,
          child: SensorConfigurationDeviceRow(device: device),
        ),
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
