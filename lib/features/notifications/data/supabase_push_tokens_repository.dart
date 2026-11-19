import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/result.dart';
import '../../../core/errors/run_catching.dart';
import '../domain/push_tokens_repository.dart';

/// Guarda los tokens con las RPC `register_push_token` / `unregister_push_token`
/// (la tabla `push_tokens` no admite insert directo desde la app).
class SupabasePushTokensRepository implements PushTokensRepository {
  SupabasePushTokensRepository(this._client);
  final sb.SupabaseClient _client;

  @override
  Future<Result<void>> register({
    required String token,
    required String platform,
  }) =>
      runCatching<void>(
        () => _client.rpc(
          'register_push_token',
          params: {'p_token': token, 'p_platform': platform},
        ),
      );

  @override
  Future<Result<void>> unregister(String token) => runCatching<void>(
        () => _client.rpc('unregister_push_token', params: {'p_token': token}),
      );
}
