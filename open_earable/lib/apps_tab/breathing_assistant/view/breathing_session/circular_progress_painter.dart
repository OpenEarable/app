import 'package:flutter/material.dart';

/// A custom painter for rendering a circular progress indicator
/// with a central text displaying the current phase of the breathing session.
///
/// This painter is used to visualize the progress of breathing phases
/// such as "Inhale," "Hold," and "Exhale."
class CircularProgressPainter extends CustomPainter {
  /// The progress value, ranging from 0.0 to 1.0.
  final double progress;

  /// The current phase of the breathing session (e.g., "Inhale").
  final String phase;

  /// Creates a [CircularProgressPainter] with the given [progress] and [phase].
  CircularProgressPainter(this.progress, this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    // Paint for the circular background (semi-transparent).
    Paint backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0;

    Paint progressPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0;

    // Calculate the radius and center of the circular progress indicator.
    double radius = size.width / 2;
    Offset center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw the progress arc based on the [progress] value.
    double sweepAngle = 2 * 3.14159265359 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159265359 / 2, 
      sweepAngle,
      false,
      progressPaint,
    );

    // Draw the current phase text in the center of the circle.
    TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: phase,
        style: const TextStyle(
          fontSize: 24,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  /// Ensures that the canvas is repainted whenever [progress] or [phase] changes.
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
