import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/posture_tracker/model/earable_attitude_tracker.dart';
import 'package:open_wearable/apps/posture_tracker/view/posture_tracker_view.dart';
import 'package:open_wearable/view_models/wearables_provider.dart';
import 'package:provider/provider.dart';

class SelectEarableView  extends StatefulWidget {
  const SelectEarableView({super.key});

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
            child: Text("Track Posture"),
            onPressed: () {
              if (_selectedWearable != null) {
                Navigator.push(
                  context,
                  platformPageRoute(
                    context: context,
                    builder: (context) {
                      return PostureTrackerView(EarableAttitudeTracker(_selectedWearable! as SensorManager,
                        _selectedWearable! as SensorConfigurationManager));
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
