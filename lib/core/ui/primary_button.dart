import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

enum ButtonTone { primary, tonal, destructive }

/// Botón de ancho completo con estado de carga. Al cargar se deshabilita para
/// evitar envíos duplicados.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.tone = ButtonTone.primary,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final ButtonTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
    );
    final style = switch (tone) {
      ButtonTone.primary => FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(DesignTokens.buttonHeight),
          shape: shape,
        ),
      ButtonTone.tonal => FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(DesignTokens.buttonHeight),
          shape: shape,
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
        ),
      ButtonTone.destructive => FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(DesignTokens.buttonHeight),
          shape: shape,
          backgroundColor: scheme.errorContainer,
          foregroundColor: scheme.error,
        ),
    };
    const textStyle = TextStyle(fontWeight: FontWeight.w800);

    final child = busy
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: tone == ButtonTone.primary ? Colors.white : scheme.primary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(label, style: textStyle)),
            ],
          );

    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: style,
      child: child,
    );
  }
}
