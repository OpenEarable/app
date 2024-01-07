import 'package:flutter/material.dart';

class Pixel extends StatelessWidget {
  final color;
  final child;

  Pixel({this.color, this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(1.0),
      child: Container(
        color: color,
        child: Center(child: child,),
      ),
    );
  }
}
