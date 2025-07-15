import 'package:flutter/material.dart';
import 'dart:async';
import 'package:open_earable_flutter/open_earable_flutter.dart';


class TouchTest extends StatefulWidget {
 final String side; // 'left' or 'right'
 final VoidCallback onCompleted;
 final Wearable wearable; // pass in left or right device


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


   if (widget.wearable is ButtonManager) {
     final buttonManager = widget.wearable as ButtonManager;


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
   _buttonSub?.cancel();
   super.dispose();
 }


 @override
 Widget build(BuildContext context) {
   final instruction = widget.side == 'left'
       ? 'Please tap the LEFT earphone'
       : 'Please tap the RIGHT earphone';


   return Center(
     child: Text(
       instruction,
       textAlign: TextAlign.center,
       style: const TextStyle(fontSize: 18),
     ),
   );
 }
}
