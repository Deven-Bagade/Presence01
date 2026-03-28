import 'package:flutter/material.dart';



enum AppTheme {
  classicBlue,
  indigoMinimal,
  tealFocus,
  darkMode,
}

class AppThemeData {
  final String name;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color card;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;

  // Status colors (consistent across all themes)
  static const Color presentColor = Color(0xFF34C759); // Green
  static const Color absentColor = Color(0xFFFF3B30); // Red
  static const Color lateColor = Color(0xFFFF9500); // Amber

  const AppThemeData({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.card,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
  });

  // Classic Blue - professional, trusted look (Default)
  static const classicBlue = AppThemeData(
    name: 'Classic Blue',
    primary: Color(0xFF2D5B7C),
    secondary: Color(0xFF4A8DB7),
    accent: Color(0xFF6BC4A6),
    card: Colors.white,
    background: Color(0xFFF5F7FA),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF636366),
    isDark: false,
  );

  // Indigo Minimal - modern, student-friendly
  static const indigoMinimal = AppThemeData(
    name: 'Indigo Minimal',
    primary: Color(0xFF3949AB),
    secondary: Color(0xFF5C6BC0),
    accent: Color(0xFF7986CB),
    card: Colors.white,
    background: Color(0xFFF3F5F9),
    textPrimary: Color(0xFF212121),
    textSecondary: Color(0xFF757575),
    isDark: false,
  );

  // Teal Focus - eye-comfort, academic style
  static const tealFocus = AppThemeData(
    name: 'Teal Focus',
    primary: Color(0xFF00796B),
    secondary: Color(0xFF009688),
    accent: Color(0xFF4DB6AC),
    card: Colors.white,
    background: Color(0xFFE0F2F1),
    textPrimary: Color(0xFF004D40),
    textSecondary: Color(0xFF00796B),
    isDark: false,
  );

  // Dark Mode - night usage & battery friendly
  static const darkMode = AppThemeData(
    name: 'Dark Mode',
    primary: Color(0xFFBB86FC),
    secondary: Color(0xFF03DAC6),
    accent: Color(0xFF03DAC5),
    card: Color(0xFF1E1E1E),
    background: Color(0xFF121212),
    textPrimary: Color(0xFFE0E0E0),
    textSecondary: Color(0xFFB0B0B0),
    isDark: true,
  );

  // Map to get theme by enum
  static AppThemeData getTheme(AppTheme theme) {
    switch (theme) {
      case AppTheme.indigoMinimal:
        return indigoMinimal;
      case AppTheme.tealFocus:
        return tealFocus;
      case AppTheme.darkMode:
        return darkMode;
      case AppTheme.classicBlue:
      default:
        return classicBlue;
    }
  }

  // Convert to Flutter's ThemeData
  ThemeData toThemeData() {
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primary,
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: secondary,
        onSecondary: isDark ? Colors.black : Colors.white,
        error: absentColor,
        onError: Colors.white,
        background: background,
        onBackground: textPrimary,
        surface: card,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: background,
      cardColor: card,
      cardTheme: CardThemeData(
        color: card,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),


      appBarTheme: AppBarTheme(
        backgroundColor: card,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: textSecondary,
        ),
      ),
    );
  }
}

// Theme provider class for state management
class ThemeProvider extends ChangeNotifier {
  AppTheme _currentTheme = AppTheme.classicBlue;

  AppTheme get currentTheme => _currentTheme;
  AppThemeData get themeData => AppThemeData.getTheme(_currentTheme);

  void setTheme(AppTheme theme) {
    _currentTheme = theme;
    notifyListeners();
  }

  void cycleTheme() {
    final themes = AppTheme.values;
    final currentIndex = themes.indexOf(_currentTheme);
    final nextIndex = (currentIndex + 1) % themes.length;
    setTheme(themes[nextIndex]);
  }
}