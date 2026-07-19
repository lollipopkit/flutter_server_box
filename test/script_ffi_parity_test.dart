// TRANSITIONAL test: byte-equality between the Dart script builders and the
// shared Rust implementation (sbm_parser::script) exposed over FFI.
// Deleted together with the Dart builders once the app switches to FFI.
// Requires: cargo build -p sbm_ffi

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/scripts/script_builders.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/src/rust/api/script.dart' as ffi;

import 'rust_lib_helper.dart';

void main() {
  setUpAll(() async {
    await initRustLibForTest();
  });

  const buildNumber = '${BuildData.build}';

  final customCmdCases = <Map<String, String>?>[
    null,
    {},
    {'custom_test': 'echo "Custom test command"', 'another_cmd': 'whoami'},
  ];

  final disabledCases = <List<String>?>[
    null,
    [],
    [
      StatusCmdType.net.displayName,
      BSDStatusCmdType.mem.displayName,
      WindowsStatusCmdType.temp.displayName,
    ],
  ];

  test('buildScript parity (unix + windows)', () {
    for (final customCmds in customCmdCases) {
      for (final disabled in disabledCases) {
        for (final (system, isWindows) in [('linux', false), ('windows', true)]) {
          final dart = ScriptBuilderFactory.getBuilder(isWindows)
              .buildScript(customCmds, disabled);
          final rust = ffi.buildScript(
            system: system,
            customCmds: [
              for (final e in (customCmds ?? {}).entries)
                ffi.CustomCmd(name: e.key, cmd: e.value),
            ],
            disabled: disabled ?? [],
            buildNumber: buildNumber,
          );
          expect(
            rust,
            dart,
            reason: 'system=$system custom=${customCmds?.keys} disabled=$disabled',
          );
        }
      }
    }
  });

  test('bsd system produces the unix script', () {
    final dart = ScriptBuilderFactory.getBuilder(false).buildScript(null);
    final rust = ffi.buildScript(
      system: 'bsd',
      customCmds: [],
      disabled: [],
      buildNumber: buildNumber,
    );
    expect(rust, dart);
  });

  test('installCommand parity', () {
    final unixDart = ScriptBuilderFactory.getBuilder(false)
        .getInstallCommand('/tmp/server_box', '/tmp/server_box/s.sh');
    final unixRust = ffi.installCommand(
      system: 'linux',
      scriptDir: '/tmp/server_box',
      scriptPath: '/tmp/server_box/s.sh',
    );
    expect(unixRust, unixDart);

    final winDart = ScriptBuilderFactory.getBuilder(true)
        .getInstallCommand(r'%TEMP%/server_box', r'%TEMP%/server_box\s.ps1');
    final winRust = ffi.installCommand(
      system: 'windows',
      scriptDir: r'%TEMP%/server_box',
      scriptPath: r'%TEMP%/server_box\s.ps1',
    );
    expect(winRust, winDart);
  });

  test('execCommand parity for all funcs', () {
    const kinds = {
      ShellFunc.status: ffi.ShellFuncKind.status,
      ShellFunc.process: ffi.ShellFuncKind.process,
      ShellFunc.shutdown: ffi.ShellFuncKind.shutdown,
      ShellFunc.reboot: ffi.ShellFuncKind.reboot,
      ShellFunc.suspend: ffi.ShellFuncKind.suspend,
    };
    for (final e in kinds.entries) {
      final unixDart = ScriptBuilderFactory.getBuilder(false)
          .getExecCommand('/tmp/s.sh', e.key);
      expect(
        ffi.execCommand(system: 'linux', scriptPath: '/tmp/s.sh', func: e.value),
        unixDart,
      );
      final winDart = ScriptBuilderFactory.getBuilder(true)
          .getExecCommand(r'C:\s.ps1', e.key);
      expect(
        ffi.execCommand(system: 'windows', scriptPath: r'C:\s.ps1', func: e.value),
        winDart,
      );
    }
  });

  test('parseScriptOutput parity', () async {
    const raw = 'SrvBoxSep.time\n123\nSrvBoxSep.mem\na\nb\n\nSrvBoxCusCmdSep.x\nhello\n';
    final dart = ScriptConstants.parseScriptOutput(raw);
    final rust = await ffi.parseScriptOutput(raw: raw);
    expect(rust, dart);
    expect(await ffi.parseScriptOutput(raw: ''), ScriptConstants.parseScriptOutput(''));
  });
}
