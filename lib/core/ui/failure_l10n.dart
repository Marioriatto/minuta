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
        InvalidCredentialsFailure() => errorInvalidCredentials,
        EmailNotConfirmedFailure() => errorEmailNotConfirmed,
        EmailAlreadyRegisteredFailure() => errorEmailAlreadyRegistered,
        WeakPasswordFailure() => errorWeakPassword,
        RateLimitedFailure() => errorRateLimited,
        LastActiveProfileFailure() => errorLastActiveProfile,
        InvalidDeviceCodeFailure() => errorInvalidDeviceCode,
        MattressWeightFailure(:final problem) => switch (problem) {
            MattressWeightProblem.notLinked => errorMattressNotLinked,
            MattressWeightProblem.offline => errorMattressOffline,
            MattressWeightProblem.noReading => errorNoWeightReading,
          },
      };
}
