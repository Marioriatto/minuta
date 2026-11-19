import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Acceso crudo a `alerts` (RLS: solo las del usuario) y a `mark_alerts_read`.
abstract interface class AlertsRemoteSource {
  Future<List<Map<String, dynamic>>> fetch({required int limit});
  Stream<List<Map<String, dynamic>>> stream({required int limit});

  /// `null` = todas.
  Future<void> markRead(List<int>? ids);
}

class SupabaseAlertsRemoteSource implements AlertsRemoteSource {
  SupabaseAlertsRemoteSource(this._client);

  final sb.SupabaseClient _client;
  static const _table = 'alerts';

  @override
  Future<List<Map<String, dynamic>>> fetch({required int limit}) async {
    final rows = await _client
        .from(_table)
        .select('id, type, severity, payload, occurred_at, read_at')
        .order('occurred_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Stream<List<Map<String, dynamic>>> stream({required int limit}) => _client
      .from(_table)
      .stream(primaryKey: ['id'])
      .order('occurred_at')
      .limit(limit);

  @override
  Future<void> markRead(List<int>? ids) async {
    await _client.rpc('mark_alerts_read', params: {'p_ids': ids});
  }
}
