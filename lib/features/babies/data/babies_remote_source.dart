import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Acceso crudo a la tabla `babies`. Separado del repositorio para poder
/// probar el mapeo y el manejo de errores sin red.
abstract interface class BabiesRemoteSource {
  Future<List<Map<String, dynamic>>> fetchAll();
  Future<Map<String, dynamic>> insert(Map<String, dynamic> row);
  Future<Map<String, dynamic>> updateRow(
    String id,
    Map<String, dynamic> changes,
  );
  Future<void> deleteRow(String id);

  /// RPC `weigh_baby`: devuelve la fila actualizada.
  Future<Map<String, dynamic>> weigh(String id);
}

class SupabaseBabiesRemoteSource implements BabiesRemoteSource {
  SupabaseBabiesRemoteSource(this._client);

  final sb.SupabaseClient _client;
  static const _table = 'babies';

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async {
    final rows = await _client
        .from(_table)
        .select()
        .order('registered_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<Map<String, dynamic>> insert(Map<String, dynamic> row) async {
    return _client.from(_table).insert(row).select().single();
  }

  @override
  Future<Map<String, dynamic>> updateRow(
    String id,
    Map<String, dynamic> changes,
  ) async {
    return _client.from(_table).update(changes).eq('id', id).select().single();
  }

  @override
  Future<void> deleteRow(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  @override
  Future<Map<String, dynamic>> weigh(String id) async {
    final Object? row = await _client.rpc(
      'weigh_baby',
      params: {'p_baby_id': id},
    );
    return Map<String, dynamic>.from(row! as Map);
  }
}
