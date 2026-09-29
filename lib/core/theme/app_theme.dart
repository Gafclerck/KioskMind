import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get lightTheme => _lightTheme;

  static ThemeData get darkTheme => _darkTheme;

  static final ThemeData _lightTheme = _build(brightness: Brightness.light);

  static final ThemeData _darkTheme = _build(brightness: Brightness.dark);

  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.lightSurface,
    primaryContainer: Color(0xFFD6EAE6),
    onPrimaryContainer: Color(0xFF0B3A34),
    secondary: AppColors.secondary,
    onSecondary: AppColors.textPrimaryLight,
    secondaryContainer: Color(0xFFFCEBD5),
    onSecondaryContainer: Color(0xFF7A4708),
    tertiary: AppColors.secondary,
    onTertiary: AppColors.textPrimaryLight,
    error: AppColors.error,
    onError: AppColors.lightSurface,
    errorContainer: Color(0xFFFBE4E0),
    onErrorContainer: Color(0xFF8A2A18),
    surfaceDim: Color(0xFFE6E4DE),
    surface: AppColors.lightBackground,
    surfaceBright: AppColors.lightSurface,
    surfaceContainerLowest: AppColors.lightSurface,
    surfaceContainerLow: Color(0xFFF4F2EC),
    surfaceContainer: Color(0xFFEFEDE6),
    surfaceContainerHigh: Color(0xFFE9E7E0),
    surfaceContainerHighest: Color(0xFFE3E1DA),
    onSurface: AppColors.textPrimaryLight,
    onSurfaceVariant: AppColors.textSecondaryLight,
    outline: Color(0xFF8C999C),
    outlineVariant: Color(0xFFDAD8D0),
    inverseSurface: AppColors.textPrimaryLight,
    onInverseSurface: AppColors.textPrimaryDark,
    inversePrimary: AppColors.primaryDark,
    surfaceTint: Colors.transparent,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primaryDark,
    onPrimary: AppColors.darkBackground,
    primaryContainer: Color(0xFF0E4A43),
    onPrimaryContainer: Color(0xFFA9E5DA),
    secondary: AppColors.secondary,
    onSecondary: AppColors.darkBackground,
    secondaryContainer: Color(0xFF5A3A12),
    onSecondaryContainer: Color(0xFFF7C089),
    tertiary: AppColors.secondary,
    onTertiary: AppColors.darkBackground,
    error: AppColors.errorDark,
    onError: AppColors.darkBackground,
    errorContainer: Color(0xFF4A1510),
    onErrorContainer: Color(0xFFF7A99B),
    surfaceDim: Color(0xFF0C1113),
    surface: AppColors.darkBackground,
    surfaceBright: AppColors.darkSurface,
    surfaceContainerLowest: Color(0xFF0A0E10),
    surfaceContainerLow: Color(0xFF161D1F),
    surfaceContainer: AppColors.darkSurface,
    surfaceContainerHigh: Color(0xFF262F31),
    surfaceContainerHighest: Color(0xFF2F393B),
    onSurface: AppColors.textPrimaryDark,
    onSurfaceVariant: AppColors.textSecondaryDark,
    outline: Color(0xFF6E7A7D),
    outlineVariant: Color(0xFF333D40),
    inverseSurface: AppColors.textPrimaryDark,
    onInverseSurface: AppColors.darkBackground,
    inversePrimary: AppColors.primary,
    surfaceTint: Colors.transparent,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static ThemeData _build({required Brightness brightness}) {
    final ColorScheme colorScheme = switch (brightness) {
      Brightness.light => _lightColorScheme,
      Brightness.dark => _darkColorScheme,
    };

    final TextTheme textTheme = switch (brightness) {
      Brightness.light => AppTypography.light,
      Brightness.dark => AppTypography.dark,
    };

    final Color background = switch (brightness) {
      Brightness.light => AppColors.lightBackground,
      Brightness.dark => AppColors.darkBackground,
    };

    final Color surface = switch (brightness) {
      Brightness.light => AppColors.lightSurface,
      Brightness.dark => AppColors.darkSurface,
    };

    final SystemUiOverlayStyle overlayStyle = switch (brightness) {
      Brightness.light => SystemUiOverlayStyle.dark,
      Brightness.dark => SystemUiOverlayStyle.light,
    };

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: background,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
        actionsIconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
        systemOverlayStyle: overlayStyle,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: _inputBorder(colorScheme.outline),
        enabledBorder: _inputBorder(colorScheme.outline),
        focusedBorder: _inputBorder(colorScheme.primary, width: 2),
        errorBorder: _inputBorder(colorScheme.error),
        focusedErrorBorder: _inputBorder(colorScheme.error, width: 2),
        disabledBorder: _inputBorder(colorScheme.outlineVariant),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.primary,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: colorScheme.error),
        iconColor: colorScheme.onSurfaceVariant,
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        selectedIconTheme: IconThemeData(color: colorScheme.primary, size: 24),
        unselectedIconTheme: IconThemeData(
          color: colorScheme.onSurfaceVariant,
          size: 24,
        ),
        selectedLabelStyle: textTheme.labelMedium,
        unselectedLabelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
