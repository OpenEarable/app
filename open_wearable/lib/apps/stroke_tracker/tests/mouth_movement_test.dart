import 'package:flutter/material.dart';

class MouthMovementTest extends StatelessWidget {
  final VoidCallback onCompleted;
  const MouthMovementTest({Key? key, required this.onCompleted}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Hold a neutral expression,\nthen smile when prompted."),
        const SizedBox(height: 12),
      ],
    );
  }
}
