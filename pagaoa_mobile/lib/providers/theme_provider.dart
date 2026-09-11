import 'package:flutter/material.dart';

class AppColors {
  static const Color maroon = Color(0xFF7A1F2B); // primary
  static const Color maroonDark = Color(0xFF4E1119); // primary, dark mode
  static const Color maroonLight = Color(0xFFF6E4E7); // container / tint
  static const Color gold = Color(0xFFE0A937); // accent (price, CTA)
  static const Color surfaceLight = Color(0xFFFFFBFA);
  static const Color surfaceDark = Color(0xFF1C1214);
}

class ThemeProvider extends ChangeNotifier {
  bool isDark = false;

  void toggleTheme() {
    isDark = !isDark;
    notifyListeners();
  }

  ThemeData get lightTheme => _buildTheme(
    brightness: Brightness.light,
    primary: AppColors.maroon,
    primaryContainer: AppColors.maroonLight,
    surface: AppColors.surfaceLight,
  );

  ThemeData get darkTheme => _buildTheme(
    brightness: Brightness.dark,
    primary: AppColors.maroonDark,
    primaryContainer: const Color(0xFF3A0D13),
    surface: AppColors.surfaceDark,
  );

  ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color primaryContainer,
    required Color surface,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.maroon,
      brightness: brightness,
      primary: primary,
      primaryContainer: primaryContainer,
      secondary: AppColors.gold,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        shadowColor: primary.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black87,
        elevation: 3,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF2A1B1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
