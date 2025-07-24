import 'package:flutter/material.dart';

// This widget tests the user's ability to perform mouth movements
// by prompting them to hold a neutral expression and then smile when instructed.
// It is meant to detect any asymmetry or other issues in facial muscle control,
// which can be important for stroke recovery and rehabilitation.

// Currently in a work in progress state, as edgeML is unable to process our data
// at this time.

class MouthMovementTest extends StatelessWidget {
  final VoidCallback onCompleted;

  const MouthMovementTest({Key? key, required this.onCompleted}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Hold a neutral expression,\nthen smile when prompted.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onCompleted,
          child: const Text("Done"),
        ),
      ],
    );
  }
}
