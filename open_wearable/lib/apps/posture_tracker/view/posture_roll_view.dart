import 'dart:math';

import 'package:flutter/material.dart';
import 'package:open_wearable/apps/posture_tracker/view/arc_painter.dart';

/// A widget that displays the roll of the head and neck.
class PostureRollView extends StatelessWidget {
  static const double _maxRoll = pi / 2;

  /// The roll of the head and neck in radians.
  final double roll;
  final double angleThreshold;

  final String headAssetPath;
  final String neckAssetPath;
  final AlignmentGeometry headAlignment;
  final double visualSize;
  final Color? goodColor;
  final Color? badColor;

  const PostureRollView({
    super.key,
    required this.roll,
    this.angleThreshold = 0,
    required this.headAssetPath,
    required this.neckAssetPath,
    this.headAlignment = Alignment.center,
    this.visualSize = 118,
    this.goodColor,
    this.badColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final boundedRoll =
        roll.isFinite ? roll.clamp(-_maxRoll, _maxRoll).toDouble() : 0.0;
    final hasOvershoot = roll.abs() > angleThreshold.abs();
    final healthyColor = goodColor ?? const Color(0xFF2F8F5B);
    final unhealthyColor = badColor ?? colorScheme.error;
    final displayColor = hasOvershoot ? unhealthyColor : healthyColor;

    return Column(
      children: [
        Text(
          '${(roll * 180 / pi).abs().toStringAsFixed(0)}°',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: displayColor,
              ),
        ),
        const SizedBox(height: 2),
        CustomPaint(
          painter: ArcPainter(
            angle: roll,
            angleThreshold: angleThreshold,
            circleColor: colorScheme.outlineVariant.withValues(alpha: 0.65),
            angleColor: displayColor,
            thresholdColor: displayColor.withValues(alpha: 0.35),
            overshootColor: unhealthyColor,
          ),
          child: SizedBox.square(
            dimension: visualSize,
            child: ClipOval(
              child: Container(
                color: hasOvershoot
                    ? unhealthyColor.withValues(alpha: 0.18)
                    : healthyColor.withValues(alpha: 0.12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      neckAssetPath,
                      fit: BoxFit.contain,
                    ),
                    Transform.rotate(
                      angle: boundedRoll,
                      alignment: headAlignment,
                      child: Image.asset(
                        headAssetPath,
                        fit: BoxFit.contain,
                      ),
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
