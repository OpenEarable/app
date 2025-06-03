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
    return NestedScrollView(
      floatHeaderSlivers: true,
      headerSliverBuilder: (context, _) => [
        SliverAppBar(
          title: const Text('Sensors'),
          pinned: true,
        ),

        SliverPersistentHeader(
          floating: true,
          delegate: _SegmentsHeader(
            current: _current,
            onChanged: (tab) => setState(() => _current = tab),
          ),
        ),
      ],
      body: _buildBody(),
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

// MARK: Segmented Control Header
class _SegmentsHeader extends SliverPersistentHeaderDelegate {
  final _SensorsTab current;
  final ValueChanged<_SensorsTab> onChanged;
  
  _SegmentsHeader({
    required this.current,
    required this.onChanged,
  });

  @override
  double get minExtent => kToolbarHeight;
  @override
  double get maxExtent => kToolbarHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final segmented = PlatformWidget(
      cupertino: (_, __) => CupertinoSlidingSegmentedControl<_SensorsTab>(
        groupValue: current,
        children: const {
          _SensorsTab.configurations: Text('Configurations'),
          _SensorsTab.charts:        Text('Charts'),
        },
        onValueChanged: (val) {
          if (val != null) onChanged(val);
        },
      ),
      material: (_, __) => SizedBox(
        width: double.infinity,
        child: SegmentedButton<_SensorsTab>(
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
          selected: {current},
          onSelectionChanged: (set) => onChanged(set.first),
        ),
      ),
    );

    return Container(
      alignment: Alignment.center,
      // color: Colors.blue,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: segmented,
    );
  }

  @override
  bool shouldRebuild(covariant _SegmentsHeader oldDelegate) =>
      oldDelegate.current != current;
}
