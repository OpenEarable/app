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
    return Column(
      children: [
        // MARK: Segmented control
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: PlatformWidget(
            cupertino: (_, __) => CupertinoSlidingSegmentedControl<_SensorsTab>(
              groupValue: _current,
              children: const {
              _SensorsTab.configurations: Text('Configurations'),
              _SensorsTab.charts: Text('Charts'),
              },
              onValueChanged: (value) {
                if (value != null) {
                  setState(() {
                    _current = value;
                  });
                }
              },
            ),
            material: (_, __) => SizedBox(
              width: double.infinity,
              child: SegmentedButton<_SensorsTab>(
                emptySelectionAllowed: false,
                multiSelectionEnabled: false,
                segments: const [
                  ButtonSegment<_SensorsTab>(
                  value: _SensorsTab.configurations,
                  label: Text('Configuration'),
                  ),
                  ButtonSegment<_SensorsTab>(
                  value: _SensorsTab.charts,
                  label: Text('Charts'),
                  ),
                ],
                selected: {_current},
                onSelectionChanged: (Set<_SensorsTab> newSelection) {
                  setState(() {
                    _current = newSelection.first;
                  });
                },
              ),
            ),
          ),
        ),
        // MARK: Tab Body
        Expanded(
          child: _current == _SensorsTab.configurations
            ? SensorConfigurationView(
              onSetConfigPressed: () => setState(() => _current = _SensorsTab.charts),
            )
            : SensorValuesPage(),
        ),
      ],
    );
  }
}
