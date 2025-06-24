import 'package:flutter/material.dart';

class TestProgressBubbles extends StatelessWidget {
  final int currentIndex;
  final Map<int, List<int>> testRanges;

  const TestProgressBubbles({
    Key? key,
    required this.currentIndex,
    required this.testRanges,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: testRanges.entries.map((entry) {
        final isActive = entry.value.contains(currentIndex);
        return CircleAvatar(
          radius: 8,
          backgroundColor: isActive ? Colors.blue : Colors.grey[300],
        );
      }).toList(),
    );
  }
}
