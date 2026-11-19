import 'package:colchon_minuta/features/devices/domain/lights_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 19, 18);

  test('valores por defecto con configuración vacía', () {
    final s = LightsSettings.fromConfig(const {});
    expect(s.on, isFalse);
    expect(s.brightness, 50);
    expect(s.speed, 50);
    expect(s.timerMinutes, isNull);
    expect(s.endsAt, isNull);
    expect(s.isOn(now), isFalse);
  });

  test('lee la configuración de fábrica y limita 0-100', () {
    final s = LightsSettings.fromConfig(const {
      'on': true,
      'brightness': 150,
      'speed': -4,
      'timer_minutes': 30,
      'ends_at': '2026-11-19T18:30:00+00:00',
    });
    expect(s.on, isTrue);
    expect(s.brightness, 100);
    expect(s.speed, 0);
    expect(s.timerMinutes, 30);
    expect(s.endsAt, DateTime.utc(2026, 11, 19, 18, 30));
  });

  test('ignora tipos inválidos', () {
    final s = LightsSettings.fromConfig(const {
      'on': 'sí',
      'brightness': 'alto',
      'ends_at': 12,
    });
    expect(s.on, isFalse);
    expect(s.brightness, 50);
    expect(s.endsAt, isNull);
  });

  test('el temporizador vencido apaga aunque la base diga on', () {
    final s = LightsSettings(
      on: true,
      timerMinutes: 15,
      endsAt: DateTime.utc(2026, 11, 19, 18, 10),
    );
    expect(s.isOn(DateTime.utc(2026, 11, 19, 18, 9, 59)), isTrue);
    expect(s.isOn(DateTime.utc(2026, 11, 19, 18, 10)), isFalse);
    expect(s.remaining(now), const Duration(minutes: 10));
    expect(s.remaining(DateTime.utc(2026, 11, 19, 18, 11)), isNull);
  });

  test('sin temporizador no hay tiempo restante', () {
    expect(const LightsSettings(on: true).remaining(now), isNull);
  });

  test('reglas del temporizador', () {
    expect(LightsRules.isValidTimer(null), isTrue);
    expect(LightsRules.isValidTimer(1), isTrue);
    expect(LightsRules.isValidTimer(720), isTrue);
    expect(LightsRules.isValidTimer(0), isFalse);
    expect(LightsRules.isValidTimer(721), isFalse);
    expect(LightsRules.isValidLevel(101), isFalse);
  });
}
