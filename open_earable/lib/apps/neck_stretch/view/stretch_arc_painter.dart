import 'dart:math';

import 'package:flutter/material.dart';
import 'package:open_earable/apps/neck_stretch/model/stretch_state.dart';
import 'package:open_earable/apps/posture_tracker/view/arc_painter.dart';
import 'package:open_earable/apps/neck_stretch/model/stretch_colors.dart';


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
      ..color = outerRing
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;

    Path circlePath = Path();
    circlePath.addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: min(size.width, size.height) / 2));
    canvas.drawPath(circlePath, circlePaint);

    // Create a paint object with the right color for the stretch indicator
    Paint anglePaint = Paint()
      ..color = _getIndicatorColor()
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

    /// Draw the overshooting path
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
          !_isWrongStretchDirection() ? angle.sign * (angle.abs() - angleThreshold) : 0, // sweep angle
    );
    }

    Paint angleOvershootPaint = Paint()
    ..color = _getOvershootColor()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 5.0;

    Path thresholdPath = Path();
    thresholdPath.addArc(
    Rect.fromCircle(center: center, radius: radius),
    // create a rectangle from the center and radius
    _getStartAngle(startAngle, angleThreshold), // start angle
    _getThreshold(angleThreshold), // sweep angle
    );

    Paint thresholdPaint = Paint()
    ..color = _getThresholdColor()
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
  double _getStartAngle(double startAngle, double threshold) {
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
  double _getThreshold(double threshold) {
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
  bool _isWrongStretchDirection() {
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
  Color _getOvershootColor() {
    if (_isNegativeOvershoot()) {
      // Equals Colors.redAccent[100]!
      return badStretchColor;
    }

    return goodStretchColor;
  }

  /// Returns the right color for the threshold depending on stretch state and
  /// if its the upper or lower head state arc.
  Color _getThresholdColor() {
    if (_isNegativeOvershoot()) {
      return goodStretchIndicatorColor;
    }

    return wrongAreaIndicator;
  }

  /// Gets the right indicator color depending on stretch angle and part
  Color _getIndicatorColor() {
    if(_isNegativeOvershoot())
        return goodStretchColor;


    if(_isWrongStretchDirection())
      return badStretchIndicatorColor;


    return goodStretchIndicatorColor;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // check if oldDelegate is an ArcPainter and if the angle is the same
    return oldDelegate is ArcPainter && oldDelegate.angle != this.angle;
  }
}
