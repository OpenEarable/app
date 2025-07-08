import 'package:flutter/material.dart';

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
