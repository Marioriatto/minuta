/// Umbrales de alerta de la cuna (RF-18).
enum ThresholdField { tempMin, tempMax, humMin, humMax }

enum ThresholdError { notANumber, outOfRange, minNotBelowMax }

enum MetricLevel { ok, high, low, unknown }

class Thresholds {
  const Thresholds({this.tempMin, this.tempMax, this.humMin, this.humMax});

  factory Thresholds.fromConfig(Map<String, Object?> config) {
    double? read(Object? group, String key) {
      if (group is! Map) return null;
      final v = group[key];
      return v is num ? v.toDouble() : null;
    }

    final t = config['thresholds'];
    final temp = t is Map ? t['temperature'] : null;
    final hum = t is Map ? t['humidity'] : null;
    return Thresholds(
      tempMin: read(temp, 'min'),
      tempMax: read(temp, 'max'),
      humMin: read(hum, 'min'),
      humMax: read(hum, 'max'),
    );
  }

  final double? tempMin;
  final double? tempMax;
  final double? humMin;
  final double? humMax;

  MetricLevel temperatureLevel(double? value) =>
      levelFor(value, tempMin, tempMax);
  MetricLevel humidityLevel(double? value) => levelFor(value, humMin, humMax);
}

MetricLevel levelFor(double? value, double? min, double? max) {
  if (value == null) return MetricLevel.unknown;
  if (max != null && value > max) return MetricLevel.high;
  if (min != null && value < min) return MetricLevel.low;
  return MetricLevel.ok;
}

class ThresholdsValidation {
  const ThresholdsValidation({this.value, this.errors = const {}});

  final Thresholds? value;
  final Map<ThresholdField, ThresholdError> errors;
  bool get isValid => errors.isEmpty && value != null;
}

/// Valida los cuatro campos de texto del formulario. Un campo vacío significa
/// "sin límite". Acepta coma o punto decimal.
abstract final class ThresholdsValidator {
  static const tempRange = (min: -20.0, max: 60.0);
  static const humRange = (min: 0.0, max: 100.0);

  static ThresholdsValidation validate({
    required String tempMin,
    required String tempMax,
    required String humMin,
    required String humMax,
  }) {
    final errors = <ThresholdField, ThresholdError>{};

    double? parse(ThresholdField field, String raw, double lo, double hi) {
      final text = raw.trim().replaceAll(',', '.');
      if (text.isEmpty) return null;
      final v = double.tryParse(text);
      if (v == null || !v.isFinite) {
        errors[field] = ThresholdError.notANumber;
        return null;
      }
      if (v < lo || v > hi) {
        errors[field] = ThresholdError.outOfRange;
        return null;
      }
      return v;
    }

    final tMin = parse(
      ThresholdField.tempMin,
      tempMin,
      tempRange.min,
      tempRange.max,
    );
    final tMax = parse(
      ThresholdField.tempMax,
      tempMax,
      tempRange.min,
      tempRange.max,
    );
    final hMin =
        parse(ThresholdField.humMin, humMin, humRange.min, humRange.max);
    final hMax =
        parse(ThresholdField.humMax, humMax, humRange.min, humRange.max);

    if (tMin != null && tMax != null && tMin >= tMax) {
      errors[ThresholdField.tempMax] = ThresholdError.minNotBelowMax;
    }
    if (hMin != null && hMax != null && hMin >= hMax) {
      errors[ThresholdField.humMax] = ThresholdError.minNotBelowMax;
    }
    if (errors.isNotEmpty) return ThresholdsValidation(errors: errors);

    return ThresholdsValidation(
      value: Thresholds(
        tempMin: tMin,
        tempMax: tMax,
        humMin: hMin,
        humMax: hMax,
      ),
    );
  }
}
