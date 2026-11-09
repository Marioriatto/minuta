import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../errors/app_failure.dart';
import 'failure_l10n.dart';

/// Resuelve los estados cargando / vacío / error / sin conexión de forma
/// uniforme. Sin lógica de negocio: solo presenta un [AsyncValue].
class StateView<T> extends StatelessWidget {
  const StateView({
    required this.value,
    required this.builder,
    this.isEmpty,
    this.emptyMessage,
    this.onRetry,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;
  final bool Function(T data)? isEmpty;
  final String? emptyMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return value.when(
      skipLoadingOnReload: true,
      loading: () => Center(
        child: CircularProgressIndicator.adaptive(
          semanticsLabel: l10n.commonLoading,
        ),
      ),
      error: (error, _) => _MessageView(
        icon: error is NetworkFailure
            ? Icons.wifi_off_rounded
            : Icons.error_outline_rounded,
        title: error is NetworkFailure
            ? l10n.stateOfflineTitle
            : l10n.stateErrorTitle,
        message: l10n.forFailure(
          error is AppFailure ? error : UnknownFailure(cause: error),
        ),
        onRetry: onRetry,
      ),
      data: (data) => (isEmpty?.call(data) ?? false)
          ? _MessageView(
              icon: Icons.inbox_outlined,
              title: emptyMessage ?? l10n.stateEmptyDefault,
            )
          : builder(context, data),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, textAlign: TextAlign.center),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
            ],
          ],
        ),
      ),
    );
  }
}
