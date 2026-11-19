import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/baby_age.dart';
import '../../domain/baby_validators.dart';

String babyAgeText(AppLocalizations l10n, BabyAge age) => switch (age.unit) {
      BabyAgeUnit.days => l10n.babyAgeDays(age.value),
      BabyAgeUnit.weeks => l10n.babyAgeWeeks(age.value),
      BabyAgeUnit.months => l10n.babyAgeMonths(age.value),
      BabyAgeUnit.years => l10n.babyAgeYears(age.value),
    };

/// "5,84 kg" con el separador decimal del idioma, o el aviso de que aún no
/// se ha pesado con el colchón.
String babyWeightText(BuildContext context, double? kg) {
  final l10n = AppLocalizations.of(context);
  if (kg == null) return l10n.babyWeightPending;
  final locale = Localizations.localeOf(context).toString();
  final value = NumberFormat('#,##0.###', locale).format(kg);
  return l10n.babyWeightKg(value);
}

String? babyFieldErrorText(AppLocalizations l10n, BabyFieldError? error) =>
    switch (error) {
      null => null,
      BabyFieldError.nameEmpty => l10n.babyNameRequired,
      BabyFieldError.nameTooLong =>
        l10n.babyNameTooLong(BabyValidators.maxNameLength),
      BabyFieldError.birthMissing => l10n.babyBirthRequired,
      BabyFieldError.birthFuture => l10n.babyBirthFuture,
    };
