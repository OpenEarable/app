// File: lib/apps/stroke_tracker/tests/touch_test.dart


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';


/// Provider to track left-right touch sequence for stroke detection.
class TouchTestProvider extends ChangeNotifier {
 final VoidCallback onComplete;
 bool _leftTapped = false;
 bool _rightTapped = false;


 bool get leftTapped => _leftTapped;
 bool get rightTapped => _rightTapped;
 bool get isComplete => _leftTapped && _rightTapped;


 StreamSubscription? _leftSub;
 StreamSubscription? _rightSub;


 TouchTestProvider({required this.onComplete});


 /// Subscribe to the touch sensor streams on each manager.
 void startListening({
   required SensorManager leftManager,
   required SensorManager rightManager,
 }) {
   final leftTouch = leftManager.sensors.firstWhere(
     (s) => s.sensorName.toLowerCase().contains('touch'),
   );
   final rightTouch = rightManager.sensors.firstWhere(
     (s) => s.sensorName.toLowerCase().contains('touch'),
   );


   _leftSub = leftTouch.sensorStream.listen((_) {
     if (!_leftTapped) {
       _leftTapped = true;
       notifyListeners();
     }
   });


   _rightSub = rightTouch.sensorStream.listen((_) {
     if (_leftTapped && !_rightTapped) {
       _rightTapped = true;
       notifyListeners();
       onComplete();
     }
   });
 }


 /// Cancel subscriptions.
 void stopListening() {
   _leftSub?.cancel();
   _rightSub?.cancel();
 }


 /// Reset state and subscriptions.
 void reset() {
   stopListening();
   _leftTapped = false;
   _rightTapped = false;
   notifyListeners();
 }
}


/// Widget for the stroke touch test using two earable devices.
class TouchTest extends StatefulWidget {
 final String title;
 final SensorManager leftManager;
 final SensorManager rightManager;
 final VoidCallback onCompleted;


 const TouchTest({
   Key? key,
   this.title = 'Stroke Touch Test',
   required this.leftManager,
   required this.rightManager,
   required this.onCompleted,
 }) : super(key: key);


 @override
 _TouchTestState createState() => _TouchTestState();
}


class _TouchTestState extends State<TouchTest> {
 late final TouchTestProvider provider;


 @override
 void initState() {
   super.initState();
   provider = TouchTestProvider(onComplete: widget.onCompleted);
   provider.startListening(
     leftManager: widget.leftManager,
     rightManager: widget.rightManager,
   );
 }


 @override
 void dispose() {
   provider.stopListening();
   super.dispose();
 }


 @override
 Widget build(BuildContext context) {
   return ChangeNotifierProvider.value(
     value: provider,
     child: Consumer<TouchTestProvider>(
       builder: (_, p, __) {
         String instruction;
         if (!p.leftTapped) {
           instruction = 'Tap the LEFT earable';
         } else if (!p.rightTapped) {
           instruction = 'Now tap the RIGHT earable';
         } else {
           instruction = 'Test complete! 🎉';
         }


         return Scaffold(
           appBar: AppBar(title: Text(widget.title)),
           body: Center(child: Text(instruction, style: TextStyle(fontSize: 24))),
           floatingActionButton: p.isComplete
               ? FloatingActionButton(
                   onPressed: provider.reset,
                   child: Icon(Icons.refresh),
                 )
               : null,
         );
       },
     ),
   );
 }
}



