import 'package:flutter/material.dart';

class AppBanner extends StatelessWidget {
  final Widget content;
  final Color backgroundColor;

  const AppBanner({
    super.key,
    required this.content,
    this.backgroundColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: content,
      ),
    );
  }
}
