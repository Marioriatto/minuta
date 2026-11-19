import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

/// Tema claro. El modo oscuro queda fuera de esta fase (no está en el SRS ni
/// existe diseño). Tipografía Nunito (estimada de las capturas).
abstract final class AppTheme {
  static const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: DesignTokens.primary,
    onPrimary: Colors.white,
    primaryContainer: DesignTokens.primaryContainer,
    onPrimaryContainer: DesignTokens.onPrimaryContainer,
    secondary: DesignTokens.accent,
    onSecondary: Colors.white,
    tertiary: DesignTokens.success,
    onTertiary: Colors.white,
    tertiaryContainer: DesignTokens.successContainer,
    onTertiaryContainer: DesignTokens.success,
    error: DesignTokens.danger,
    onError: Colors.white,
    errorContainer: DesignTokens.dangerContainer,
    onErrorContainer: DesignTokens.danger,
    surface: DesignTokens.background,
    onSurface: DesignTokens.textPrimary,
    onSurfaceVariant: DesignTokens.textSecondary,
    outline: DesignTokens.outline,
    outlineVariant: DesignTokens.outlineSoft,
    surfaceContainerLowest: DesignTokens.surfaceCard,
  );

  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    return base.copyWith(
      scaffoldBackgroundColor: DesignTokens.background,
      textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).apply(
        bodyColor: DesignTokens.textPrimary,
        displayColor: DesignTokens.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DesignTokens.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: DesignTokens.textPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DesignTokens.surfaceCard,
        surfaceTintColor: Colors.transparent,
        indicatorColor: DesignTokens.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? DesignTokens.primary
                : DesignTokens.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? DesignTokens.primary
                : DesignTokens.textSecondary,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? DesignTokens.accent
              : DesignTokens.outline,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dividerTheme: const DividerThemeData(
        color: DesignTokens.outlineSoft,
        space: 1,
      ),
    );
  }
}
