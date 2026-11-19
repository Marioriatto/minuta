import 'baby_age.dart';

/// Perfil de bebé (RF-04). La edad se deriva de [birth].
class Baby {
  const Baby({
    required this.id,
    required this.name,
    required this.birth,
    required this.registeredAt,
    this.weightKg,
    this.archivedAt,
  });

  final String id;
  final String name;

  /// Solo fecha (sin hora).
  final DateTime birth;

  /// Lo mide el colchón (RF-11) con "Pesar ahora"; `null` hasta la primera
  /// medición. La app nunca lo escribe a mano.
  final double? weightKg;
  final DateTime registeredAt;

  /// `null` mientras el perfil está activo.
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  BabyAge ageOn(DateTime today) => BabyAge.between(birth, today);
}

/// Datos validados para crear o modificar un perfil. El peso no está aquí:
/// solo lo fija el colchón.
class BabyDraft {
  const BabyDraft({
    required this.name,
    required this.birth,
  });

  final String name;
  final DateTime birth;
}
