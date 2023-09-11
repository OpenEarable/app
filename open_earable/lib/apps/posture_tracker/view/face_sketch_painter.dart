import 'package:flutter/material.dart';

class FaceSketchPainter extends CustomPainter {
  static const double _strokeWidth = 15;

  static const double _eyeHeight = 25;
  static const double _defaultEyePosY = 1 / 3;
  static const double _defaultEyePosX = 1 / 3.5;

  static const double _defaultMouthPosY = 1 / 1.3;
  static const double _defaultMouthPosX = 1 / 2;
  static const double _defaultMouthWidth = 1 / 3;

  @override
  void paint(Canvas canvas, Size size) {
    // draw a circle filling the canvas
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width /2, paint);

    // draw the eyes as a down stroke
    final Offset leftEyePosition = Offset(size.width * _defaultEyePosX, size.height * _defaultEyePosY);
    final Offset rightEyePosition = Offset(size.width - (size.width * _defaultEyePosX), size.height * _defaultEyePosY);
    final eyePath = Path();
    eyePath.moveTo(leftEyePosition.dx, leftEyePosition.dy);
    eyePath.lineTo(leftEyePosition.dx, leftEyePosition.dy + _eyeHeight);
    eyePath.moveTo(rightEyePosition.dx, rightEyePosition.dy);
    eyePath.lineTo(rightEyePosition.dx, rightEyePosition.dy + _eyeHeight);
    canvas.drawPath(eyePath, paint);

    // draw a curve for the mouth
    final mouthPath = Path();
    mouthPath.moveTo(size.width * _defaultMouthWidth, size.height * _defaultMouthPosY);
    mouthPath.quadraticBezierTo(size.width * _defaultMouthPosX, size.height / 1.1, size.width / 1.5, size.height * _defaultMouthPosY);
    canvas.drawPath(mouthPath, paint);

    // draw a J for the nose
    final nosePath = Path();
    nosePath.moveTo(size.width / 2, size.height / 2.5);
    nosePath.lineTo(size.width / 2, size.height / 2);
    nosePath.lineTo(size.width / 2.5, size.height / 2);
    canvas.drawPath(nosePath, paint);



    // draw a grid for reference
    final gridPaint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 10; i++) {
      canvas.drawLine(Offset(0, size.height / 10 * i), Offset(size.width, size.height / 10 * i), gridPaint);
      canvas.drawLine(Offset(size.width / 10 * i, 0), Offset(size.width / 10 * i, size.height), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}