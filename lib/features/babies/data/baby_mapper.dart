import '../domain/baby.dart';

/// Traduce filas de PostgREST ⇄ entidades. Columnas: id, name, birth (date),
/// weight (kg, puede ser null), registered_at, archived_at.
abstract final class BabyMapper {
  static Baby fromRow(Map<String, dynamic> row) => Baby(
        id: row['id'].toString(),
        name: row['name'] as String,
        birth: _dateOnly(row['birth'] as String),
        weightKg: row['weight'] == null
            ? null
            : double.parse(row['weight'].toString()),
        registeredAt: DateTime.parse(row['registered_at'] as String),
        archivedAt: row['archived_at'] == null
            ? null
            : DateTime.parse(row['archived_at'] as String),
      );

  /// `parent_id` no se envía: la base lo asigna con `auth.uid()`.
  /// `weight` tampoco: solo lo escribe `weigh_baby` con la lectura del colchón.
  static Map<String, dynamic> toRow(BabyDraft draft) => {
        'name': draft.name,
        'birth': formatDate(draft.birth),
      };

  static String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _dateOnly(String value) {
    final d = DateTime.parse(value);
    return DateTime(d.year, d.month, d.day);
  }
}
