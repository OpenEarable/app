import 'package:flutter/material.dart';

class EmptyRecordingsState extends StatelessWidget {
  const EmptyRecordingsState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.warning, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No recordings found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
