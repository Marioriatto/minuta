import 'package:flutter/material.dart';

/// Tema base provisional: la identidad visual no está definida (pendiente).
abstract final class AppTheme {
  static const _seed = Colors.indigo;

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      );
}
