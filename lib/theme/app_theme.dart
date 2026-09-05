import 'package:flutter/material.dart';

import 'la_bomba_design_system.dart';

class AppTheme {
  static const Color obsidian = LaBombaColors.obsidian;
  static const Color background = LaBombaColors.background;
  static const Color cloud = LaBombaColors.cloud;
  static const Color slate = LaBombaColors.slate;
  static const Color primary = LaBombaColors.primary;
  static const Color primaryLight = LaBombaColors.violetBright;
  static const Color blue = LaBombaColors.digitalBlue;
  static const Color cyan = LaBombaColors.cyan;
  static const Color accent = LaBombaColors.orange;
  static const Color pink = LaBombaColors.pink;

  static ThemeData get darkTheme {
    final base = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      secondary: blue,
      surface: LaBombaColors.surface,
      surfaceContainerHighest: LaBombaColors.surfaceElevated,
      onPrimary: Colors.white,
      onSurface: cloud,
      outline: LaBombaColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: base,
      scaffoldBackgroundColor: obsidian,
      textTheme: ThemeData.dark().textTheme.apply(
            bodyColor: LaBombaColors.textPrimary,
            displayColor: LaBombaColors.textPrimary,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: LaBombaColors.textPrimary,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: LaBombaColors.card,
        elevation: 0,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaBombaRadius.xLarge),
          side: const BorderSide(color: LaBombaColors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: LaBombaColors.surfaceElevated,
        contentTextStyle: const TextStyle(color: LaBombaColors.textPrimary),
        actionTextColor: LaBombaColors.violetBright,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaBombaRadius.medium),
          side: const BorderSide(color: LaBombaColors.border),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(
        color: LaBombaColors.border,
        thickness: 1,
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      secondary: blue,
      surface: Colors.white,
      surfaceContainerHighest: const Color(0xFFE8EDF3),
      onPrimary: Colors.white,
      onSurface: const Color(0xFF0F172A),
      outline: const Color(0xFFD9E2EC),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: base,
      scaffoldBackgroundColor: LaBombaColors.cloud,
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: const Color(0xFF0F172A),
            displayColor: const Color(0xFF0F172A),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shadowColor: const Color(0x14081218),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaBombaRadius.xLarge),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        contentTextStyle: const TextStyle(color: Color(0xFF0F172A)),
        actionTextColor: primary,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaBombaRadius.medium),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
    );
  }
}
