import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';

/// Estructura común de las pantallas de cuenta: contenido centrado, con
/// desplazamiento (teclado) y ancho máximo en pantallas grandes.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.children,
    this.title,
    this.subtitle,
    this.header,
    this.showAppBar = false,
    super.key,
  });

  /// Puede omitirse cuando el [header] ya identifica la pantalla (p. ej. el
  /// logo en login y registro).
  final String? title;
  final String? subtitle;
  final Widget? header;
  final List<Widget> children;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: showAppBar ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.pagePadding,
                24,
                DesignTokens.pagePadding,
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (header != null) ...[
                    Align(alignment: Alignment.centerLeft, child: header),
                    SizedBox(height: title == null ? 12 : 20),
                  ],
                  if (title != null)
                    Text(title!, style: theme.textTheme.headlineSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
