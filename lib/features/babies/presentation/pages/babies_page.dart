import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/ui/failure_l10n.dart';
import '../../../../core/ui/primary_button.dart';
import '../../../../core/ui/state_view.dart';
import '../../../../core/ui/surface_card.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../babies_providers.dart';
import '../../domain/baby.dart';
import '../controllers/babies_actions_controller.dart';
import '../widgets/baby_avatar.dart';
import '../widgets/baby_formatters.dart';

enum _BabyMenu { weigh, edit, archive, restore, delete }

/// Ajustes → Perfiles de bebé: elegir el activo, editar, archivar, restaurar y
/// eliminar definitivamente (RF-04, DB-001).
class BabiesPage extends ConsumerWidget {
  const BabiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final babies = ref.watch(babiesProvider);
    final active = ref.watch(activeBabiesProvider);
    final archived = ref.watch(archivedBabiesProvider);
    final current = ref.watch(activeBabyProvider);
    final actions = ref.watch(babiesActionsControllerProvider);

    ref.listen(babiesActionsControllerProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      final failure = next.failure;
      if (failure != null) {
        messenger
            .showSnackBar(SnackBar(content: Text(l10n.forFailure(failure))));
        return;
      }
      final done = next.done;
      if (done != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              switch (done) {
                BabyAction.archived => l10n.babyArchivedSnack,
                BabyAction.restored => l10n.babyRestoredSnack,
                BabyAction.deleted => l10n.babyDeletedSnack,
                BabyAction.weighed => l10n.babyWeighedSnack,
              },
            ),
          ),
        );
      }
    });

    Widget tile(Baby baby) => _BabyTile(
          baby: baby,
          isCurrent: current?.id == baby.id,
          busy: actions.busyId == baby.id,
          canArchive: active.length > 1,
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.babiesTitle)),
      body: StateView<List<Baby>>(
        value: babies,
        onRetry: () => ref.invalidate(babiesProvider),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _SectionLabel(l10n.babiesActiveSection),
            SurfaceCard(
              child: Column(
                children: [
                  for (var i = 0; i < active.length; i++) ...[
                    if (i > 0) const Divider(),
                    tile(active[i]),
                  ],
                ],
              ),
            ),
            if (active.length == 1)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  l10n.babyLastProfileNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: l10n.babiesAdd,
              tone: ButtonTone.tonal,
              icon: Icons.add_rounded,
              onPressed: () => context.push(AppRoutes.settingsBabiesNew),
            ),
            if (archived.isNotEmpty) ...[
              const SizedBox(height: 28),
              _SectionLabel(l10n.babiesArchivedSection),
              SurfaceCard(
                child: Column(
                  children: [
                    for (var i = 0; i < archived.length; i++) ...[
                      if (i > 0) const Divider(),
                      tile(archived[i]),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}

class _BabyTile extends ConsumerWidget {
  const _BabyTile({
    required this.baby,
    required this.isCurrent,
    required this.busy,
    required this.canArchive,
  });

  final Baby baby;
  final bool isCurrent;
  final bool busy;
  final bool canArchive;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.babyDeleteTitle(baby.name)),
        content: Text(l10n.babyDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.babyDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(babiesActionsControllerProvider.notifier).delete(baby);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(babiesActionsControllerProvider.notifier);
    final age = babyAgeText(l10n, baby.ageOn(DateTime.now()));
    final weight = babyWeightText(context, baby.weightKg);

    return ListTile(
      leading: BabyAvatar(name: baby.name),
      title: Row(
        children: [
          Flexible(
            child: Text(
              baby.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (isCurrent) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle_rounded, size: 18, color: scheme.tertiary),
            const SizedBox(width: 4),
            Text(
              l10n.babyActiveBadge,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: scheme.tertiary,
              ),
            ),
          ],
        ],
      ),
      subtitle: Text('$age · $weight'),
      onTap: (baby.isArchived || isCurrent || busy)
          ? null
          : () => controller.setActive(baby),
      trailing: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : PopupMenuButton<_BabyMenu>(
              tooltip: baby.name,
              onSelected: (action) async {
                switch (action) {
                  case _BabyMenu.weigh:
                    await controller.weigh(baby);
                  case _BabyMenu.edit:
                    await context.push(AppRoutes.settingsBabyEdit(baby.id));
                  case _BabyMenu.archive:
                    await controller.archive(baby);
                  case _BabyMenu.restore:
                    await controller.restore(baby);
                  case _BabyMenu.delete:
                    await _confirmDelete(context, ref);
                }
              },
              itemBuilder: (_) => [
                if (!baby.isArchived)
                  PopupMenuItem(
                    value: _BabyMenu.weigh,
                    child: Text(l10n.babyMenuWeigh),
                  ),
                if (!baby.isArchived)
                  PopupMenuItem(
                    value: _BabyMenu.edit,
                    child: Text(l10n.babyMenuEdit),
                  ),
                if (!baby.isArchived && canArchive)
                  PopupMenuItem(
                    value: _BabyMenu.archive,
                    child: Text(l10n.babyMenuArchive),
                  ),
                if (baby.isArchived)
                  PopupMenuItem(
                    value: _BabyMenu.restore,
                    child: Text(l10n.babyMenuRestore),
                  ),
                if (baby.isArchived)
                  PopupMenuItem(
                    value: _BabyMenu.delete,
                    child: Text(
                      l10n.babyMenuDelete,
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
              ],
            ),
    );
  }
}
