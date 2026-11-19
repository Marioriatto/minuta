import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import 'data/supabase_auth_repository.dart';
import 'domain/auth_repository.dart';
import 'domain/auth_snapshot.dart';
import 'domain/auth_use_cases.dart';

/// Punto de composición de la feature: es el único lugar que conecta la capa de
/// datos con el dominio. La presentación solo importa este archivo.

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);

final signInWithEmailProvider = Provider<SignInWithEmail>(
  (ref) => SignInWithEmail(ref.watch(authRepositoryProvider)),
);
final signUpWithEmailProvider = Provider<SignUpWithEmail>(
  (ref) => SignUpWithEmail(ref.watch(authRepositoryProvider)),
);
final resendVerificationProvider = Provider<ResendVerification>(
  (ref) => ResendVerification(ref.watch(authRepositoryProvider)),
);
final requestPasswordResetProvider = Provider<RequestPasswordReset>(
  (ref) => RequestPasswordReset(ref.watch(authRepositoryProvider)),
);
final resetPasswordProvider = Provider<ResetPassword>(
  (ref) => ResetPassword(ref.watch(authRepositoryProvider)),
);
final signInWithSocialProvider = Provider<SignInWithSocial>(
  (ref) => SignInWithSocial(ref.watch(authRepositoryProvider)),
);
final signOutProvider = Provider<SignOut>(
  (ref) => SignOut(ref.watch(authRepositoryProvider)),
);

/// Sesión actual y cambios. Fuente de verdad del estado de autenticación.
final authSnapshotProvider = StreamProvider<AuthSnapshot>(
  (ref) => ref.watch(authRepositoryProvider).watchSession(),
);
