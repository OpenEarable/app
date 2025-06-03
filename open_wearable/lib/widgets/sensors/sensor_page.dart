import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/widgets/sensors/configuration/sensor_configuration_view.dart';
import 'package:open_wearable/widgets/sensors/values/sensor_values_page.dart';

/// Which tab is currently selected.
enum _SensorsTab { configurations, charts }

class SensorPage extends StatefulWidget {
  const SensorPage({super.key});

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  _SensorsTab _current = _SensorsTab.configurations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            title: const Text('Sensors'),
            floating: true,
            snap: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: _buildSegmentedControl(),
            ),
          ),
        ],
        body: _buildBody(),
      ),
    );
  }

  // MARK: Segmented Control
  Widget _buildSegmentedControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: PlatformWidget(
        cupertino: (_, __) => CupertinoSlidingSegmentedControl<_SensorsTab>(
          groupValue: _current,
          children: const {
            _SensorsTab.configurations: Text('Configurations'),
            _SensorsTab.charts:        Text('Charts'),
          },
          onValueChanged: (v) {
            if (v != null) setState(() => _current = v);
          },
        ),
        material: (_, __) => SegmentedButton<_SensorsTab>(
          segments: const [
            ButtonSegment(
              value: _SensorsTab.configurations,
              label: Text('Configuration'),
            ),
            ButtonSegment(
              value: _SensorsTab.charts,
              label: Text('Charts'),
            ),
          ],
          selected: {_current},
          onSelectionChanged: (s) =>
            setState(() => _current = s.first),
        ),
      ),
    );
  }

  // MARK: Tab Body
  Widget _buildBody() {
    switch (_current) {
      case _SensorsTab.charts:
        return SensorValuesPage();
      case _SensorsTab.configurations:
        return SensorConfigurationView(
          onSetConfigPressed: () => setState(() => _current = _SensorsTab.charts),
        );
    }
  }
}
