import 'baby.dart';

enum BabyFieldError {
  nameEmpty,
  nameTooLong,
  birthMissing,
  birthFuture,
}

/// Reglas de validación del perfil. Los límites son supuestos de diseño (no
/// vienen del SRS) y deben coincidir con los `check` de la tabla `babies`.
abstract final class BabyValidators {
  static const maxNameLength = 50;

  static BabyFieldError? name(String value) {
    final v = value.trim();
    if (v.isEmpty) return BabyFieldError.nameEmpty;
    return v.length > maxNameLength ? BabyFieldError.nameTooLong : null;
  }

  static BabyFieldError? birth(DateTime? value, {required DateTime today}) {
    if (value == null) return BabyFieldError.birthMissing;
    final d = DateTime(value.year, value.month, value.day);
    final t = DateTime(today.year, today.month, today.day);
    return d.isAfter(t) ? BabyFieldError.birthFuture : null;
  }

  /// Devuelve el borrador listo para guardar o `null` si algún dato es inválido.
  static BabyDraft? buildDraft({
    required String name,
    required DateTime? birth,
    required DateTime today,
  }) {
    if (BabyValidators.name(name) != null ||
        BabyValidators.birth(birth, today: today) != null) {
      return null;
    }
    return BabyDraft(
      name: name.trim(),
      birth: DateTime(birth!.year, birth.month, birth.day),
    );
  }
}
