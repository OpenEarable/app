import 'package:flutter/material.dart';

class DirectionTest extends StatelessWidget {
  final VoidCallback onCompleted;
  const DirectionTest({Key? key, required this.onCompleted}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Turn your head in the direction the sound played.",
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
      ],
    );
  }
}
