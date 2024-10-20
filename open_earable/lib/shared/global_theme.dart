import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

final ThemeData materialTheme = ThemeData(
  useMaterial3: false,
  colorScheme: ColorScheme(
    brightness: Brightness.dark,
    primary: Color.fromARGB(255, 54, 53, 59),
    onPrimary: Colors.white,
    secondary: Color.fromARGB(255, 119, 242, 161),
    onSecondary: Colors.white,
    error: Colors.red,
    onError: Colors.black,
    surface: Color.fromARGB(255, 22, 22, 24),
    onSurface: Colors.white,
  ),
  secondaryHeaderColor: Colors.black,
);

final CupertinoThemeData cupertinoTheme = CupertinoThemeData(
  brightness: Brightness.dark,
  primaryColor: Color.fromARGB(255, 119, 242, 161),
  primaryContrastingColor: Color.fromARGB(255, 54, 53, 59),
  barBackgroundColor: Color.fromARGB(255, 22, 22, 24),
  scaffoldBackgroundColor: Color.fromARGB(255, 22, 22, 24),
  textTheme: CupertinoTextThemeData(
    primaryColor: Colors.white,
  ),
);
