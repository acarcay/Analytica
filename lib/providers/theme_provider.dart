// lib/providers/theme_provider.dart

import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  // Default to dark mode to match requested dark UI
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners(); // Değişikliği dinleyen widget'lara haber ver
  }
}