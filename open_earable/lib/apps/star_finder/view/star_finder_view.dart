import 'package:flutter/material.dart';
import 'package:open_earable/apps/star_finder/model/attitude.dart';
import 'package:open_earable/apps/star_finder/model/attitude_tracker.dart';
import 'package:open_earable/apps/star_finder/view_model/star_finder_view_model.dart';
import 'package:provider/provider.dart';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class StarFinderView extends StatefulWidget {
  final AttitudeTracker _tracker;
  final OpenEarable _openEarable;


  StarFinderView(this._tracker, this._openEarable);

  @override
  State<StarFinderView> createState() => _StarFinderViewState();
}


class _StarFinderViewState extends State<StarFinderView> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StarFinderViewModel>(
        create: (context) => StarFinderViewModel(widget._tracker),
        builder: (context, child) => Consumer<StarFinderViewModel>(
            builder: (context, starFinderViewModel, child) => Scaffold(
                  appBar: AppBar(
                    title: const Text("Star Finder"),
                    //actions: [
                    //  IconButton(
                    //      onPressed: () => Navigator.of(context).push(
                    //          MaterialPageRoute(
                    //              builder: (context) =>
                    //                  SettingsView(postureTrackerViewModel))),
                    //      icon: Icon(Icons.settings)),
                    //],
                  ),
                  body: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text("${(starFinderViewModel.attitude.x).abs().toStringAsFixed(0)},${(starFinderViewModel.attitude.y).abs().toStringAsFixed(0)},${(starFinderViewModel.attitude.z).abs().toStringAsFixed(0)}",
          style: TextStyle(
              // use proper color matching the background
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 30,
              fontWeight: FontWeight.bold)),
              this._buildTrackingButton(starFinderViewModel),
                    //child: this._buildContentView(starFinderViewModel),
                  ]),
                    
                  backgroundColor: Theme.of(context).colorScheme.background,
                )));
  }

  Widget _buildTrackingButton(StarFinderViewModel starFinderViewModel) {
    return Column(children: [
      ElevatedButton(
        onPressed: starFinderViewModel.isAvailable
            ? () {
                starFinderViewModel.isTracking
                    ? starFinderViewModel.stopTracking()
                    : starFinderViewModel.startTracking();
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: !starFinderViewModel.isTracking
              ? Color(0xff77F2A1)
              : Color(0xfff27777),
          foregroundColor: Colors.black,
        ),
        child: starFinderViewModel.isTracking
            ? const Text("Stop Tracking")
            : const Text("Start Tracking"),
      ),
      Visibility(
        visible: !starFinderViewModel.isAvailable,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: Text(
          "No Earable Connected",
          style: TextStyle(
            color: Colors.red,
            fontSize: 12,
          ),
        ),
      )
    ]);
  }

}