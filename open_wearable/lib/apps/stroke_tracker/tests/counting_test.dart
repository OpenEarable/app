import 'package:flutter/material.dart';

class CountingTest extends StatefulWidget {
  final VoidCallback onCompleted;

  const CountingTest({Key? key, required this.onCompleted}) : super(key: key);

  @override
  State<CountingTest> createState() => _CountingTestState();
}

class _CountingTestState extends State<CountingTest> {
  bool _completed = false;

  void _finishTest() {
    setState(() {
      _completed = true;
    });
    Future.delayed(const Duration(milliseconds: 500), widget.onCompleted);
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 10),
            Text("Thank you!", style: TextStyle(fontSize: 20)),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Please count out loud from 1 to 10.",
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _finishTest,
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }
}
