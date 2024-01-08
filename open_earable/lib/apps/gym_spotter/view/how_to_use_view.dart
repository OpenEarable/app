import 'package:flutter/material.dart';

import 'package:open_earable/apps/gym_spotter/view/return_button.dart';

// This Widget gets shown after the "howToUse" button gets pressed,

class HowToUse extends StatelessWidget {
  // the Instructions on how to use the App
  static const List<String> _instructions = [
    "Step 1: Click the calibrate button and calibrate the app by performing a clean deadlift without weights on the bar",
    "Step 2: Get in your deaflift position ready to lift the bar and wait there until you hear a jingle",
    "Step 3: Do your lift, the app detects when you are done with it. The app is now calibrated",
    "Step 4: After calibration you can now record a set by clicking the record button, it will turn red upon recording",
    "Step 5: Repeat step 2 and do your lift",
    "Step 6: After your repetition you will get visual and audio feedback on your form",
    "Step 7: If you want to make more repetitions in succession, stand still in your foward bended position, after a rep, and wait for the jingle to start the next rep",
    "Step 8: Stop the recording after your set",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text('Deadlift Spotter'),
      ),

      // Return button on bottom right for easy navigation
      floatingActionButton: returnButton(),

      // Scrollable body in case the screen is not big enough to fit all steps
      body: ListView(
        children: [
          // headline of route
          Padding(
            padding: EdgeInsets.fromLTRB(0, 20, 0, 20),
            child: DefaultTextStyle(
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 40,
                color: Theme.of(context).colorScheme.onBackground,
              ),
              child: Text("How to use"),
            ),
          ),
          // Add all instructions below headline
          for (String i in _instructions) getTab(i, context)
        ],
      ),
    );
  }

  // Text widget with Padding and decoration to show boxes of texts below each other
  // in this case the instructions on how to use the app.
  Widget getTab(String i, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          color: Theme.of(context).colorScheme.primary,
        ),
        padding: EdgeInsets.all(8.0),
        alignment: Alignment.center,
        child: DefaultTextStyle(
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            color: Theme.of(context).colorScheme.onBackground,
          ),
          child: Text(i),
        ),
      ),
    );
  }
}
