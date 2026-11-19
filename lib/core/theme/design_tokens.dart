import 'package:flutter/material.dart';

/// Tokens de diseño.
///
/// ATENCIÓN: los colores son ESTIMADOS a partir de las capturas de Figma, no
/// valores exportados. Sustitúyelos aquí (único lugar) por los del Inspect o las
/// Variables de Figma; el resto de la app los consume desde el tema.
abstract final class DesignTokens {
  // Marca
  static const primary = Color(0xFF2A7FA8);
  static const onPrimaryContainer = Color(0xFF1F6A8C);
  static const primaryContainer = Color(0xFFE3F3FA);
  static const accent = Color(0xFF63B7DB);

  // Superficies y texto
  static const background = Color(0xFFF5FAFB);
  static const surfaceCard = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1E2A3A);
  static const textSecondary = Color(0xFF6B7A8C);
  static const outline = Color(0xFFB9CBD5);
  static const outlineSoft = Color(0xFFDDE9EF);

  // Estados
  static const success = Color(0xFF2E8B6A);
  static const successContainer = Color(0xFFE6F6EE);
  static const danger = Color(0xFFD64545);
  static const dangerContainer = Color(0xFFFDECEC);

  // Avatares de perfil (degradado durazno, estimado)
  static const avatarStart = Color(0xFFF8D9C2);
  static const avatarEnd = Color(0xFFF2B997);
  static const avatarText = Color(0xFF8A4B2A);

  // Formas y espaciado
  static const radiusField = 16.0;
  static const radiusButton = 16.0;
  static const radiusCard = 20.0;
  static const buttonHeight = 52.0;
  static const pagePadding = 24.0;
}
