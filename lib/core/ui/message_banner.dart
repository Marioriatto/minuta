import 'package:flutter/material.dart';

enum BannerKind { error, info }

/// Mensaje en línea (errores de formulario, confirmaciones).
class MessageBanner extends StatelessWidget {
  const MessageBanner({
    required this.message,
    this.kind = BannerKind.error,
    super.key,
  });

  final String message;
  final BannerKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError = kind == BannerKind.error;
    final background =
        isError ? scheme.errorContainer : scheme.primaryContainer;
    final foreground = isError ? scheme.error : scheme.onPrimaryContainer;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              size: 20,
              color: foreground,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: TextStyle(color: foreground))),
          ],
        ),
      ),
    );
  }
}
