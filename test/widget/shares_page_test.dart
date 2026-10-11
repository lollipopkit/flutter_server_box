import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/src/rust/api/shares.dart' as shares_ffi;
import 'package:server_box/src/rust/api/storage.dart' as storage_ffi;
import 'package:server_box/src/rust/api/users.dart' as users_ffi;
import 'package:server_box/view/page/shares/page.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/spi_fixture.dart';

const _sid = 'shares-page';

final class _FakeExec implements ServerExec {
  @override
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
    Future<void>? cancel,
  }) async {
    if (script == shares_ffi.sharesReadScript()) {
      return const ExecResult(exitCode: 0, stdout: _read, stderr: '');
    }
    if (script == users_ffi.usersListScript()) {
      return const ExecResult(
        exitCode: 0,
        stdout: 'SrvBoxUsers.Current\troot\nSrvBoxUsers.UidMin\t1000\nSrvBoxUsers.Passwd\nroot:x:0:0:root:/root:/bin/bash\nSrvBoxUsers.Group\n',
        stderr: '',
      );
    }
    if (script == storage_ffi.storageViewScript()) {
      return const ExecResult(
        exitCode: 0,
        stdout: '### lsblk\n{"blockdevices":[]}\n### mdstat\n### zpool\n### zstatus\n### tools\n',
        stderr: '',
      );
    }
    if (script == shares_ffi.sharesConnectionsScript()) {
      return const ExecResult(exitCode: 0, stdout: '### smb\n### nfs\n', stderr: '');
    }
    return const ExecResult(exitCode: 0, stdout: '', stderr: '');
  }
}

const _read = '''
### tools
smbd
testparm
smbpasswd
exportfs
### active
smbd
### smb
[media]
 path = /srv/media
 read only = no
 guest ok = yes
### smbManaged
[media]
 path = /srv/media
### nfs
/srv/other *(ro,sync,root_squash)
### nfsManaged
"/srv/managed" 192.168.1.0/24(rw,sync,no_subtree_check,root_squash)
''';

final class _FakeServerNotifier extends ServerNotifier {
  @override
  ServerState build(String id) =>
      ServerState(spi: spiFixture(id: id, name: 'nas'), status: InitStatus.status);

  @override
  Future<ServerExec> ensureExec({VoidCallback? onSshDial}) async => _FakeExec();
}

void main() {
  setUpAll(initRustLibForTest);

  testWidgets('shows the first sharing view with managed and external shares', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [serverProvider(_sid).overrideWith(_FakeServerNotifier.new)],
        child: MaterialApp(
          localizationsDelegates: const [
            ...app_locale.appLocalizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return SharesPage(
                args: SpiRequiredArgs(spiFixture(id: _sid, name: 'nas')),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('SMB'), findsOneWidget);
    expect(find.text('media'), findsOneWidget);
    expect(find.text('/srv/media'), findsOneWidget);
    expect(find.text('Set up outside ServerBox'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
