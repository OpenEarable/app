import 'dart:math';

import 'package:flutter/material.dart';
import 'package:open_earable/apps/neck_stretch/model/stretch_state.dart';
import 'package:open_earable/apps/posture_tracker/view/arc_painter.dart';

class StretchArcPainter extends CustomPainter {
  /// the angle of rotation
  final double angle;
  final double angleThreshold;
  final NeckStretchState stretchState;
  final bool isFront;

  StretchArcPainter({required this.angle,
    this.angleThreshold = 0,
    this.stretchState = NeckStretchState.noStretch,
    required this.isFront});

  @override
  void paint(Canvas canvas, Size size) {
    Paint circlePaint = Paint()
      ..color = const Color.fromARGB(255, 195, 195, 195)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;

    Path circlePath = Path();
    circlePath.addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: min(size.width, size.height) / 2));
    canvas.drawPath(circlePath, circlePaint);

    // Create a paint object with purple color and stroke style
    Paint anglePaint = Paint()
      ..color = _isCorrectStretchDirection() ? Colors.redAccent[100]! : Colors.greenAccent[100]!
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
      Rect.fromCircle(center: center, radius: radius),
      // create a rectangle from the center and radius
      startAngle, // start angle
      endAngle, // sweep angle
    );

    Path angleOvershootPath = Path();

    if (_isNegativeOvershoot()) {
      angleOvershootPath.addArc(
        Rect.fromCircle(center: center, radius: radius),
        // create a rectangle from the center and radius
        startAngle + angle.sign * angleThreshold, // start angle
        angle.sign * (angle.abs() - angleThreshold), // sweep angle
      );
    } else {
      angleOvershootPath.addArc(
          Rect.fromCircle(center: center, radius: radius),
          // create a rectangle from the center and radius
          startAngle + angle.sign * angleThreshold, // start angle
          !_isCorrectStretchDirection() ? angle.sign * (angle.abs() - angleThreshold) : 0, // sweep angle
    );
    }

    Paint angleOvershootPaint = Paint()
    ..color = getOvershootColor()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 5.0;

    Path thresholdPath = Path();
    thresholdPath.addArc(
    Rect.fromCircle(center: center, radius: radius),
    // create a rectangle from the center and radius
    getStartAngle(startAngle, angleThreshold), // start angle
    getThreshold(angleThreshold), // sweep angle
    );

    Paint thresholdPaint = Paint()
    ..color = getThresholdColor()
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

  /// Gets the right start angle depending on stretch state
  double getStartAngle(double startAngle, double threshold) {
    if (!this.isFront) return startAngle - threshold;

    switch (this.stretchState) {
      case NeckStretchState.rightNeckStretch:
        return startAngle - threshold;
      case NeckStretchState.leftNeckStretch:
        return startAngle - threshold - pi / 2 - 2 / 18 * pi;
      default:
        return startAngle - threshold;
    }
  }

  /// Gets the right threshold depending on stretch state
  double getThreshold(double threshold) {
    if (this.isFront) {
      switch (this.stretchState) {
        case NeckStretchState.rightNeckStretch:
        case NeckStretchState.leftNeckStretch:
          return 2 * threshold + pi / 2 + 2 / 18 * pi;
        default:
          return 2 * threshold;
      }
    }

    switch (this.stretchState) {
      case NeckStretchState.mainNeckStretch:
        return 2 * threshold + pi / 2 + 1 / 36 * pi;
      default:
        return 2 * threshold;
    }
  }

  /// Determines whether the user is currently stretching in the right direction
  bool _isCorrectStretchDirection() {
    if (this.isFront) {
      switch (this.stretchState) {
        case NeckStretchState.rightNeckStretch:
          return angle.sign >= 0;
        case NeckStretchState.leftNeckStretch:
          return angle.sign <= 0;
        default:
          return false;
      }
    }

    switch (this.stretchState) {
      case NeckStretchState.mainNeckStretch:
        return angle.sign >= 0;
      default:
        return false;
    }
  }

  /// Detgermines whether the overshoot is negative (shouldnt stretch that part)
  /// or is positive (should stretch that part)
  bool _isNegativeOvershoot() {
    return (this.isFront &&
        this.stretchState == NeckStretchState.mainNeckStretch) ||
        (!this.isFront &&
            (this.stretchState == NeckStretchState.leftNeckStretch ||
                this.stretchState == NeckStretchState.rightNeckStretch));
  }

  /// Returns the right color for the overshoot depending on stretch state and
  /// if its upper or lower head state arc.
  Color getOvershootColor() {
    if (_isNegativeOvershoot()) {
      // Equals Colors.redAccent[100]!
      return Color.fromARGB(255, 255, 138, 128);
    }

    return Color(0xff77F2A1);
  }

  /// Returns the right color for the threshold depending on stretch state and
  /// if its the upper or lower head state arc.
  Color getThresholdColor() {
    if (_isNegativeOvershoot()) {
      return Color(0xff77F2A1);
    }

    // Equals Colors.redAccent[100]!
    return Color.fromARGB(255, 124, 124, 124);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // check if oldDelegate is an ArcPainter and if the angle is the same
    return oldDelegate is ArcPainter && oldDelegate.angle != this.angle;
  }
}
