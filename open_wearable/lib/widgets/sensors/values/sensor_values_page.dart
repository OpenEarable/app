import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/models/wearable_display_group.dart';
import 'package:open_wearable/view_models/sensor_data_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/widgets/sensors/sensor_page_spacing.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_value_card.dart';
import 'package:provider/provider.dart';

class SensorValuesPage extends StatelessWidget {
  final Map<(Wearable, Sensor), SensorDataProvider> _sensorDataProvider = {};

  SensorValuesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WearablesProvider>(
      builder: (context, wearablesProvider, child) {
        return FutureBuilder<List<WearableDisplayGroup>>(
          future: buildWearableDisplayGroups(
            wearablesProvider.wearables,
            shouldCombinePair: (left, right) =>
                wearablesProvider.isStereoPairCombined(
              first: left,
              second: right,
            ),
          ),
          builder: (context, snapshot) {
            final groups = _orderGroupsForLiveData(
              snapshot.data ??
                  wearablesProvider.wearables
                      .map(
                        (wearable) =>
                            WearableDisplayGroup.single(wearable: wearable),
                      )
                      .toList(),
            );
            final orderedWearables = _orderedWearablesFromGroups(groups);
            final charts = _buildCharts(orderedWearables);
            _cleanupProviders(orderedWearables);

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
      },
    );
  }

  List<Widget> _buildCharts(List<Wearable> orderedWearables) {
    final charts = <Widget>[];
    for (final wearable in orderedWearables) {
      if (!wearable.hasCapability<SensorManager>()) {
        continue;
      }
      for (final sensor
          in wearable.requireCapability<SensorManager>().sensors) {
        if (!_sensorDataProvider.containsKey((wearable, sensor))) {
          _sensorDataProvider[(wearable, sensor)] =
              SensorDataProvider(sensor: sensor);
        }
        charts.add(
          ChangeNotifierProvider.value(
            value: _sensorDataProvider[(wearable, sensor)],
            child: SensorValueCard(
              sensor: sensor,
              wearable: wearable,
            ),
          ),
        );
      }
    }
    return charts;
  }

  void _cleanupProviders(List<Wearable> orderedWearables) {
    _sensorDataProvider.removeWhere(
      (key, _) => !orderedWearables.any(
        (device) =>
            device.hasCapability<SensorManager>() &&
            device == key.$1 &&
            device.requireCapability<SensorManager>().sensors.contains(key.$2),
      ),
    );
  }

  List<WearableDisplayGroup> _orderGroupsForLiveData(
    List<WearableDisplayGroup> groups,
  ) {
    final indexed = groups.asMap().entries.toList();

    indexed.sort((a, b) {
      final groupA = a.value;
      final groupB = b.value;
      final sameName =
          groupA.displayName.toLowerCase() == groupB.displayName.toLowerCase();
      final bothSingle = !groupA.isCombined && !groupB.isCombined;
      if (sameName && bothSingle) {
        final sideOrderA = _configureSideOrder(groupA.primaryPosition);
        final sideOrderB = _configureSideOrder(groupB.primaryPosition);
        final knownSides = sideOrderA <= 1 && sideOrderB <= 1;
        if (knownSides && sideOrderA != sideOrderB) {
          return sideOrderA.compareTo(sideOrderB);
        }
      }

      // Preserve existing order for all other rows.
      return a.key.compareTo(b.key);
    });

    return indexed.map((entry) => entry.value).toList();
  }

  int _configureSideOrder(DevicePosition? position) {
    if (position == DevicePosition.left) {
      return 0;
    }
    if (position == DevicePosition.right) {
      return 1;
    }
    return 2;
  }

  List<Wearable> _orderedWearablesFromGroups(
    List<WearableDisplayGroup> groups,
  ) {
    final ordered = <Wearable>[];
    for (final group in groups) {
      final left = group.leftDevice;
      final right = group.rightDevice;
      if (left != null) {
        ordered.add(left);
      }
      if (right != null && right.deviceId != left?.deviceId) {
        ordered.add(right);
      }
      if (left == null && right == null) {
        ordered.addAll(group.members);
      }
    }
    return ordered;
  }

  Widget _buildSmallScreenLayout(BuildContext context, List<Widget> charts) {
    if (charts.isEmpty) {
      return Center(
        child: PlatformText(
          "No sensors connected",
          style: Theme.of(context).textTheme.titleLarge,
        ),
      );
    }

    return ListView(
      padding: SensorPageSpacing.pagePadding,
      children: charts,
    );
  }

  Widget _buildLargeScreenLayout(BuildContext context, List<Widget> charts) {
    return GridView.builder(
      padding: SensorPageSpacing.pagePadding,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 500,
        childAspectRatio: 1.5,
        crossAxisSpacing: SensorPageSpacing.gridGap,
        mainAxisSpacing: SensorPageSpacing.gridGap,
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
              child: PlatformText(
                "No sensors available",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          );
        }
        return charts[index];
      },
    );
  }
}
