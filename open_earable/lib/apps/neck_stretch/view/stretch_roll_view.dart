import 'dart:math';

import 'package:flutter/material.dart';
import 'package:open_earable/apps/neck_stretch/model/stretch_state.dart';
import 'package:open_earable/apps/neck_stretch/view/stretch_arc_painter.dart';

/// A widget that displays the roll of the head and neck for the meditation.
class StretchRollView extends StatelessWidget {
  static final double _MAX_ROLL = pi / 2;

  /// The roll of the head and neck in radians.
  final double roll;
  final double angleThreshold;

  final String headAssetPath;
  final String neckAssetPath;
  final AlignmentGeometry headAlignment;

  // Checks whether the arc has different properties due to meditation state
  final NeckStretchState stretchState;

  const StretchRollView(
      {Key? key,
      required this.roll,
      this.angleThreshold = 0,
      required this.headAssetPath,
      required this.neckAssetPath,
      this.headAlignment = Alignment.center,
      this.stretchState = NeckStretchState.noStretch})
      : super(key: key);

  /// Returns true if this is a StretchRollView for a front facing head. False otherwise.
  bool _isFront() {
    return headAssetPath.contains("Front.png");
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text("${(this.roll * 180 / 3.14).abs().toStringAsFixed(0)}°",
          style: TextStyle(
              // use proper color matching the background
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 30,
              fontWeight: FontWeight.bold)),
      CustomPaint(
          painter:
              StretchArcPainter(angle: this.roll, angleThreshold: this.angleThreshold, stretchState: this.stretchState, isFront: _isFront()),
          child: Padding(
              padding: EdgeInsets.all(10),
              child: ClipOval(
                  child: Container(
                      color: roll.abs() > _MAX_ROLL
                          ? Colors.red.withOpacity(0.5)
                          : Colors.transparent,
                      child: Stack(children: [
                        Image.asset(this.neckAssetPath),
                        Transform.rotate(
                            angle: this.roll.isFinite
                                ? roll.abs() < _MAX_ROLL
                                    ? this.roll
                                    : roll.sign * _MAX_ROLL
                                : 0,
                            alignment: this.headAlignment,
                            child: Image.asset(this.headAssetPath)),
                      ]))))),
    ]);
  }
}
