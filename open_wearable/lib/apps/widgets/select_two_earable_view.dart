// File: lib/apps/widgets/select_two_earable_view.dart
// This file defines the dual-picker for the Stroke Test app.

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';

/// A screen to pick two earables (left & right) before running stroke tests
class SelectTwoEarableView extends StatefulWidget {
  /// Callback invoked when both earables are selected.
  /// Provides: (leftWearable, leftConfigProv, rightWearable, rightConfigProv)
  final Widget Function(
    Wearable leftWearable,
    SensorConfigurationProvider leftProv,
    Wearable rightWearable,
    SensorConfigurationProvider rightProv,
  ) startApp;

  const SelectTwoEarableView({Key? key, required this.startApp}) : super(key: key);

  @override
  State<SelectTwoEarableView> createState() => _SelectTwoEarableViewState();
}

class _SelectTwoEarableViewState extends State<SelectTwoEarableView> {
  Wearable? _left;
  Wearable? _right;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<WearablesProvider>();
    return PlatformScaffold(
      appBar: PlatformAppBar(title: Text('Select Earables')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left device picker
            Text('Left Earable', style: Theme.of(context).textTheme.titleMedium),
            ...prov.wearables.map((w) => PlatformListTile(
                  title: Text(w.name),
                  trailing: _left == w ? Icon(context.platformIcons.checkMark) : null,
                  onTap: () => setState(() => _left = w),
                )),

            const SizedBox(height: 16),

            // Right device picker
            Text('Right Earable', style: Theme.of(context).textTheme.titleMedium),
            ...prov.wearables.map((w) => PlatformListTile(
                  title: Text(w.name),
                  trailing: _right == w ? Icon(context.platformIcons.checkMark) : null,
                  onTap: () => setState(() => _right = w),
                )),


            PlatformElevatedButton(
              child: Text('Start Test'),
              onPressed: (_left != null && _right != null)
                  ? () {
                      final leftProv = prov.getSensorConfigurationProvider(_left!);
                      final rightProv = prov.getSensorConfigurationProvider(_right!);
                      Navigator.of(context).push(platformPageRoute(
                        context: context,
                        builder: (_) => MultiProvider(
                          providers: [
                            ChangeNotifierProvider.value(value: leftProv),
                            ChangeNotifierProvider.value(value: rightProv),
                          ],
                          child: widget.startApp(_left!, leftProv, _right!, rightProv),
                        ),
                      ));
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
