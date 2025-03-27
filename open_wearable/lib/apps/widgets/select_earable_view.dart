import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:provider/provider.dart';

class SelectEarableView  extends StatefulWidget {
  /// Callback to start the app
  /// -- [wearable] the selected wearable
  /// returns a [Widget] of the home page of the app
  final Widget Function(Wearable) startApp;

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
        title: Text("Select Earable"),
      ),
      body: Column(
        children: [
          Consumer(
            builder: (context, WearablesProvider wearablesProvider, child) {
              return ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: wearablesProvider.wearables.length,
                itemBuilder: (context, index) {
                  Wearable wearable = wearablesProvider.wearables[index];
                  return PlatformListTile(
                    title: Text(wearable.name),
                    subtitle: Text(wearable.deviceId), //TODO: use device ID
                    trailing: _selectedWearable == wearable
                        ? Icon(Icons.check)
                        : null,
                    onTap: () => setState(() {
                      _selectedWearable = wearable;
                    }),
                  );
                },
              );
            },
          ),

          PlatformElevatedButton(
            child: Text("Start App"),
            onPressed: () {
              if (_selectedWearable != null) {
                Navigator.push(
                  context,
                  platformPageRoute(
                    context: context,
                    builder: (context) {
                      return widget.startApp(_selectedWearable!);
                    }
                  )
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
