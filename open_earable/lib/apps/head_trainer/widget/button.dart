import 'package:flutter/material.dart';

class Button extends StatelessWidget {
  const Button({required this.text, required this.onPressed});

  final String text;
  final Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          foregroundColor: Colors.black,
          enableFeedback: true,
        ),
        onPressed: onPressed,
        child: Text(text)
    );
  }
}
