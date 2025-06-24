import 'package:flutter/material.dart';

class RepetitionTest extends StatelessWidget {
  final VoidCallback onCompleted;
  const RepetitionTest({Key? key, required this.onCompleted}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Repeat: Today is a sunny day.\nRepeat: The quick brown fox jumps over the lazy dog."),
        const SizedBox(height: 12),
      ],
    );
  }
}
