import 'package:flutter/material.dart';

/// A no-op placeholder for the direction test,
/// so you can verify your UI & navigation without the sensor logic.
class DirectionTestPlaceholder extends StatelessWidget {
  final VoidCallback onCompleted;

  const DirectionTestPlaceholder({
    Key? key,
    required this.onCompleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // You can replace this with an Icon or image of an arrow if you like:
        const Text(
          "👉  Please turn your head to the LEFT  👈",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: onCompleted,
          child: const Text("Done"),
        ),
      ],
    );
  }
}
