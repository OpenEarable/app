import 'package:flutter/material.dart';
import 'package:open_earable/apps/star_finder/model/attitude_tracker.dart';
import 'package:open_earable/apps/star_finder/model/right_direction.dart';
import 'package:open_earable/apps/star_finder/model/star_object.dart';
import 'package:open_earable/apps/star_finder/view_model/star_finder_view_model.dart';
import 'package:open_earable/apps/star_finder/view/star_objects_tab.dart';
import 'package:provider/provider.dart';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';

/// This class represents the main view for the Star Finder app
/// It manages the UI and interactions for star finding functionality
class StarFinderView extends StatefulWidget {
  final AttitudeTracker _tracker; // Tracker to manage the device's attitude
  final OpenEarable _openEarable; // Earable device interface
  StarObject _starObject = StarObjectList.starObjects.first; // The star object being tracked

  StarFinderView(this._tracker, this._openEarable);

  @override
  State<StarFinderView> createState() => _StarFinderViewState();
}

class _StarFinderViewState extends State<StarFinderView> {
  late StarFinderViewModel starFinderViewModel; // ViewModel to manage the app logic

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StarFinderViewModel>(
        create: (context) => StarFinderViewModel(
            widget._tracker,
            RightDirection(
                widget._openEarable, widget._tracker, widget._starObject)),
        builder: (context, child) => Consumer<StarFinderViewModel>(
            builder: (context, starFinderViewModel, child) => Scaffold(
                  appBar: AppBar(
                    title: const Text("Star Finder"),
                    actions: [
                      IconButton(
                          onPressed: () {
                            starFinderViewModel.stopTracking();
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) =>
                                    StarObjectsTab(starFinderViewModel)));
                          },
                          icon: Icon(Icons.star)),
                    ],
                  ),
                  body: Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        // Create StarObject Name Text
                        Text("${starFinderViewModel.starObject.name}",
                            style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onBackground,
                                fontSize: 50,
                                fontWeight: FontWeight.bold)),
                        // If you want the roll, yaw and pitch data to be displayed on screen for testing, uncomment this lines
                        //
                        //Text("Attitude ${(starFinderViewModel.attitude.roll).toStringAsFixed(0)},${(starFinderViewModel.attitude.pitch ).toStringAsFixed(0)},${(starFinderViewModel.attitude.yaw).toStringAsFixed(0)} \n StarObject ${(starFinderViewModel.starObject.eulerAngle.roll).toStringAsFixed(0)},${(starFinderViewModel.starObject.eulerAngle.pitch).toStringAsFixed(0)},${(starFinderViewModel.starObject.eulerAngle.yaw).toStringAsFixed(0)} \n Diff ${((starFinderViewModel.attitude.roll - starFinderViewModel.starObject.eulerAngle.roll) ).toStringAsFixed(0)},${((starFinderViewModel.attitude.pitch - starFinderViewModel.starObject.eulerAngle.pitch)).toStringAsFixed(0)},${((starFinderViewModel.attitude.yaw - starFinderViewModel.starObject.eulerAngle.yaw)).toStringAsFixed(0)}",
                        //style: TextStyle(
                        //color: Theme.of(context).colorScheme.onBackground,
                        //fontSize: 10,
                        //fontWeight: FontWeight.bold)),

                        // Create StarObject Image
                        SizedBox(height: 20),
                        Image.asset(
                          starFinderViewModel.starObject.image,
                          width: 200,
                          height: 200,
                        ),
                        // Create arrow for pointing direction
                        Center(
                          child: Transform(
                              transform: Matrix4.identity()
                                ..rotateZ((starFinderViewModel.attitude.roll - starFinderViewModel.starObject.eulerAngle.roll) * (3.14 / 180))
                                ..rotateX((starFinderViewModel.attitude.pitch - starFinderViewModel.starObject.eulerAngle.pitch - 90) * (3.14 / 180)) // -90 because because default direction of arrow is up but when pointing at right direction it should point into the screen
                                ..rotateY((starFinderViewModel.attitude.yaw - starFinderViewModel.starObject.eulerAngle.yaw) * 3.14 / 180),
                              alignment: Alignment.center,
                              child: Image.asset(
                                'assets/star_finder/compass.png',
                                width: 250.0,
                                height: 250.0,
                              )),
                        ),
                        // Create Tracking Button
                        this._buildTrackingButton(starFinderViewModel),
                      ])),
                  // Change background color if looking in right direction
                  backgroundColor:
                      starFinderViewModel.rightDirection.rightDirection == true
                          ? const Color.fromARGB(255, 0, 128, 4)
                          : Theme.of(context).colorScheme.background,
                )));
  }

  /// Builds the tracking button with its functionality
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
        // The background color and Text of the button changes depending on the tracking state
        style: ElevatedButton.styleFrom(
          backgroundColor: !starFinderViewModel.isTracking
              ? Color(0xff77F2A1)
              : Color(0xfff27777),
          foregroundColor: Colors.black,
        ),
        child: starFinderViewModel.isTracking
            ? const Text("Stop Searching")
            : const Text("Start Searching"),
      ),
      // Visibility widget used to show/hide the 'No Earable Connected' message
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
