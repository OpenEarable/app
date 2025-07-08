import 'package:flutter/material.dart';

class TouchTest extends StatelessWidget {
  final String side; // 'left' or 'right'
  final VoidCallback onCompleted;

  const TouchTest({
    Key? key,
    required this.side,
    required this.onCompleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final instruction = side == 'left'
        ? 'Please tap the LEFT earphone'
        : 'Please tap the RIGHT earphone';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          instruction,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onCompleted,
          child: Text("Tap ${side.toUpperCase()}"),
        ),
      ],
    );
  }
}
