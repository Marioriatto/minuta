import 'package:colchon_minuta/features/babies/domain/baby_age.dart';
import 'package:flutter_test/flutter_test.dart';

BabyAge _age(DateTime birth, DateTime today) => BabyAge.between(birth, today);

void main() {
  final today = DateTime(2026, 11, 11);

  test('recién nacido: días', () {
    final age = _age(today, today);
    expect(age.unit, BabyAgeUnit.days);
    expect(age.value, 0);
  });

  test('menos de 2 semanas: días', () {
    final age = _age(DateTime(2026, 11, 1), today);
    expect(age.unit, BabyAgeUnit.days);
    expect(age.value, 10);
  });

  test('de 2 semanas a 3 meses: semanas', () {
    final age = _age(DateTime(2026, 10, 21), today);
    expect(age.unit, BabyAgeUnit.weeks);
    expect(age.value, 3);
    // Casi 3 meses: sigue en semanas.
    final almost = _age(DateTime(2026, 8, 13), today);
    expect(almost.totalMonths, 2);
    expect(almost.unit, BabyAgeUnit.weeks);
  });

  test('de 3 a 23 meses: meses', () {
    expect(_age(DateTime(2026, 8, 11), today).unit, BabyAgeUnit.months);
    expect(_age(DateTime(2026, 8, 11), today).value, 3);
    expect(_age(DateTime(2025, 9, 11), today).value, 14);
  });

  test('desde 24 meses: años', () {
    final age = _age(DateTime(2024, 11, 11), today);
    expect(age.unit, BabyAgeUnit.years);
    expect(age.value, 2);
  });

  test('fin de mes: no cuenta un mes completo antes de tiempo', () {
    final age = _age(DateTime(2026, 1, 31), DateTime(2026, 2, 28));
    expect(age.totalMonths, 0);
    expect(age.totalDays, 28);
  });

  test('fecha futura devuelve cero', () {
    final age = _age(DateTime(2027, 1, 1), today);
    expect(age.totalDays, 0);
    expect(age.totalMonths, 0);
  });
}
