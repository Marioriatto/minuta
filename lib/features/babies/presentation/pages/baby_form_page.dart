import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_text_field.dart';
import '../../../../core/ui/failure_l10n.dart';
import '../../../../core/ui/message_banner.dart';
import '../../../../core/ui/primary_button.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/controllers/sign_out_controller.dart';
import '../../babies_providers.dart';
import '../../domain/baby.dart';
import '../controllers/baby_form_controller.dart';
import '../widgets/baby_formatters.dart';

/// Alta o edición de un perfil.
/// - [isFirst]: primer perfil obligatorio tras los permisos (sin volver atrás).
/// - [babyId]: edita ese perfil; si es nulo, crea uno nuevo.
class BabyFormPage extends ConsumerStatefulWidget {
  const BabyFormPage({this.babyId, this.isFirst = false, super.key});

  final String? babyId;
  final bool isFirst;

  @override
  ConsumerState<BabyFormPage> createState() => _BabyFormPageState();
}

class _BabyFormPageState extends ConsumerState<BabyFormPage> {
  final _name = TextEditingController();
  final _birthText = TextEditingController();
  DateTime? _birth;
  bool _prefilled = false;

  bool get _isEdit => widget.babyId != null;

  @override
  void initState() {
    super.initState();
    // Los controladores no se autodestruyen: se limpian al abrir la pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(babyFormControllerProvider);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _birthText.dispose();
    super.dispose();
  }

  void _prefill(BuildContext context, Baby baby) {
    if (_prefilled) return;
    _prefilled = true;
    _name.text = baby.name;
    _birth = baby.birth;
    _birthText.text = MaterialLocalizations.of(context).formatMediumDate(
      baby.birth,
    );
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final l10n = AppLocalizations.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      helpText: l10n.babyBirthLabel,
    );
    if (picked == null || !mounted) return;
    final date = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      _birth = date;
      _birthText.text =
          MaterialLocalizations.of(context).formatMediumDate(date);
    });
  }

  void _submit() {
    ref.read(babyFormControllerProvider.notifier).submit(
          babyId: widget.babyId,
          name: _name.text,
          birth: _birth,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final form = ref.watch(babyFormControllerProvider);

    ref.listen(babyFormControllerProvider, (previous, next) {
      if (next.completed && !(previous?.completed ?? false)) {
        // En el primer perfil, el router sale solo al haber un perfil activo.
        if (!widget.isFirst && context.canPop()) context.pop();
      }
    });

    if (_isEdit) {
      final babies = ref.watch(babiesProvider);
      Baby? editing;
      for (final b in babies.value ?? const <Baby>[]) {
        if (b.id == widget.babyId) editing = b;
      }
      if (editing == null) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.babyFormEditTitle)),
          body: Center(
            child: babies.isLoading
                ? const CircularProgressIndicator()
                : Text(l10n.errorNotFound),
          ),
        );
      }
      _prefill(context, editing);
    }

    final title = widget.isFirst
        ? l10n.babyFormFirstTitle
        : (_isEdit ? l10n.babyFormEditTitle : l10n.babyFormNewTitle);

    return Scaffold(
      appBar: widget.isFirst ? null : AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.isFirst) ...[
                    Text(title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      l10n.babyFormFirstSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  AppTextField(
                    label: l10n.babyNameLabel,
                    hint: l10n.babyNameHint,
                    controller: _name,
                    prefixIcon: Icons.child_care_rounded,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    errorText: babyFieldErrorText(l10n, form.nameError),
                    enabled: !form.busy,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: l10n.babyBirthLabel,
                    hint: l10n.babyBirthHint,
                    controller: _birthText,
                    prefixIcon: Icons.cake_outlined,
                    trailingIcon: Icons.calendar_today_outlined,
                    readOnly: true,
                    onTap: form.busy ? null : _pickBirth,
                    errorText: babyFieldErrorText(l10n, form.birthError),
                    enabled: !form.busy,
                  ),
                  const SizedBox(height: 16),
                  // El peso no se escribe: lo mide el colchón (RF-11).
                  Row(
                    children: [
                      Icon(
                        Icons.monitor_weight_outlined,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.babyWeightFromMattressNote,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (form.failure != null) ...[
                    const SizedBox(height: 16),
                    MessageBanner(message: l10n.forFailure(form.failure!)),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: _isEdit ? l10n.commonSave : l10n.babyCreate,
                    busy: form.busy,
                    onPressed: _submit,
                  ),
                  if (widget.isFirst) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: form.busy
                            ? null
                            : () => ref
                                .read(signOutControllerProvider.notifier)
                                .signOut(),
                        child: Text(
                          l10n.settingsSignOut,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
