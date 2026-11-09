import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hace cumplir la arquitectura por capas dentro de lib/features/<feature>/.
/// - domain: Dart puro (sin Flutter, Supabase, Riverpod ni data/presentation).
/// - presentation: no importa data ni Supabase.
/// - data: no importa presentation.
final _import = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''', multiLine: true);

List<String> _imports(File f) =>
    _import.allMatches(f.readAsStringSync()).map((m) => m.group(1)!).toList();

Iterable<File> _dartFiles(String layer) {
  final root = Directory('lib/features');
  if (!root.existsSync()) return const [];
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => f.path.replaceAll(r'\', '/').contains('/$layer/'));
}

void _expectNone(String layer, List<String> forbidden) {
  for (final file in _dartFiles(layer)) {
    for (final imp in _imports(file)) {
      for (final bad in forbidden) {
        expect(
          imp.contains(bad),
          isFalse,
          reason: '${file.path} (capa $layer) no puede importar "$imp"',
        );
      }
    }
  }
}

void main() {
  test('domain es Dart puro', () {
    _expectNone('domain', [
      'package:flutter/',
      'package:flutter_riverpod',
      'package:supabase',
      '/data/',
      '/presentation/',
    ]);
  });

  test('presentation no accede a data ni a Supabase', () {
    _expectNone('presentation', ['/data/', 'package:supabase']);
  });

  test('data no depende de presentation', () {
    _expectNone('data', ['/presentation/']);
  });
}
