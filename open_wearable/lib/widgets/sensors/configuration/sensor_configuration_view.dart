import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart' hide logger;
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_device_row.dart';
import 'package:provider/provider.dart';

import '../../../models/logger.dart';

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
        return _buildSmallScreenLayout(context, wearablesProvider);
      },
    );
  }

  Widget _buildSmallScreenLayout(
    BuildContext context,
    WearablesProvider wearablesProvider,
  ) {
    if (wearablesProvider.wearables.isEmpty) {
      return Center(
        child: PlatformText(
          "No devices connected",
          style: Theme.of(context).textTheme.titleLarge,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        ...wearablesProvider.wearables.map((wearable) {
          if (wearable.hasCapability<SensorConfigurationManager>()) {
            return ChangeNotifierProvider<SensorConfigurationProvider>.value(
              value: wearablesProvider.getSensorConfigurationProvider(wearable),
              child: SensorConfigurationDeviceRow(device: wearable),
            );
          } else {
            return SensorConfigurationDeviceRow(device: wearable);
          }
        }),
        _buildApplyConfigButton(
          context,
          configProviders: wearablesProvider.wearables
              // ignore: prefer_iterable_wheretype
              .where(
                (wearable) =>
                    wearable.hasCapability<SensorConfigurationManager>(),
              )
              .map(
                (wearable) =>
                    wearablesProvider.getSensorConfigurationProvider(wearable),
              )
              .toList(),
        ),
        _buildThroughputWarningBanner(context),
      ],
    );
  }

  Widget _buildApplyConfigButton(
    BuildContext context, {
    required List<SensorConfigurationProvider> configProviders,
  }) {
    return PlatformElevatedButton(
      onPressed: () async {
        if (configProviders.isEmpty) {
          await showPlatformDialog<void>(
            context: context,
            builder: (dialogContext) => PlatformAlertDialog(
              title: PlatformText('No configurable devices'),
              content: PlatformText(
                'Connect a wearable with configurable sensors to apply settings.',
              ),
              actions: [
                PlatformDialogAction(
                  child: PlatformText('OK'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          );
          return;
        }

        int appliedCount = 0;
        for (SensorConfigurationProvider notifier in configProviders) {
          logger.d("Setting sensor configurations for notifier: $notifier");
          notifier.getSelectedConfigurations().forEach((entry) {
            SensorConfiguration config = entry.$1;
            SensorConfigurationValue value = entry.$2;
            config.setConfiguration(value);
            appliedCount += 1;
          });
        }

        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              'Applied $appliedCount sensor settings to ${configProviders.length} device(s).',
            ),
          ),
        );

        (onSetConfigPressed ?? () {})();
      },
      child: PlatformText('Apply Configurations'),
    );
  }

  Widget _buildThroughputWarningBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sampling & bandwidth guidance',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'High sensor counts and aggressive sampling rates can exceed bandwidth and cause dropped samples.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            _buildGuidanceItem(
              context,
              'Enable only the sensors needed for this session.',
            ),
            _buildGuidanceItem(
              context,
              'Lower sampling rates for non-critical signals.',
            ),
            _buildGuidanceItem(
              context,
              'For high-rate recordings, recording to the on-board memory of the device is preferred (if available).',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceItem(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_outline,
              size: 16,
              color: colorScheme.primary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLargeScreenLayout(
    BuildContext context,
    WearablesProvider wearablesProvider,
  ) {
    final List<Wearable> devices = wearablesProvider.wearables;
    List<StaggeredGridTile> tiles =
        _generateTiles(devices, wearablesProvider.sensorConfigurationProviders);
    if (tiles.isNotEmpty) {
      tiles.addAll(
        [
          StaggeredGridTile.extent(
            crossAxisCellCount: 1,
            mainAxisExtent: 100.0,
            child: _buildApplyConfigButton(
              context,
              configProviders: devices
                  .map(
                    (device) => wearablesProvider
                        .getSensorConfigurationProvider(device),
                  )
                  .toList(),
            ),
          ),
          StaggeredGridTile.extent(
            crossAxisCellCount: 1,
            mainAxisExtent: 230.0,
            child: _buildThroughputWarningBanner(context),
          ),
        ],
      );
    }

    return StaggeredGrid.count(
      crossAxisCount: (MediaQuery.of(context).size.width / 250)
          .floor()
          .clamp(1, 4), // Adaptive grid
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: tiles.isNotEmpty
          ? tiles
          : [
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
                    child: PlatformText(
                      "No devices connected",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            ],
    );
  }

  /// Generates a dynamic quilted grid layout based on the device properties
  List<StaggeredGridTile> _generateTiles(
    List<Wearable> devices,
    Map<Wearable, SensorConfigurationProvider> notifiers,
  ) {
    // Sort devices by size dynamically for a balanced layout
    devices.sort(
      (a, b) => _getGridSpanForDevice(b) - _getGridSpanForDevice(a),
    );

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
    if (!device.hasCapability<SensorConfigurationManager>()) {
      return 1; // Default size
    }

    int sensorConfigCount = device
        .requireCapability<SensorConfigurationManager>()
        .sensorConfigurations
        .length;

    return sensorConfigCount.clamp(1, 4);
  }
}
