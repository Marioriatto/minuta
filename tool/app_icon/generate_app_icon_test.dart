// Genera el ícono de la app (Android) a partir del ícono de bebé que usa la UI
// (`Icons.child_care_rounded`), en blanco sobre el color primario.
//
// No forma parte de la suite: se ejecuta a mano cuando cambie el diseño.
//   flutter test tool/app_icon/generate_app_icon_test.dart \
//     --dart-define=FLUTTER_ROOT=<ruta del SDK de Flutter>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:colchon_minuta/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _icon = Icons.child_care_rounded;
const _res = 'android/app/src/main/res';

/// Densidades de Android: (carpeta, factor respecto a mdpi).
const _densities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

Future<void> _loadMaterialIcons() async {
  const root = String.fromEnvironment('FLUTTER_ROOT');
  if (root.isEmpty) {
    throw StateError('Falta --dart-define=FLUTTER_ROOT=<ruta del SDK>');
  }
  final font = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
  await loader.load();
}

/// Dibuja el glifo centrado ocupando [glyphFraction] del lado.
void _paintGlyph(Canvas canvas, double side, double glyphFraction) {
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(_icon.codePoint),
      style: TextStyle(
        fontFamily: _icon.fontFamily,
        package: _icon.fontPackage,
        fontSize: side * glyphFraction,
        color: Colors.white,
        height: 1,
      ),
    ),
  )..layout();
  painter.paint(
    canvas,
    Offset((side - painter.width) / 2, (side - painter.height) / 2),
  );
}

Future<void> _writePng(
  String path,
  int side,
  void Function(Canvas canvas, double side) draw,
) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder), side.toDouble());
  final image = await recorder.endRecording().toImage(side, side);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('genera los íconos de Android', (tester) async {
    await tester.runAsync(() async {
      await _loadMaterialIcons();

      for (final MapEntry(key: density, value: scale) in _densities.entries) {
        // Ícono clásico (Android < 8): círculo azul con el bebé.
        await _writePng(
          '$_res/mipmap-$density/ic_launcher.png',
          (48 * scale).round(),
          (canvas, side) {
            canvas.drawCircle(
              Offset(side / 2, side / 2),
              side / 2,
              Paint()..color = DesignTokens.primary,
            );
            _paintGlyph(canvas, side, 0.62);
          },
        );
        // Ícono adaptable (Android 8+): solo el bebé, dentro de la zona
        // segura (66 de 108 dp); el fondo es un color.
        await _writePng(
          '$_res/mipmap-$density/ic_launcher_foreground.png',
          (108 * scale).round(),
          (canvas, side) => _paintGlyph(canvas, side, 0.5),
        );
      }
    });
  });
}
