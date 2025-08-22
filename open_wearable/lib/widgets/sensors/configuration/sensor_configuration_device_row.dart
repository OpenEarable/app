import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_storage.dart';
import 'package:open_wearable/widgets/sensors/configuration/edge_recorder_prefix_row.dart';
import 'package:open_wearable/widgets/sensors/configuration/save_config_row.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_value_row.dart';
import 'package:provider/provider.dart';

import '../../../view_models/sensor_configuration_provider.dart';
import '../../devices/device_detail/stereo_pos_label.dart';

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
      if (!_tabController.indexIsChanging) {
        _updateContent();
      }
    });
    _content = [PlatformCircularProgressIndicator()];
    _updateContent();
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
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PlatformText(
                  device.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (device is StereoDevice)
                  StereoPosLabel(device: device as StereoDevice),
              ],
            ),
            trailing: _buildTabBar(context),
          ),
          ..._content,
        ],
      ),
    );
  }

  Future<void> _updateContent() async {
    final Wearable device = widget.device;

    if (device is! SensorConfigurationManager) {
      if (!mounted) return;
      setState(() {
        _content = [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PlatformText("This device does not support sensors"),
          ),
        ];
      });
      return;
    }

    final SensorConfigurationManager sensorManager = device as SensorConfigurationManager;

    if (_tabController.index == 0) {
      _buildNewTabContent(sensorManager);
    } else {
      await _buildLoadTabContent(sensorManager);
    }
  }

  void _buildNewTabContent(SensorConfigurationManager device) {
    final List<Widget> content = device.sensorConfigurations
        .map((config) => SensorConfigurationValueRow(sensorConfiguration: config))
        .cast<Widget>()
        .toList();

    content.addAll([
      const Divider(),
      const SaveConfigRow(),
    ]);

    if (device is EdgeRecorderManager) {
      content.addAll([
        const Divider(),
        EdgeRecorderPrefixRow(manager: device as EdgeRecorderManager),
      ]);
    }

    if (!mounted) return;
    setState(() {
      _content = content;
    });
  }

  Future<void> _buildLoadTabContent(SensorConfigurationManager device) async {
    if (!mounted) return;
    setState(() {
      _content = [PlatformCircularProgressIndicator()];
    });

    final configKeys = await SensorConfigurationStorage.listConfigurationKeys();

    if (!mounted) return;

    if (configKeys.isEmpty) {
      setState(() {
        _content = [
          PlatformListTile(title: PlatformText("No configurations found")),
        ];
      });
      return;
    }

    final widgets = configKeys.map((key) {
      return PlatformListTile(
        title: PlatformText(key),
        onTap: () async {
          final config = await SensorConfigurationStorage.loadConfiguration(key);
          if (!mounted) return;

          final result = await Provider.of<SensorConfigurationProvider>(context, listen: false)
              .restoreFromJson(config);

          if (!result && mounted) {
            showPlatformDialog(
              context: context,
              builder: (_) => PlatformAlertDialog(
                title: PlatformText("Error"),
                content: PlatformText("Failed to load configuration: $key"),
                actions: [
                  PlatformDialogAction(
                    child: PlatformText("OK"),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            );
            return;
          }

          _tabController.index = 0;
          _updateContent();
        },
        trailing: PlatformIconButton(
          icon: Icon(context.platformIcons.delete),
          onPressed: () async {
            await SensorConfigurationStorage.deleteConfiguration(key);
            if (mounted) _updateContent();
          },
        ),
      );
    }).toList();

    setState(() {
      _content = widgets;
    });
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
