import 'package:flutter/material.dart';

abstract class DrawerPage implements Widget {
  String get label;
  IconData get icon;
  IconData get selectedIcon;
}
