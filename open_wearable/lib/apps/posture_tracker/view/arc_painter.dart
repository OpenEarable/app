import 'dart:math';

import 'package:flutter/material.dart';

class ArcPainter extends CustomPainter {
  final double angle;
  final double angleThreshold;
  final Color circleColor;
  final Color angleColor;
  final Color thresholdColor;
  final Color overshootColor;
  final double strokeWidth;

  ArcPainter({
    required this.angle,
    this.angleThreshold = 0,
    this.circleColor = const Color(0xFFC3C3C3),
    this.angleColor = Colors.blue,
    this.thresholdColor = const Color(0x664285F4),
    this.overshootColor = Colors.red,
    this.strokeWidth = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final safeAngle = angle.isFinite ? angle : 0.0;
    final safeThreshold = angleThreshold.abs();
    const startAngle = -pi / 2;

    final circlePaint = Paint()
      ..color = circleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, circlePaint);

    final anglePaint = Paint()
      ..color = angleColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final thresholdPaint = Paint()
      ..color = thresholdColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final angleOvershootPaint = Paint()
      ..color = overshootColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final arcBounds = Rect.fromCircle(center: center, radius: radius);
    if (safeThreshold > 0) {
      canvas.drawArc(
        arcBounds,
        startAngle - safeThreshold,
        2 * safeThreshold,
        false,
        thresholdPaint,
      );
    }

    canvas.drawArc(
      arcBounds,
      startAngle,
      safeAngle,
      false,
      anglePaint,
    );

    if (safeThreshold > 0 && safeAngle.abs() > safeThreshold) {
      canvas.drawArc(
        arcBounds,
        startAngle + safeAngle.sign * safeThreshold,
        safeAngle.sign * (safeAngle.abs() - safeThreshold),
        false,
        angleOvershootPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is ArcPainter &&
        (oldDelegate.angle != angle ||
            oldDelegate.angleThreshold != angleThreshold ||
            oldDelegate.circleColor != circleColor ||
            oldDelegate.angleColor != angleColor ||
            oldDelegate.thresholdColor != thresholdColor ||
            oldDelegate.overshootColor != overshootColor ||
            oldDelegate.strokeWidth != strokeWidth);
  }
}
