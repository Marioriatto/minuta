import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Logo de la marca: el bebé del ícono de la app (círculo azul) con el nombre
/// "Minuta" a la derecha, al estilo de un logotipo horizontal.
class MinutaLogo extends StatelessWidget {
  const MinutaLogo({required this.label, this.size = 44, super.key});

  /// Nombre de la marca (viene del ARB).
  final String label;

  /// Diámetro del círculo; el texto escala con él.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      header: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: DesignTokens.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.child_care_rounded,
              color: Colors.white,
              size: size * 0.62,
            ),
          ),
          SizedBox(width: size * 0.22),
          Text(
            label,
            style: TextStyle(
              fontSize: size * 0.78,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1,
              color: DesignTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
