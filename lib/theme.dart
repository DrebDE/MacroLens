import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF1E2B21);
  static const green = Color(0xFF2E7D32);
  static const deepGreen = Color(0xFF173D28);
  static const lime = Color(0xFFE8F5E9);
  static const paleGreen = Color(0xFFEFF6EC);
  static const canvas = Color(0xFFF7FAF6);
  static const white = Colors.white;
  static const muted = Color(0xFF68766A);
  static const border = Color(0xFFDDE7DB);
  static const danger = Color(0xFFB3261E);
  static const amber = Color(0xFF8A5A00);
}

const appCardRadius = 20.0;

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.green).copyWith(
    primary: AppColors.green,
    onPrimary: Colors.white,
    primaryContainer: AppColors.lime,
    onPrimaryContainer: AppColors.deepGreen,
    surface: AppColors.canvas,
    onSurface: AppColors.ink,
    outline: AppColors.border,
    error: AppColors.danger,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    canvasColor: AppColors.canvas,
    fontFamily: 'Roboto',
    visualDensity: VisualDensity.standard,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        color: AppColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.green, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Roboto',
        color: AppColors.muted,
        fontSize: 13,
      ),
      floatingLabelStyle: const TextStyle(
        fontFamily: 'Roboto',
        color: AppColors.green,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Roboto',
        color: AppColors.muted,
        fontSize: 13,
      ),
      errorStyle: const TextStyle(
        fontFamily: 'Roboto',
        color: AppColors.danger,
        fontSize: 11,
      ),
      prefixIconColor: AppColors.muted,
      suffixIconColor: AppColors.muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.muted,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.green,
        minimumSize: const Size(0, 46),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.green,
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.lime,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: 'Roboto',
          color: selected ? AppColors.deepGreen : AppColors.muted,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.green : AppColors.muted,
          size: 24,
        );
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.deepGreen,
      contentTextStyle: const TextStyle(
        fontFamily: 'Roboto',
        color: Colors.white,
        fontSize: 13,
      ),
      actionTextColor: AppColors.lime,
      insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) return AppColors.green;
        return Colors.white;
      }),
      side: const BorderSide(color: AppColors.muted, width: 1.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.green,
      linearTrackColor: AppColors.border,
      circularTrackColor: AppColors.lime,
    ),
  );
}
