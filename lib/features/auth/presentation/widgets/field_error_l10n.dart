import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/auth_validators.dart';

String? fieldErrorText(AppLocalizations l10n, FieldError? error) =>
    switch (error) {
      null => null,
      FieldError.empty => l10n.fieldRequired,
      FieldError.invalidEmail => l10n.fieldEmailInvalid,
      FieldError.tooShort =>
        l10n.fieldPasswordTooShort(AuthValidators.minPasswordLength),
      FieldError.mismatch => l10n.fieldPasswordMismatch,
    };
