import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/res/build_data.dart';

/// That `BuildData.script` still counts the files the script is made of.
///
/// It counted `cmd_types.dart` from when the script was generated in Dart.
/// The generation moved to `crates/sbm_parser`, and the counter did not: for
/// the whole of that window, editing the script left the version alone and
/// editing an enum that changes no script byte bumped it. Nothing failed —
/// the version is only a file name — which is exactly why it went unnoticed.
///
/// So this does not check the number. It checks that the list `make.dart`
/// counts still covers what `script.rs` is built from, which is the property
/// that quietly stopped holding.
void main() {
  final make = File('make.dart').readAsStringSync();

  /// The paths `make.dart` runs `git log` over.
  Set<String> countedPaths() {
    final block = RegExp(
      r'const scriptSourcePaths = \[(.*?)\];',
      dotAll: true,
    ).firstMatch(make);
    expect(block, isNotNull, reason: 'make.dart no longer declares the list');
    return RegExp("'([^']+)'")
        .allMatches(block!.group(1)!)
        .map((m) => m.group(1)!)
        .toSet();
  }

  test('every file it counts is there to count', () {
    for (final path in countedPaths()) {
      expect(File(path).existsSync(), isTrue, reason: '$path is gone');
    }
  });

  test('and they are what the generator is built from', () {
    // `script.rs` writes the script; whatever it pulls in from the crate
    // decides its output with it. A new `use crate::<module>` is a new input,
    // and left uncounted it is a change to the script that the version cannot
    // see — the same way `commands.rs` was invisible before this list existed.
    const generator = 'crates/sbm_parser/src/script.rs';
    final source = File(generator).readAsStringSync();

    final modules = RegExp(r'use crate::([a-z_]+)(::|;)')
        .allMatches(source)
        .map((m) => 'crates/sbm_parser/src/${m.group(1)}.rs')
        .toSet();

    final counted = countedPaths();
    expect(
      counted,
      contains(generator),
      reason: 'the generator itself has to be counted',
    );
    expect(
      modules.difference(counted),
      isEmpty,
      reason: 'script.rs pulls these in and make.dart does not count them',
    );

    // `use crate::SystemType` is deliberately not here: it is a type at the
    // crate root, and a platform added to it has no script text of its own
    // until these files are given some.
  });

  test('the version reaches the file name and nothing else', () {
    // What the number is for. Two apps must not write different scripts under
    // one name; nothing else reads it, which is why a wrong value was never
    // a failure.
    expect(ScriptConstants.scriptFile, 'srvboxm_v${BuildData.script}.sh');
    expect(ScriptConstants.scriptFileWindows, 'srvboxm_v${BuildData.script}.ps1');
  });
}
