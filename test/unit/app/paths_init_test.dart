/// `Paths` fields are `late final`, and `main.dart` initializes only the
/// directories it names in `Paths.init(dirs: ...)`. Reading any other one
/// throws `LateInitializationError` the first time a user reaches that code —
/// the theme store's preview did, with `Paths.cache`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib reads only the Paths directories main.dart initializes', () {
    final main = File('lib/main.dart').readAsStringSync();
    final dirs = RegExp(r'dirs:\s*const\s*\{([^}]*)\}').firstMatch(main);
    expect(dirs, isNotNull, reason: 'main.dart passes Paths.init a dirs set');
    final initialized = {
      for (final m in RegExp(r'PathDir\.(\w+)').allMatches(dirs!.group(1)!))
        m.group(1)!,
    };
    const optional = {'dl', 'audio', 'video', 'img', 'cache', 'font'};
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (final (i, line) in lines.indexed) {
        if (line.trimLeft().startsWith('//')) continue;
        for (final m in RegExp(r'\bPaths\.(\w+)\b').allMatches(line)) {
          final dir = m.group(1)!;
          if (optional.contains(dir) && !initialized.contains(dir)) {
            offenders.add('${f.path}:${i + 1} Paths.$dir');
          }
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
