import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Acceso crudo a `detection_periods` (RLS: solo lectura de los propios) y a
/// las RPC `start_detection` / `stop_detection`.
abstract interface class DetectionRemoteSource {
  Future<List<Map<String, dynamic>>> fetch({required int limit});
  Stream<List<Map<String, dynamic>>> stream({required int limit});
  Future<Map<String, dynamic>> start({
    required String deviceId,
    required String babyId,
    int? minutes,
  });
  Future<Map<String, dynamic>> stop();
}

class SupabaseDetectionRemoteSource implements DetectionRemoteSource {
  SupabaseDetectionRemoteSource(this._client);

  final sb.SupabaseClient _client;
  static const _table = 'detection_periods';
  static const _columns = 'id, baby_id, device_id, starts_at, ends_at';

  @override
  Future<List<Map<String, dynamic>>> fetch({required int limit}) async {
    final rows = await _client
        .from(_table)
        .select(_columns)
        .order('starts_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Stream<List<Map<String, dynamic>>> stream({required int limit}) => _client
      .from(_table)
      .stream(primaryKey: ['id'])
      .order('starts_at')
      .limit(limit);

  Map<String, dynamic> _row(Object? result) =>
      Map<String, dynamic>.from(result! as Map);

  @override
  Future<Map<String, dynamic>> start({
    required String deviceId,
    required String babyId,
    int? minutes,
  }) async =>
      _row(
        await _client.rpc<dynamic>(
          'start_detection',
          params: {
            'p_device_id': deviceId,
            'p_baby_id': babyId,
            'p_minutes': minutes,
          },
        ),
      );

  @override
  Future<Map<String, dynamic>> stop() async =>
      _row(await _client.rpc<dynamic>('stop_detection'));
}
