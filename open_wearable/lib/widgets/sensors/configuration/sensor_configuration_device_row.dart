import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_storage.dart';
import 'package:open_wearable/widgets/sensors/configuration/edge_recorder_prefix_row.dart';
import 'package:open_wearable/widgets/sensors/configuration/save_config_row.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_value_row.dart';
import 'package:provider/provider.dart';

import '../../../view_models/sensor_configuration_provider.dart';

/// A widget that displays a list of sensor configurations for a device.
class SensorConfigurationDeviceRow extends StatefulWidget {
  final Wearable device;

  const SensorConfigurationDeviceRow({super.key, required this.device});

  @override
  State<SensorConfigurationDeviceRow> createState() =>
      _SensorConfigurationDeviceRowState();
}

class _SensorConfigurationDeviceRowState extends State<SensorConfigurationDeviceRow>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Widget> _content = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _buildContent(context);
      }
    });
    _content = [PlatformCircularProgressIndicator()];
    _buildContent(context);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlatformListTile(
            title: Text(
              device.name,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            trailing: _buildTabBar(context),
          ),
          ..._content,
        ],
      ),
    );
  }

  Future<void> _buildContent(BuildContext context) async {
    final device = widget.device;

    if (device is SensorConfigurationManager) {
      if (_tabController.index == 0) {
        List<Widget> content = (device as SensorConfigurationManager).sensorConfigurations
            .map((config) => SensorConfigurationValueRow(sensorConfiguration: config)).cast<Widget>()
            .toList();

        // Store Config
        content.addAll([
          const Divider(),
          SaveConfigRow(),
        ]);

        if (device is EdgeRecorderManager) {
          content.addAll([
            const Divider(),
            EdgeRecorderPrefixRow(
              manager: device as EdgeRecorderManager,
            ),
          ]);
        }
        setState(() {
          _content = content;
        });
      } else {
        SensorConfigurationProvider provider =
            Provider.of<SensorConfigurationProvider>(context, listen: false);
        
        setState(() {
          _content = [PlatformCircularProgressIndicator()];
        });

        List<String> configKeys = await SensorConfigurationStorage.listConfigurationKeys();

        if (configKeys.isEmpty) {
          setState(() {
            _content = [
              PlatformListTile(title: Text("No configurations found")),
            ];
          });
          return;
        }

        setState(() {
          _content = configKeys.map((key) {
            return PlatformListTile(
              onTap: () {
                // Load the selected configuration
                SensorConfigurationStorage.loadConfiguration(key).then((config) {
                  if (mounted) {
                    Provider.of<SensorConfigurationProvider>(context, listen: false)
                        .restoreFromJson(config);
                    // switch the tab to the first one
                    _tabController.index = 0;
                    _buildContent(context);
                  }
                });
              },
              title: Text(key),
              trailing: PlatformIconButton(
                icon: Icon(context.platformIcons.delete),
                onPressed: () async {
                    await SensorConfigurationStorage.deleteConfiguration(key);
                  if (mounted) {
                    _buildContent(context);
                  }
                },
              ),
            );
          }).toList();
        });
      }
    } else {
      setState(() {
        _content = [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("This device does not support sensors"),
          ),
        ];
      });
    }
  }

  Widget? _buildTabBar(BuildContext context) {
    if (widget.device is! SensorConfigurationManager) return null;
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      child: TabBar.secondary(
        controller: _tabController,
        tabs: const [
          Tab(text: 'New'),
          Tab(text: 'Load'),
        ],
      ),
    );
  }
}
