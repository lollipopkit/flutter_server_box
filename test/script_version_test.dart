import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';

/// What the number is for. Two apps must not write different scripts under one
/// name; nothing else reads it, which is why a wrong value was never a failure
/// anywhere it would be noticed.
void main() {
  test('the version reaches the file name and nothing else', () {
    expect(
      ScriptConstants.scriptFile,
      'srvboxm_v${ScriptConstants.version}.sh',
    );
    expect(
      ScriptConstants.scriptFileWindows,
      'srvboxm_v${ScriptConstants.version}.ps1',
    );
  });
}
