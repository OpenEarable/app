import 'dart:math';

import 'package:flutter/material.dart';

class ArcPainter extends CustomPainter {
  final double angle; // the angle of rotation

  ArcPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    Paint circlePaint = Paint()
      ..color = const Color.fromARGB(255, 195, 195, 195)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;

    Path circlePath = Path();
    circlePath.addOval(Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: min(size.width, size.height) / 2));
    canvas.drawPath(circlePath, circlePaint);

    // Create a paint object with purple color and stroke style
    Paint paint = Paint()
      ..color = Colors.purple
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    // Create a path object to draw the arc
    Path path = Path();

    // Calculate the center and radius of the circle
    Offset center = Offset(size.width / 2, size.height / 2);
    double radius = min(size.width, size.height) / 2;

    // Calculate the start and end angles of the arc
    double startAngle = -pi / 2; // start from the top of the circle
    double endAngle = angle; // end at the bottom of the circle

    // Add an arc to the path
    path.addArc(
      Rect.fromCircle(center: center, radius: radius), // create a rectangle from the center and radius
      startAngle, // start angle
      endAngle, // sweep angle
    );

    // Draw the path on the canvas
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // return true to update the painting when the angle changes
  }
}