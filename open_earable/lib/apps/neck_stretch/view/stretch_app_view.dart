import 'package:flutter/material.dart';

import 'package:open_earable/apps_tab.dart';
import 'package:open_earable/apps/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable/apps/neck_stretch/view/stretch_tracker_view.dart';
import 'package:open_earable/apps/neck_stretch/view/stretch_tutorial_view.dart';
import 'package:open_earable/apps/neck_stretch/view_model/stretch_view_model.dart';
import 'package:open_earable/apps/neck_stretch/model/stretch_state.dart';
import 'package:open_earable/apps/neck_stretch/view/stretch_settings_view.dart';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class StretchAppView extends StatefulWidget {
  final AttitudeTracker _tracker;
  final OpenEarable _openEarable;

  StretchAppView(this._tracker, this._openEarable);

  @override
  State<StretchAppView> createState() => _StretchAppViewState();
}

/// This class is the initial view you get when opening the Stretch-App
/// It refers to the tutorial page and the actual stretching page
class _StretchAppViewState extends State<StretchAppView> {
  late final StretchViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    this._viewModel = StretchViewModel(widget._tracker, widget._openEarable);
  }

  List<AppInfo> stretchApps(BuildContext context) {
    return [
      AppInfo(
          iconData: Icons.play_circle,
          title: "Start Stretching",
          description: "Dive directly into the guided neck stretch!",
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        StretchTrackerView(this._viewModel)));
          }),
      AppInfo(
          iconData: Icons.help,
          title: "How to use this Tool",
          description: "Short guide to get started with the neck stretch.",
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        StretchTutorialView(this._viewModel)));
          }),
      // ... similarly for other apps
    ];
  }

  @override
  Widget build(BuildContext context) {
    List<AppInfo> apps = stretchApps(context);

    return Scaffold(
        appBar: AppBar(
          title: const Text("Guided Neck Stretch"),
          actions: [
            IconButton(
                onPressed: (this._viewModel.stretchState ==
                            NeckStretchState.noStretch ||
                        this._viewModel.stretchState ==
                            NeckStretchState.doneStretching)
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => SettingsView(this._viewModel)))
                    : null,
                icon: Icon(Icons.settings)),
          ],
        ),
        body: ListView.builder(
            itemCount: apps.length,
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Card(
                    color: Theme.of(context).colorScheme.primary,
                    child: ListTile(
                      leading: Icon(apps[index].iconData, size: 40.0),
                      title: Text(apps[index].title),
                      subtitle: Text(apps[index].description),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16.0),
                      // Arrow icon on the right
                      onTap:
                          apps[index].onTap, // Callback when the card is tapped
                    ),
                  ));
            }));
  }
}
