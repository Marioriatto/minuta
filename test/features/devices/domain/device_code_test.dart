import 'package:colchon_minuta/features/devices/domain/device_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normaliza guiones, espacios y minúsculas', () {
    expect(
      DeviceCode.normalize(' d05c-7563 7154 4754 '),
      'D05C756371544754',
    );
  });

  test('valida longitud', () {
    expect(DeviceCode.validate(''), DeviceCodeError.empty);
    expect(DeviceCode.validate('---'), DeviceCodeError.empty);
    expect(DeviceCode.validate('ABC123'), DeviceCodeError.invalid);
    expect(DeviceCode.validate('D05C-7563-7154-4754'), isNull);
    expect(DeviceCode.validate('D05C7563715447541'), DeviceCodeError.invalid);
  });
}
