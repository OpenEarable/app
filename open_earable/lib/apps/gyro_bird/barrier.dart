import 'package:flutter/material.dart';

class Barrier extends StatelessWidget {
  final size;

  Barrier({this.size}) {}

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.23 * MediaQuery.of(context).size.width,
      height: size,
      decoration: BoxDecoration(
        color: Colors.green,
        border: Border(
          top: BorderSide(width: 10.0, color: Colors.green.shade800),
          left: BorderSide(width: 5.0, color: Colors.green.shade800),
          right: BorderSide(width: 5.0, color: Colors.green.shade800),
        ),
       // borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
