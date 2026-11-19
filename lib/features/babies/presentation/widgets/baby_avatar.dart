import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';

/// Círculo con la inicial del bebé sobre un degradado cálido.
class BabyAvatar extends StatelessWidget {
  const BabyAvatar({required this.name, this.size = 44, super.key});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.34),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [DesignTokens.avatarStart, DesignTokens.avatarEnd],
          ),
        ),
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            color: DesignTokens.avatarText,
          ),
        ),
      ),
    );
  }
}
