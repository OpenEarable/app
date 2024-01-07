import 'package:flutter/material.dart';
import 'package:open_earable/apps/star_finder/model/attitude.dart';
import 'package:open_earable/apps/star_finder/model/attitude_tracker.dart';
import 'package:open_earable/apps/star_finder/model/right_direction.dart';
import 'package:open_earable/apps/star_finder/model/star_object.dart';
import 'package:open_earable/apps/star_finder/view_model/star_finder_view_model.dart';
import 'package:open_earable/apps/star_finder/view/star_objects_tab.dart';
import 'package:provider/provider.dart';

import 'package:open_earable_flutter/src/open_earable_flutter.dart';

class StarFinderView extends StatefulWidget {
  final AttitudeTracker _tracker;
  final OpenEarable _openEarable;
  StarObject _starObject = StarObjectList.starObjects.first;


  StarFinderView(this._tracker, this._openEarable);

  @override
  State<StarFinderView> createState() => _StarFinderViewState();
}


class _StarFinderViewState extends State<StarFinderView> {

  late StarFinderViewModel starFinderViewModel;
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StarFinderViewModel>(
        create: (context) => StarFinderViewModel(widget._tracker, RightDirection(widget._openEarable,
             widget._tracker, widget._starObject)),
        builder: (context, child) => Consumer<StarFinderViewModel>(
            builder: (context, starFinderViewModel, child) => Scaffold(
                  appBar: AppBar(
                    title: const Text("Star Finder"),
                    actions: [
                      IconButton(
                          onPressed: () {starFinderViewModel.stopTracking();
                          Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) =>
                                      StarObjectsTab(starFinderViewModel)));},
                          icon: Icon(Icons.star)),
                    ],
                  ),
                  body: Center( child:
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        //${(starFinderViewModel.attitude.x).toStringAsFixed(0)},${(starFinderViewModel.attitude.y).toStringAsFixed(0)},${(starFinderViewModel.attitude.z).toStringAsFixed(0)
                       Text("${starFinderViewModel.starObject.name}",
                       style: TextStyle(
                        // use proper color matching the background
                         color: Theme.of(context).colorScheme.onBackground,
                       fontSize: 50,
                       fontWeight: FontWeight.bold)),
                        //Text("Attitude ${(starFinderViewModel.attitude.roll).toStringAsFixed(0)},${(starFinderViewModel.attitude.pitch ).toStringAsFixed(0)},${(starFinderViewModel.attitude.yaw).toStringAsFixed(0)} \n StarObject ${(starFinderViewModel.starObject.eulerAngle.roll).toStringAsFixed(0)},${(starFinderViewModel.starObject.eulerAngle.pitch).toStringAsFixed(0)},${(starFinderViewModel.starObject.eulerAngle.yaw).toStringAsFixed(0)} \n Diff ${((starFinderViewModel.attitude.roll - starFinderViewModel.starObject.eulerAngle.roll) ).toStringAsFixed(0)},${((starFinderViewModel.attitude.pitch - starFinderViewModel.starObject.eulerAngle.pitch)).toStringAsFixed(0)},${((starFinderViewModel.attitude.yaw - starFinderViewModel.starObject.eulerAngle.yaw)).toStringAsFixed(0)}",
                       //style: TextStyle(
                        // use proper color matching the background
                        //color: Theme.of(context).colorScheme.onBackground,
                        //fontSize: 30,
                        //fontWeight: FontWeight.bold)),
                        //SizedBox(height: 20),
            Image.asset(starFinderViewModel.starObject.image,
              width: 200,
              height: 200,
            ),
                        Center(
                          child: Transform(
                           transform: Matrix4.identity()
                             ..rotateZ((starFinderViewModel.attitude.roll - starFinderViewModel.starObject.eulerAngle.roll) * (3.14 / 180) )
                             ..rotateX((starFinderViewModel.attitude.pitch - starFinderViewModel.starObject.eulerAngle.pitch - 90) * (3.14 / 180))
                             ..rotateY((starFinderViewModel.attitude.yaw - starFinderViewModel.starObject.eulerAngle.yaw) * 3.14 / 180),
                           alignment: Alignment.center,
                            child: Image.asset('assets/star_finder/compass.png', 
                            width: 250.0, // You can set a specific width if needed
                            height: 250.0, // You can set a specific height if needed), 
                         )),
                       ),
                       this._buildTrackingButton(starFinderViewModel),
                     ])),
                  backgroundColor: starFinderViewModel.rightDirection.rightDirection == true
                      ? const Color.fromARGB(255, 0, 128, 4)
                      : Theme.of(context).colorScheme.background,
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
            ? const Text("Stop Searching")
            : const Text("Start Searching"),
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