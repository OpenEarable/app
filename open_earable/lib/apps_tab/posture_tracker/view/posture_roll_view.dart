// ignore_for_file: unnecessary_this

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:open_earable/apps_tab/posture_tracker/view/arc_painter.dart';

/// A widget that displays the roll of the head and neck.
class PostureRollView extends StatelessWidget {
  static final double _maxRoll = pi / 2;

  /// The roll of the head and neck in radians.
  final double roll;
  final double angleThreshold;

  final String headAssetPath;
  final String neckAssetPath;
  final AlignmentGeometry headAlignment;

  const PostureRollView({
    super.key,
    required this.roll,
    this.angleThreshold = 0,
    required this.headAssetPath,
    required this.neckAssetPath,
    this.headAlignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          "${(this.roll * 180 / 3.14).abs().toStringAsFixed(0)}°",
          style: TextStyle(
            // use proper color matching the background
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        CustomPaint(
          painter:
              ArcPainter(angle: this.roll, angleThreshold: this.angleThreshold),
          child: Padding(
            padding: EdgeInsets.all(10),
            child: ClipOval(
              child: Container(
                color: roll.abs() > _maxRoll
                    ? Colors.red.withOpacity(0.5)
                    : Colors.transparent,
                child: Stack(
                  children: [
                    Image.asset(this.neckAssetPath),
                    Transform.rotate(
                      angle: this.roll.isFinite
                          ? roll.abs() < _maxRoll
                              ? this.roll
                              : roll.sign * _maxRoll
                          : 0,
                      alignment: this.headAlignment,
                      child: Image.asset(this.headAssetPath),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
