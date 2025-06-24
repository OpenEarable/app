import 'package:flutter/material.dart';

class CountingTest extends StatelessWidget {
  final VoidCallback onCompleted;
  const CountingTest({Key? key, required this.onCompleted}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Please count from 0 to 10 out loud."),
        const SizedBox(height: 12),
      ],
    );
  }
}
