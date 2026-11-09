import '../../l10n/generated/app_localizations.dart';
import '../errors/app_failure.dart';

extension AppFailureL10n on AppLocalizations {
  String forFailure(AppFailure failure) => switch (failure) {
        NetworkFailure() => errorNetwork,
        UnauthorizedFailure() => errorUnauthorized,
        ForbiddenFailure() => errorForbidden,
        NotFoundFailure() => errorNotFound,
        ValidationFailure() => errorValidation,
        ServerFailure() => errorServer,
        UnknownFailure() => errorUnknown,
      };
}
