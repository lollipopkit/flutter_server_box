/// The status script run on the machine running the tests, the way a server
/// that is this device reads it: installed and executed through
/// [LocalServer.exec], parsed by the same [ScriptDataSource] the SSH path uses.
///
/// Needs `cargo build -p sbm_ffi` first, and skipped where
/// [LocalServer.isSupported] is false.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/local_server.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/script_source.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/src/rust/api/script.dart' as ffi;

import '../helpers/rust_lib_helper.dart';

void main() {
  setUpAll(initRustLibForTest);

  test(
    'installs, runs and parses on this device',
    () async {
      final dir = await Directory.systemTemp.createTemp('sbm_local_');
      addTearDown(() => dir.delete(recursive: true));
      final scriptDir = dir.path.replaceAll(r'\', '/');
      const id = 'local-test';
      final system = LocalServer.systemType;
      final exec = LocalServer.exec();

      final install = await exec.run(
        ShellFuncManager.installPayload(
          ShellFuncManager.allScript(systemType: system),
          systemType: system,
        ),
        entry: ShellFuncManager.getInstallShellCmd(
          id,
          systemType: system,
          customDir: scriptDir,
        ),
      );
      expect(install.succeeded, isTrue, reason: install.combined);

      final result = await exec.run(
        ShellFunc.status.exec(id, systemType: system, customDir: scriptDir),
      );
      expect(
        ffi.containsScriptSegment(raw: result.stdout),
        isTrue,
        reason: result.combined,
      );

      final spi = Spi(name: 'me', id: id, local: true);
      // What `_getDataLocal` sets before the first read: the parser takes the
      // platform from the status it is handed.
      final into = InitStatus.status..system = system;
      final status = await ScriptDataSource(
        spi: spi,
        runScript: () async => result.stdout,
      ).fetchStatus(into);
      expect(status.system, system);
      expect(status.mem.total, greaterThan(1));
      expect(status.disk, isNotEmpty);
    },
    skip: LocalServer.isSupported ? false : 'no local processes here',
  );
}
