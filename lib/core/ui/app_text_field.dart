import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';

/// Campo con etiqueta arriba (como en el diseño). Los estilos viven aquí y no
/// en el tema global, para no depender de APIs de tema en migración.
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.label,
    required this.controller,
    this.hint,
    this.prefixIcon,
    this.errorText,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.showPasswordTooltip,
    this.hidePasswordTooltip,
    this.readOnly = false,
    this.onTap,
    this.trailingIcon,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? prefixIcon;
  final String? errorText;
  final bool obscure;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  /// Textos localizados del botón de mostrar/ocultar contraseña.
  final String? showPasswordTooltip;
  final String? hidePasswordTooltip;

  /// Campo de solo lectura (p. ej. selector de fecha) que reacciona a [onTap].
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? trailingIcon;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusField),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: widget.label,
          child: TextField(
            controller: widget.controller,
            enabled: widget.enabled,
            obscureText: _hidden,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            onSubmitted: widget.onSubmitted,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            inputFormatters: widget.inputFormatters,
            textCapitalization: widget.textCapitalization,
            autocorrect: false,
            enableSuggestions: !widget.obscure,
            decoration: InputDecoration(
              hintText: widget.hint,
              errorText: widget.errorText,
              filled: true,
              fillColor: scheme.surfaceContainerLowest,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              prefixIcon: widget.prefixIcon == null
                  ? null
                  : Icon(widget.prefixIcon, color: scheme.onSurfaceVariant),
              suffixIcon: widget.obscure
                  ? IconButton(
                      tooltip: _hidden
                          ? widget.showPasswordTooltip
                          : widget.hidePasswordTooltip,
                      icon: Icon(
                        _hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    )
                  : widget.trailingIcon == null
                      ? null
                      : Icon(
                          widget.trailingIcon,
                          color: scheme.onSurfaceVariant,
                        ),
              border: _border(scheme.outlineVariant),
              enabledBorder: _border(scheme.outlineVariant),
              focusedBorder: _border(scheme.primary, 1.6),
              errorBorder: _border(scheme.error),
              focusedErrorBorder: _border(scheme.error, 1.6),
              disabledBorder: _border(scheme.outlineVariant),
            ),
          ),
        ),
      ],
    );
  }
}
