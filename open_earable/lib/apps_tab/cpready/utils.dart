
import 'dart:math';

import 'package:flutter/cupertino.dart';

/// Function that converts frequencies from Hz to bpm
double toBPM(double currentFrequency) {
  return currentFrequency * 60;
}

/// Function for retrieving a text scale factor.
/// It uses the [context] for a responsive text size.
double textScaleFactor(BuildContext context, {double maxTextScaleFactor = 2}) {
  final width = MediaQuery.of(context).size.width;
  double val = (width / 1400) * maxTextScaleFactor;
  return max(1, min(val, maxTextScaleFactor));
}
