import 'package:flutter/material.dart';
import 'dart:async';
import 'package:open_earable_flutter/open_earable_flutter.dart';

// A widget for the touch test which prompts the user to press the button
// on the left or right earphone, lisening for a ButtonEvent from the earable.

class TouchTest extends StatefulWidget {
 final String side; // 'left' or 'right'
 final VoidCallback onCompleted; // Callback when the button is pressed
 final Wearable wearable; // pass in left or right earable


 const TouchTest({
   Key? key,
   required this.side,
   required this.onCompleted,
   required this.wearable,
 }) : super(key: key);


 @override
 State<TouchTest> createState() => _TouchTestState();
}


class _TouchTestState extends State<TouchTest> {
 StreamSubscription<ButtonEvent>? _buttonSub;


 @override
 void initState() {
   super.initState();

  // Check if the provided earable supports button events
   if (widget.wearable is ButtonManager) {
     final buttonManager = widget.wearable as ButtonManager;

      // Listen for button press events
     _buttonSub = buttonManager.buttonEvents.listen((event) {
        if (event == ButtonEvent.pressed) {
          print("Button press detected on ${widget.side} earphone.");
          widget.onCompleted();
        }
     });
   } else {
     print("Error: wearable is not a ButtonManager");
   }
 }


 @override
 void dispose() {
  // Cancel the subscription when the widget is disposed
   _buttonSub?.cancel();
   super.dispose();
 }


 @override
 Widget build(BuildContext context) {
  // Displays the instruction based on the side
   final instruction = widget.side == 'left'
       ? 'Please press the LEFT earphone button'
       : 'Please press the RIGHT earphone button';


   return Center(
     child: Text(
       instruction,
       textAlign: TextAlign.center,
       style: const TextStyle(fontSize: 18),
     ),
   );
 }
}
