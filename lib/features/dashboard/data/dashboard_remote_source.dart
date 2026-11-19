import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Lecturas e historial para el inicio. Solo lectura: RLS limita todo a las
/// filas del usuario (`owner_id = auth.uid()`).
abstract interface class DashboardRemoteSource {
  /// Filas de `readings_hourly`: metric, bucket_start, avg_value.
  Future<List<Map<String, dynamic>>> hourly({
    required List<String> metrics,
    required DateTime since,
    String? babyId,
  });

  /// Filas de `events`: id, type, description, occurred_at.
  Future<List<Map<String, dynamic>>> recentEvents({
    required String? babyId,
    required int limit,
  });
}

class SupabaseDashboardRemoteSource implements DashboardRemoteSource {
  SupabaseDashboardRemoteSource(this._client);

  final sb.SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> hourly({
    required List<String> metrics,
    required DateTime since,
    String? babyId,
  }) async {
    var query = _client
        .from('readings_hourly')
        .select('metric, bucket_start, avg_value')
        .inFilter('metric', metrics)
        .gte('bucket_start', since.toUtc().toIso8601String());
    if (babyId != null) query = query.eq('baby_id', babyId);
    final rows = await query.order('bucket_start', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> recentEvents({
    required String? babyId,
    required int limit,
  }) async {
    var query =
        _client.from('events').select('id, type, description, occurred_at');
    query = babyId == null
        ? query.isFilter('baby_id', null)
        : query.or('baby_id.eq.$babyId,baby_id.is.null');
    final rows =
        await query.order('occurred_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }
}
