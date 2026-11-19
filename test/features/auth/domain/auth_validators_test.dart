import 'package:colchon_minuta/features/auth/domain/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('email', () {
    test('vacío o solo espacios', () {
      expect(AuthValidators.email(''), FieldError.empty);
      expect(AuthValidators.email('   '), FieldError.empty);
    });

    test('formato inválido', () {
      for (final v in ['a', 'a@', 'a@b', 'a b@c.com', '@c.com']) {
        expect(AuthValidators.email(v), FieldError.invalidEmail, reason: v);
      }
    });

    test('válido, ignorando espacios laterales', () {
      expect(AuthValidators.email('maria@correo.com'), isNull);
      expect(AuthValidators.email('  maria@correo.com '), isNull);
    });
  });

  group('contraseñas', () {
    test('login solo exige que no esté vacía', () {
      expect(AuthValidators.loginPassword(''), FieldError.empty);
      expect(AuthValidators.loginPassword('1'), isNull);
    });

    test('nueva contraseña exige longitud mínima', () {
      expect(AuthValidators.newPassword(''), FieldError.empty);
      expect(AuthValidators.newPassword('1234567'), FieldError.tooShort);
      expect(AuthValidators.newPassword('12345678'), isNull);
    });

    test('confirmación', () {
      expect(AuthValidators.confirmation('abc12345', ''), FieldError.empty);
      expect(
        AuthValidators.confirmation('abc12345', 'abc12346'),
        FieldError.mismatch,
      );
      expect(AuthValidators.confirmation('abc12345', 'abc12345'), isNull);
    });
  });
}
