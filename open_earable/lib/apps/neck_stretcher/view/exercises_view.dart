import 'package:flutter/material.dart';
import 'package:open_earable/apps/neck_stretcher/view/front_back_stretch_view.dart';
import 'package:open_earable/apps/neck_stretcher/view/side_stretch_view.dart';
import 'package:open_earable_flutter/src/open_earable_flutter.dart';
import 'package:open_earable/apps/neck_stretcher/model/earable_attitude_tracker.dart';

import '../../neck_stretcher/model/attitude_tracker.dart';

/// widget to choose exercises
class ExercisesView extends StatelessWidget {
  final AttitudeTracker _tracker;
  final OpenEarable _openEarable;

  ExercisesView(this._tracker, this._openEarable);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Neck Stretcher"),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              height: 50,
            ),
            Text(
              "Choose an Exercise",
              style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 70,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                this._buildSideExercise(context),
                SizedBox(
                  width: 16,
                ),
                this._buildFrontBackEx(context),
              ],
            )
          ],
        ));
  }

  /// side to side exercise
  Widget _buildSideExercise(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => SideStretcherView(
                    EarableAttitudeTracker_Stretcher(this._openEarable),
                    this._openEarable)));
      },
      child: Card(
        color: Colors.grey[800],
        elevation: 50,
        shadowColor: Colors.black,
        child: SizedBox(
          width: 150,
          height: 330,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Text(
                  "Side to Side",
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                ),
                CircleAvatar(
                  radius: 100,
                  child: CircleAvatar(
                    backgroundImage:
                        Image.asset("assets/posture_tracker/Head_Front.png")
                            .image,
                    radius: 87,
                    backgroundColor: Colors.green,
                  ),
                ),
                Text(
                  "Stretch your neck from side to side to release tension.",
                  style: TextStyle(fontSize: 13.0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// front back exercise
  Widget _buildFrontBackEx(BuildContext context) {
    return GestureDetector(
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => FrontBackStretcherView(
                      EarableAttitudeTracker_Stretcher(this._openEarable),
                      this._openEarable)));
        },
        child: Card(
          color: Colors.grey[800],
          elevation: 50,
          shadowColor: Colors.black,
          child: SizedBox(
            width: 150,
            height: 330,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Text(
                    "Front to Back",
                    style:
                        TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                  ),
                  CircleAvatar(
                    radius: 100,
                    child: CircleAvatar(
                      backgroundImage:
                          Image.asset("assets/posture_tracker/Head_Side.png")
                              .image,
                      radius: 85,
                      backgroundColor: Colors.green,
                    ),
                  ),
                  Text(
                    "Stretch your neck from the front to the back and the other way around.",
                    style: TextStyle(fontSize: 13.0),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
