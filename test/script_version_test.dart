import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/res/build_data.dart';

/// `fl_build` gets this value from `make.dart`, while a direct Flutter build
/// uses the committed `BuildData`. They must name the same remote script.
void main() {
  final make = File('make.dart').readAsStringSync();

  test('the build hook and committed build data agree', () {
    final match = RegExp(
      r'const scriptVersion = (\d+);',
    ).firstMatch(make);
    expect(match, isNotNull, reason: 'make.dart must declare scriptVersion');
    expect(int.parse(match!.group(1)!), BuildData.script);
  });

  test('the version reaches the file name and nothing else', () {
    // What the number is for. Two apps must not write different scripts under
    // one name; nothing else reads it, which is why a wrong value was never
    // a failure.
    expect(ScriptConstants.scriptFile, 'srvboxm_v${BuildData.script}.sh');
    expect(ScriptConstants.scriptFileWindows, 'srvboxm_v${BuildData.script}.ps1');
  });
}
