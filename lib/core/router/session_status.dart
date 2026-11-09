import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SessionStatus { unknown, unauthenticated, authenticated }

/// Marcador de Fase 0. La fase de autenticación lo sobreescribe con el estado
/// real de la sesión de Supabase (ver SRS).
final sessionStatusProvider = Provider<SessionStatus>(
  (ref) => SessionStatus.unauthenticated,
);
