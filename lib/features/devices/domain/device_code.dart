enum DeviceCodeError { empty, invalid }

/// Código de vinculación impreso en el módulo (RF-06): 16 letras y números.
abstract final class DeviceCode {
  static const length = 16;

  /// Quita guiones y espacios y pasa a mayúsculas, como hace el servidor.
  static String normalize(String raw) =>
      raw.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();

  static DeviceCodeError? validate(String raw) {
    final code = normalize(raw);
    if (code.isEmpty) return DeviceCodeError.empty;
    if (code.length != length) return DeviceCodeError.invalid;
    return null;
  }
}
