import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:provider/provider.dart';

class SelectEarableView  extends StatefulWidget {
  /// Callback to start the app
  /// -- [wearable] the selected wearable
  /// returns a [Widget] of the home page of the app
  final Widget Function(Wearable, SensorConfigurationProvider) startApp;

  const SelectEarableView({super.key, required this.startApp});

  @override
  State<SelectEarableView> createState() => _SelectEarableViewState();
}

class _SelectEarableViewState extends State<SelectEarableView> {
  Wearable? _selectedWearable;

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: PlatformText("Select Earable"),
      ),
      body: Consumer(
        builder: (context, WearablesProvider wearablesProvider, child) =>
          Column(
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: wearablesProvider.wearables.length,
                itemBuilder: (context, index) {
                  Wearable wearable = wearablesProvider.wearables[index];
                  return PlatformListTile(
                    title: PlatformText(wearable.name),
                    subtitle: PlatformText(wearable.deviceId), //TODO: use device ID
                    trailing: _selectedWearable == wearable
                        ? Icon(Icons.check)
                        : null,
                    onTap: () => setState(() {
                      _selectedWearable = wearable;
                    }),
                  );
                },
              ),

              PlatformElevatedButton(
                child: PlatformText("Start App"),
                onPressed: () {
                  if (_selectedWearable != null) {
                    Navigator.push(
                      context,
                      platformPageRoute(
                        context: context,
                        builder: (context) {
                          return ChangeNotifierProvider.value(
                            value: wearablesProvider.getSensorConfigurationProvider(_selectedWearable!),
                            child: widget.startApp(
                              _selectedWearable!, 
                              wearablesProvider.getSensorConfigurationProvider(_selectedWearable!),
                            ),
                          );
                        },
                      ),
                    );
                  }
                },
              ),
            ],
          ),
      ),
    );
  }
}
