import 'package:flutter/material.dart';

import 'package:open_earable/apps_tab/posture_tracker/model/attitude_tracker.dart';
import 'package:open_earable/apps_tab/neck_stretch/view/stretch_tracker_view.dart';
import 'package:open_earable/apps_tab/neck_stretch/view/stretch_tutorial_view.dart';
import 'package:open_earable/apps_tab/neck_stretch/view_model/stretch_view_model.dart';
import 'package:open_earable/apps_tab/neck_stretch/model/stretch_state.dart';
import 'package:open_earable/apps_tab/neck_stretch/view/stretch_settings_view.dart';
import 'package:open_earable/apps_tab/neck_stretch/view/stretch_stats_view.dart';
import 'package:open_earable/shared/global_theme.dart';

import 'package:open_earable_flutter/open_earable_flutter.dart';

class MenuItem {
  final IconData iconData;
  final String title;
  final String description;
  final VoidCallback onTap;

  MenuItem(
      {required this.iconData,
      required this.title,
      required this.description,
      required this.onTap,});
}

class StretchAppView extends StatefulWidget {
  final AttitudeTracker _tracker;
  final OpenEarable _openEarable;

  const StretchAppView(this._tracker, this._openEarable, {super.key});

  @override
  State<StretchAppView> createState() => _StretchAppViewState();
}

/// This class is the initial view you get when opening the Stretch-App
/// It refers to all the submodules of the stretching app
class _StretchAppViewState extends State<StretchAppView> {
  late final StretchViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = StretchViewModel(widget._tracker, widget._openEarable);
  }

  List<MenuItem> stretchApps(BuildContext context) {
    return [
      MenuItem(
          iconData: Icons.play_circle,
          title: "Start Stretching",
          description: "Dive directly into the guided neck stretch!",
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => Material(
                        child: Theme(
                            data: materialTheme,
                            child: StretchTrackerView(_viewModel),),),),);
          },),
      MenuItem(
          iconData: Icons.info,
          title: "Stretch Stats",
          description: "Your stats about your last stretch.",
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => Material(
                        child: Theme(
                            data: materialTheme,
                            child: StretchStatsView(_viewModel),),),),);
          },),
      MenuItem(
          iconData: Icons.help,
          title: "How to use this Tool",
          description: "Short guide to get started with the neck stretch.",
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => Material(
                        child: Theme(
                            data: materialTheme,
                            child: StretchTutorialView(_viewModel),),),),);
          },),
      // ... similarly for other apps
    ];
  }

  @override
  Widget build(BuildContext context) {
    List<MenuItem> apps = stretchApps(context);

    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text("Guided Neck Stretch"),
          actions: [
            /// Settings button, only active when not stretching
            IconButton(
                onPressed: (_viewModel.stretchState ==
                            NeckStretchState.noStretch ||
                        _viewModel.stretchState ==
                            NeckStretchState.doneStretching)
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => Material(
                            child: Theme(
                                data: materialTheme,
                                child: SettingsView(_viewModel),),),),)
                    : null,
                icon: Icon(Icons.settings),),
          ],
        ),
        body: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: ListView.builder(
                itemCount: apps.length,
                itemBuilder: (BuildContext context, int index) {
                  return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Card(
                        color: Theme.of(context).colorScheme.primary,
                        child: Container(
                            alignment: Alignment.center,
                            height: 80,
                            child: ListTile(
                              leading: Icon(apps[index].iconData, size: 40.0),
                              title: Text(apps[index].title),
                              subtitle: Text(apps[index].description),
                              trailing:
                                  Icon(Icons.arrow_forward_ios, size: 16.0),
                              // Arrow icon on the right
                              onTap: apps[index]
                                  .onTap, // Callback when the card is tapped
                            ),),
                      ),);
                },),),);
  }
}
