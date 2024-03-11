// ignore_for_file: unnecessary_this

import 'dart:math';

import 'package:flutter/material.dart';

class ArcPainter extends CustomPainter {
  /// the angle of rotation
  final double angle;
  final double angleThreshold;

  ArcPainter({required this.angle, this.angleThreshold = 0});

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
    Paint anglePaint = Paint()
      ..color = Colors.purpleAccent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    // Create a path object to draw the arc
    Path anglePath = Path();

    // Calculate the center and radius of the circle
    Offset center = Offset(size.width / 2, size.height / 2);
    double radius = min(size.width, size.height) / 2;

    // Calculate the start and end angles of the arc
    double startAngle = -pi / 2; // start from the top of the circle
    double endAngle = angle;

    // Add an arc to the path
    anglePath.addArc(
      Rect.fromCircle(center: center, radius: radius), // create a rectangle from the center and radius
      startAngle, // start angle
      endAngle, // sweep angle
    );

    Path angleOvershootPath = Path();
    angleOvershootPath.addArc(
      Rect.fromCircle(center: center, radius: radius), // create a rectangle from the center and radius
      startAngle + angle.sign * angleThreshold, // start angle
      angle.sign * (angle.abs() - angleThreshold), // sweep angle
    );

    Paint angleOvershootPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    Path thresholdPath = Path();
    thresholdPath.addArc(
      Rect.fromCircle(center: center, radius: radius), // create a rectangle from the center and radius
      startAngle - angleThreshold, // start angle
      2 * angleThreshold, // sweep angle
    );

    Paint thresholdPaint = Paint()
      ..color = Colors.purpleAccent[100]!
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;


    // Draw the path on the canvas
    canvas.drawPath(thresholdPath, thresholdPaint);
    canvas.drawPath(anglePath, anglePaint);
    if (angle.abs() > angleThreshold.abs()) {
      canvas.drawPath(angleOvershootPath, angleOvershootPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // check if oldDelegate is an ArcPainter and if the angle is the same
    return oldDelegate is ArcPainter && oldDelegate.angle != this.angle;
  }
}