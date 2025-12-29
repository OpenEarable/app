import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  static const String themeKey = 'theme_mode';

  ThemeSettings() {
    _loadThemeFromPrefs();
  }

  void setTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    _saveThemeToPrefs();
  }

  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString(themeKey);

    if (themeString == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (themeString == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeString == 'system') {
      _themeMode = ThemeMode.system;
    } // else default to light
    notifyListeners();
  }

  Future<void> _saveThemeToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    String themeString;
    if (_themeMode == ThemeMode.dark) {
      themeString = 'dark';
    } else if (_themeMode == ThemeMode.light) {
      themeString = 'light';
    } else {
      themeString = 'system';
    }
    await prefs.setString(themeKey, themeString);
  }
}