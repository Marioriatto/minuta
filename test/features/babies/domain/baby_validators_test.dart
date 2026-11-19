import 'package:colchon_minuta/features/babies/domain/baby_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 11);

  group('name', () {
    test('vacío o solo espacios', () {
      expect(BabyValidators.name(''), BabyFieldError.nameEmpty);
      expect(BabyValidators.name('   '), BabyFieldError.nameEmpty);
    });

    test('longitud máxima', () {
      expect(BabyValidators.name('a' * 50), isNull);
      expect(BabyValidators.name('a' * 51), BabyFieldError.nameTooLong);
    });
  });

  group('birth', () {
    test('obligatoria y no futura', () {
      expect(
        BabyValidators.birth(null, today: today),
        BabyFieldError.birthMissing,
      );
      expect(
        BabyValidators.birth(DateTime(2026, 11, 12), today: today),
        BabyFieldError.birthFuture,
      );
      expect(BabyValidators.birth(today, today: today), isNull);
      expect(
        BabyValidators.birth(DateTime(2026, 3, 5), today: today),
        isNull,
      );
    });
  });

  group('buildDraft', () {
    test('recorta el nombre y quita la hora de la fecha', () {
      final draft = BabyValidators.buildDraft(
        name: '  Emma ',
        birth: DateTime(2026, 3, 5, 14, 30),
        today: today,
      )!;
      expect(draft.name, 'Emma');
      expect(draft.birth, DateTime(2026, 3, 5));
    });

    test('devuelve null si algún dato es inválido', () {
      expect(
        BabyValidators.buildDraft(
          name: '',
          birth: DateTime(2026, 3, 5),
          today: today,
        ),
        isNull,
      );
    });
  });
}
