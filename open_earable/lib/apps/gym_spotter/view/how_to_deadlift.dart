import 'package:flutter/material.dart';
import 'package:open_earable/apps/gym_spotter/view/return_button.dart';

// This Widget gets shown after the "howToDeadlift" button gets pressed,

class HowToDeadLift extends StatelessWidget {
  // the Instructions on how to deadlift properly
  static const List<String> _instructions = [
    "Step 1: Stand shoulder-width apart and place your mid-foots below the bar",
    "Step 2: Bend over and grab the bar just outside your knees",
    "Step 3: Bend your knees until your shin touches the bar",
    "Step 4: Squeeze your shoulder blades together to lift your chest up",
    "Step 5: Make sure your back is straight by engaging your core. Your head should be an extention your spine",
    "Step 6: Lift the bar up by pushing your feet through the floor untill the bar passes your knees",
    "Step 7: Finish the lift by pushing your hips forward",
    "Step 8: To lower the bar again push your hips back untill the bar passes your knee, then bend your knees untill the plates hit the ground",
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
              child: Text("How to Deadlift"),
            ),
          ),

          // Add all instructions below headline
          for (String i in _instructions) getTab(i, context),
        ],
      ),
    );
  }

  // Text widget with Padding and decoration to show boxes of texts below each other
  // in this case the instructions on how do a proper deadlift.
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
