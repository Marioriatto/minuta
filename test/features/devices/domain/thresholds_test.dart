import 'package:colchon_minuta/features/devices/domain/thresholds.dart';
import 'package:flutter_test/flutter_test.dart';

ThresholdsValidation _validate({
  String tempMin = '',
  String tempMax = '',
  String humMin = '',
  String humMax = '',
}) =>
    ThresholdsValidator.validate(
      tempMin: tempMin,
      tempMax: tempMax,
      humMin: humMin,
      humMax: humMax,
    );

void main() {
  test('acepta coma decimal y deja vacío como sin límite', () {
    final r = _validate(tempMin: '18,5', tempMax: '26', humMax: ' 60 ');
    expect(r.isValid, isTrue);
    expect(r.value!.tempMin, 18.5);
    expect(r.value!.tempMax, 26);
    expect(r.value!.humMin, isNull);
    expect(r.value!.humMax, 60);
  });

  test('todos vacíos es válido (sin umbrales)', () {
    final r = _validate();
    expect(r.isValid, isTrue);
    expect(r.value!.tempMin, isNull);
  });

  test('texto que no es número', () {
    final r = _validate(tempMax: 'caliente');
    expect(r.errors[ThresholdField.tempMax], ThresholdError.notANumber);
    expect(r.isValid, isFalse);
  });

  test('fuera de rango', () {
    final r = _validate(tempMin: '-30', humMax: '101');
    expect(r.errors[ThresholdField.tempMin], ThresholdError.outOfRange);
    expect(r.errors[ThresholdField.humMax], ThresholdError.outOfRange);
  });

  test('el mínimo debe ser menor que el máximo', () {
    final r =
        _validate(tempMin: '26', tempMax: '26', humMin: '70', humMax: '30');
    expect(r.errors[ThresholdField.tempMax], ThresholdError.minNotBelowMax);
    expect(r.errors[ThresholdField.humMax], ThresholdError.minNotBelowMax);
  });

  test('lee la configuración del servidor', () {
    final t = Thresholds.fromConfig(const {
      'thresholds': {
        'temperature': {'min': 18, 'max': 26},
        'humidity': {'max': 60},
      },
    });
    expect(t.tempMin, 18);
    expect(t.tempMax, 26);
    expect(t.humMin, isNull);
    expect(t.humMax, 60);
    expect(Thresholds.fromConfig(const {}).tempMax, isNull);
  });

  test('nivel de una medición', () {
    const t = Thresholds(tempMin: 18, tempMax: 26, humMax: 60);
    expect(t.temperatureLevel(22), MetricLevel.ok);
    expect(t.temperatureLevel(26.1), MetricLevel.high);
    expect(t.temperatureLevel(17.9), MetricLevel.low);
    expect(t.temperatureLevel(null), MetricLevel.unknown);
    expect(t.humidityLevel(10), MetricLevel.ok);
    expect(t.humidityLevel(61), MetricLevel.high);
  });
}
