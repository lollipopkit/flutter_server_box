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
import 'package:server_box/src/rust/api/storage.dart' as ffi;
import 'package:server_box/view/page/storage_admin/page.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/spi_fixture.dart';

const _sid = 'storage-page';

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
    if (script == ffi.storageViewScript()) {
      return const ExecResult(exitCode: 0, stdout: _view, stderr: '');
    }
    if (script == ffi.storageHealthScript()) {
      return const ExecResult(
        exitCode: 0,
        stdout: '### /dev/sda\n{"smartctl":{"exit_status":0},"device":{"type":"nvme"},"nvme_smart_health_information_log":{"temperature":32,"power_on_hours":12,"media_errors":0}}\n',
        stderr: '',
      );
    }
    return const ExecResult(exitCode: 0, stdout: '', stderr: '');
  }
}

const _view = '''
### lsblk
{"blockdevices":[
 {"name":"sda","path":"/dev/sda","type":"disk","size":500000000000,"model":"Test SSD","serial":"S1","rota":false,"tran":"nvme","rm":false,"ro":false,"fstype":null,"label":null,"uuid":null,"mountpoints":[null],"fsavail":null,"fsused":null,"children":[
  {"name":"sda1","path":"/dev/sda1","type":"part","size":500000000000,"fstype":"ext4","label":"root","uuid":"u1","mountpoints":["/"],"fsavail":"400000000000","fsused":"100000000000","rota":false,"rm":false,"ro":false}
 ]}
]}
### mdstat
### zpool
### zstatus
### tools
sfdisk
mkfs.ext4
smartctl
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

  testWidgets('shows the first disk view on a phone', (tester) async {
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
              return StoragePage(
                args: SpiRequiredArgs(spiFixture(id: _sid, name: 'nas')),
              );
            },
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('Disks').first, findsOneWidget);
    expect(find.textContaining('Test SSD'), findsOneWidget);
    expect(find.text('/dev/sda1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
