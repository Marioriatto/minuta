import 'package:flutter/material.dart';

/// Ícono dentro de un cuadrado redondeado tintado.
class IconBadge extends StatelessWidget {
  const IconBadge({required this.icon, this.size = 56, super.key});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: scheme.primary, size: size * 0.5),
    );
  }
}
