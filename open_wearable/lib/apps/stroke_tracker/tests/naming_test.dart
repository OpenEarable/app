import 'package:flutter/material.dart';

class NamingTest extends StatelessWidget {
  final VoidCallback onCompleted;

  const NamingTest({Key? key, required this.onCompleted}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Please name the large gray animal that roams in Africa.",
          style: TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: onCompleted,
          child: const Text("Complete Test"),
        ),
      ],
    );
  }
}