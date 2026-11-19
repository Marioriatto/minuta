import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Acceso crudo a `devices` y a sus funciones RPC. Separado del repositorio para
/// probar el mapeo y los errores sin red.
abstract interface class DevicesRemoteSource {
  Future<List<Map<String, dynamic>>> fetchAll();
  Stream<List<Map<String, dynamic>>> stream();
  Future<Map<String, dynamic>> claim({required String code, String? name});
  Future<Map<String, dynamic>> setLights({
    required String deviceId,
    required bool on,
    required int brightness,
    required int speed,
    int? minutes,
    bool keepTimer = false,
  });
  Future<Map<String, dynamic>> setThresholds({
    required String deviceId,
    double? tempMin,
    double? tempMax,
    double? humMin,
    double? humMax,
  });

  /// Encola un comando para el módulo (tabla `commands`). RLS exige que sea
  /// del usuario y el trigger `commands_enforce_refs` que el módulo también.
  Future<void> sendCommand({
    required String deviceId,
    required String command,
    Map<String, Object?> params = const {},
  });
}

class SupabaseDevicesRemoteSource implements DevicesRemoteSource {
  SupabaseDevicesRemoteSource(this._client);

  final sb.SupabaseClient _client;
  static const _table = 'devices';

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async {
    final rows = await _client.from(_table).select().order('claimed_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Stream<List<Map<String, dynamic>>> stream() =>
      _client.from(_table).stream(primaryKey: ['id']).order('claimed_at');

  Map<String, dynamic> _row(Object? result) =>
      Map<String, dynamic>.from(result! as Map);

  @override
  Future<Map<String, dynamic>> claim({
    required String code,
    String? name,
  }) async =>
      _row(
        await _client.rpc(
          'claim_device',
          params: {'p_code': code, 'p_name': name},
        ),
      );

  @override
  Future<Map<String, dynamic>> setLights({
    required String deviceId,
    required bool on,
    required int brightness,
    required int speed,
    int? minutes,
    bool keepTimer = false,
  }) async =>
      _row(
        await _client.rpc(
          'set_lights',
          params: {
            'p_device_id': deviceId,
            'p_on': on,
            'p_brightness': brightness,
            'p_speed': speed,
            'p_minutes': minutes,
            'p_keep_timer': keepTimer,
          },
        ),
      );

  @override
  Future<Map<String, dynamic>> setThresholds({
    required String deviceId,
    double? tempMin,
    double? tempMax,
    double? humMin,
    double? humMax,
  }) async =>
      _row(
        await _client.rpc(
          'set_thresholds',
          params: {
            'p_device_id': deviceId,
            'p_temp_min': tempMin,
            'p_temp_max': tempMax,
            'p_hum_min': humMin,
            'p_hum_max': humMax,
          },
        ),
      );

  @override
  Future<void> sendCommand({
    required String deviceId,
    required String command,
    Map<String, Object?> params = const {},
  }) async {
    // owner_id, status ('pending') y expires_at (2 min) los pone la base.
    await _client.from('commands').insert({
      'device_id': deviceId,
      'command': command,
      'params': params,
    });
  }
}
