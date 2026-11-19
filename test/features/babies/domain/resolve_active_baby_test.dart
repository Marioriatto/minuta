import 'package:colchon_minuta/features/babies/domain/active_baby.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_babies.dart';

void main() {
  final oldest = makeBaby(id: 'a', registeredAt: DateTime(2026, 1, 1));
  final newer = makeBaby(id: 'b', registeredAt: DateTime(2026, 2, 1));
  final archived = makeBaby(
    id: 'c',
    registeredAt: DateTime(2025, 1, 1),
    archivedAt: DateTime(2026, 3, 1),
  );

  test('usa el guardado si sigue activo', () {
    expect(resolveActiveBaby([oldest, newer], 'b')?.id, 'b');
  });

  test('si el guardado no existe o está archivado, usa el más antiguo activo',
      () {
    expect(resolveActiveBaby([newer, oldest, archived], 'c')?.id, 'a');
    expect(resolveActiveBaby([newer, oldest], 'zzz')?.id, 'a');
    expect(resolveActiveBaby([newer, oldest], null)?.id, 'a');
  });

  test('sin perfiles activos devuelve null', () {
    expect(resolveActiveBaby(const [], null), isNull);
    expect(resolveActiveBaby([archived], 'c'), isNull);
  });
}
