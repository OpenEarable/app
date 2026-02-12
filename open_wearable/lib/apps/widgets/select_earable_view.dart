import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/widgets/app_compatibility.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:provider/provider.dart';

class SelectEarableView extends StatefulWidget {
  /// Callback to start the app
  /// -- [wearable] the selected wearable
  /// returns a [Widget] of the home page of the app
  final Widget Function(Wearable, SensorConfigurationProvider) startApp;
  final List<String> supportedDevicePrefixes;

  const SelectEarableView({
    super.key,
    required this.startApp,
    this.supportedDevicePrefixes = const [],
  });

  @override
  State<SelectEarableView> createState() => _SelectEarableViewState();
}

class _SelectEarableViewState extends State<SelectEarableView> {
  Wearable? _selectedWearable;

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText("Select Wearable"),
      ),
      body: Consumer(
        builder: (context, WearablesProvider wearablesProvider, child) =>
            _buildBody(context, wearablesProvider),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WearablesProvider wearablesProvider,
  ) {
    final compatibleWearables = wearablesProvider.wearables
        .where(
          (wearable) => wearableIsCompatibleWithApp(
            wearableName: wearable.name,
            supportedDevicePrefixes: widget.supportedDevicePrefixes,
          ),
        )
        .toList(growable: false);

    final hasSelectedCompatibleWearable = _selectedWearable != null &&
        compatibleWearables.contains(_selectedWearable);

    return Column(
      children: [
        Expanded(
          child: compatibleWearables.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      'No compatible wearables connected for this app.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: compatibleWearables.length,
                  itemBuilder: (context, index) {
                    final wearable = compatibleWearables[index];
                    return PlatformListTile(
                      title: PlatformText(wearable.name),
                      subtitle: PlatformText(wearable.deviceId),
                      trailing: _selectedWearable == wearable
                          ? Icon(Icons.check)
                          : null,
                      onTap: () => setState(() {
                        _selectedWearable = wearable;
                      }),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: PlatformElevatedButton(
              onPressed: hasSelectedCompatibleWearable
                  ? () {
                      Navigator.push(
                        context,
                        platformPageRoute(
                          context: context,
                          builder: (context) {
                            return ChangeNotifierProvider.value(
                              value: wearablesProvider
                                  .getSensorConfigurationProvider(
                                _selectedWearable!,
                              ),
                              child: widget.startApp(
                                _selectedWearable!,
                                wearablesProvider
                                    .getSensorConfigurationProvider(
                                  _selectedWearable!,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }
                  : null,
              child: PlatformText("Start App"),
            ),
          ),
        ),
      ],
    );
  }
}
