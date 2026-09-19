/// The crontab page, drawn from a listing rather than from a server.
///
/// What it is for is the two layouts: a task is one line on a desktop and a
/// stacked card on a phone, and both draw a schedule, a command and a next run
/// in a row that has to fit. An overflow here is a red banner over the list,
/// which is why every case ends by asking the tester for an exception.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/service/cron_manager.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/scheduled_tasks.dart';

import '../helpers/spi_fixture.dart';

const _sid = 'cron-1';

/// A crontab with something of every kind in it: a task under a macro, one
/// this app disabled, and lines it does not manage.
const _crontab = '''
# managed by hk-ops
SHELL=/bin/bash
*/5 * * * * /opt/hk/bin/healthcheck.sh
0 2 * * * /usr/bin/rsync -a --delete /srv/www /mnt/backup/www
@reboot /opt/hk/bin/warmcache --quiet
# ServerBox disabled: 15 3 * * 1-5 /opt/hk/bin/report.py --weekly-digest
''';

/// The account the listing reports, which the toolbar draws as it comes.
var _listUser = 'lk';

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
    if (script == CronManager.listScript) {
      return ExecResult(
        exitCode: 0,
        stdout:
            'SrvBoxCron.User\t$_listUser\n'
            'SrvBoxCron.Clock\t1772000000 +0800\n'
            'SrvBoxCron.Body\n$_crontab',
        stderr: '',
      );
    }
    return const ExecResult(exitCode: 0, stdout: '', stderr: '');
  }
}

final class _FakeServerNotifier extends ServerNotifier {
  @override
  ServerState build(String id) =>
      ServerState(spi: spiFixture(id: id, name: 'hk'), status: InitStatus.status);

  @override
  Future<ServerExec> ensureExec({VoidCallback? onSshDial}) async => _FakeExec();
}

void main() {
  final page = ScheduledTasksPage(
    args: SpiRequiredArgs(spiFixture(id: _sid, name: 'hk')),
  );

  Future<void> pump(WidgetTester tester, {required Size size}) async {
    // The view, not `setSurfaceSize`: which layout runs is a `MediaQuery`
    // question, and `setSurfaceSize` changes layout without changing what
    // `MediaQuery` reports.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverProvider(_sid).overrideWith(_FakeServerNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return page;
            },
          ),
        ),
      ),
    );
    // Never `pumpAndSettle`: the page holds a clock that keeps "in 4 minutes"
    // true, so nothing ever settles.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Takes the page down inside the body: the binding checks for pending
  /// timers before `addTearDown` callbacks run, and the page's clock is
  /// cancelled on dispose.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('phone: enabled and disabled are two lists, and add floats', (
    tester,
  ) async {
    await pump(tester, size: const Size(393, 852));

    expect(tester.takeException(), isNull);
    expect(find.text('ENABLED · 3'), findsOneWidget);
    expect(find.text('DISABLED · 1'), findsOneWidget);
    // A schedule is read out, and the expression stays beside it.
    expect(find.text('Every 5 minutes'), findsOneWidget);
    expect(find.text('At boot'), findsOneWidget);
    expect(find.text('*/5 * * * *'), findsOneWidget);
    // A disabled task says why it will not run.
    expect(find.text('Commented out'), findsOneWidget);
    // What the page does not manage is kept, and says how much of it there is.
    expect(find.text('Preserved lines'), findsOneWidget);
    expect(find.textContaining('2 · '), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    // The filter is a desktop affordance; a phone has the list and no room.
    expect(find.text('Filter tasks'), findsNothing);

    await close(tester);
  });

  testWidgets('phone: the editor is a sheet, and the file is readable raw', (
    tester,
  ) async {
    await pump(tester, size: const Size(393, 852));

    await tester.tap(find.byType(FloatingActionButton));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Enable now'), findsOneWidget);
    // Five fields side by side on a 393pt screen, each still saying which it
    // is — the row that has the least room to be right.
    expect(find.text('Day of month'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, libL10n.cancel));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Enable now'), findsNothing);

    await tester.tap(find.byTooltip('Raw crontab'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    // Every line, including the ones the list does not manage.
    expect(find.textContaining('SHELL=/bin/bash'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, libL10n.ok));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await close(tester);
  });

  testWidgets('desktop: the toolbar carries the filter and the add button', (
    tester,
  ) async {
    await pump(tester, size: const Size(1100, 800));

    expect(tester.takeException(), isNull);
    expect(find.text('Filter tasks'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add task'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('4 tasks · 3 enabled'), findsOneWidget);
    // The next run is the one thing a crontab does not say for itself.
    expect(find.text('Next run'), findsOneWidget);

    await close(tester);
  });

  /// The account is whatever `id -un` said and the summary is as long as the
  /// language makes it, and the toolbar has to hold both at any width.
  for (final size in const [Size(360, 780), Size(760, 800)]) {
    testWidgets('a long account name fits the toolbar at ${size.width}', (
      tester,
    ) async {
      _listUser = 'deployment-service-account-with-a-long-name';
      addTearDown(() => _listUser = 'lk');

      await pump(tester, size: size);

      expect(tester.takeException(), isNull);
      expect(
        find.byType(FilledButton),
        size.width >= 720 ? findsOneWidget : findsNothing,
      );

      await close(tester);
    });
  }

  testWidgets('filtering narrows the list to what matches', (tester) async {
    await pump(tester, size: const Size(1100, 800));

    await tester.enterText(find.byType(TextField).first, 'rsync');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Every day at 02:00'), findsOneWidget);
    expect(find.text('Every 5 minutes'), findsNothing);
    // A filter narrows the page to tasks: the banner would name one the
    // filter has just taken off the page, and the preserved lines answer a
    // question nobody asked.
    expect(find.text('Next run'), findsNothing);
    expect(find.text('Preserved lines'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'nothing matches');
    await tester.pump();
    expect(find.text(libL10n.empty), findsOneWidget);

    await close(tester);
  });

  testWidgets('desktop: the editor is the same sheet, not a dialog', (
    tester,
  ) async {
    await pump(tester, size: const Size(1100, 800));

    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.text('Enable now'), findsOneWidget);
    // One form at every width. A dialog here gave the fields a surface the
    // same colour as themselves, and made the same form two things.
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    // Five fields, each labelled by which one it is.
    expect(find.text('Day of month'), findsOneWidget);
    expect(find.text('Day of week'), findsOneWidget);
    // The preview says what the fields add up to, before anything is saved.
    expect(find.text('Every day at 02:00'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, libL10n.cancel));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Enable now'), findsNothing);

    await close(tester);
  });
}
