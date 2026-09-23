/// The permissions dialog, and when an update is allowed not to show one.
///
/// The rule under test is a security one, and both halves of it fail quietly:
/// asking on every update trains the user to tap through the one dialog whose
/// value is being read, and *not* asking when the new version added a
/// permission would let a plugin use something nobody agreed to. Neither shows
/// up as an error — what changes is which set is written to `granted`.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/plugin/l10n.dart';
import 'package:server_box/src/rust/api/plugin.dart' as ffi;
import 'package:server_box/view/widget/plugin/consent.dart';

ffi.PluginManifestInfo _manifest(
  List<String> permissions, {
  String name = 'Test',
  String description = 'A plugin.',
}) => ffi.PluginManifestInfo(
  id: 'app.serverbox.test',
  version: '1.1.0',
  abi: 2,
  dataVersion: 0,
  name: name,
  description: description,
  permissions: permissions,
);

void main() {
  /// A context under a `MaterialApp`, so the dialog has a root navigator to go
  /// on — which is the navigator `showRoundDialog` puts it on.
  ///
  /// Handed back rather than used inside `builder`: opening a dialog from a
  /// build is `setState() called during build`, and the test then fails on that
  /// instead of on what it is about.
  Future<BuildContext> mount(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );
    return ctx;
  }

  /// A manifest is one document for every language, so what it says a plugin
  /// is called may be a key. This dialog is where the name is read most
  /// carefully — it is the question — and it showed `l10n.pluginName` above a
  /// list of permissions in an interface that was otherwise translated.
  testWidgets('a plugin that names itself with a key is read, not shown', (
    tester,
  ) async {
    final answer = askPluginConsent(
      await mount(tester),
      _manifest(
        const ['server.exec'],
        name: 'l10n.pluginName',
        description: 'l10n.pluginDescription',
      ),
      strings: const PluginL10n(
        active: {'pluginName': '定时任务', 'pluginDescription': '按时间运行的任务。'},
        fallback: {'pluginName': 'Scheduled', 'pluginDescription': 'On a timer.'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('定时任务'), findsOneWidget);
    expect(find.text('按时间运行的任务。'), findsOneWidget);
    expect(find.textContaining('l10n.'), findsNothing);

    await tester.tap(find.text(libL10n.cancel));
    await tester.pumpAndSettle();
    await answer;
  });

  /// Every permission explains itself, or the ones with nothing under them read
  /// as the rows still missing something.
  testWidgets('each permission says what granting it means', (tester) async {
    final answer = askPluginConsent(
      await mount(tester),
      _manifest(const [
        'server.exec',
        'server.stream',
        'server.list',
        'net.http',
        'ui.dialog',
        'clipboard',
        'storage.sync',
      ]),
    );
    await tester.pumpAndSettle();

    for (final detail in [
      l10n.pluginRunsOnServer,
      l10n.permStreamTip,
      l10n.pluginSeesAllServersTip,
      l10n.permHttpTip,
      l10n.permDialogTip,
      l10n.permClipboardTip,
      l10n.permSyncTip,
    ]) {
      expect(find.text(detail), findsOneWidget, reason: detail);
    }

    await tester.tap(find.text(libL10n.cancel));
    await tester.pumpAndSettle();
    await answer;
  });

  group('a first install', () {
    testWidgets('asks, and answers what the manifest wants', (tester) async {
      final answer = askPluginConsent(
        await mount(tester),
        _manifest(['server.exec']),
      );
      await tester.pumpAndSettle();

      // Named in words rather than by its identifier, and with what granting
      // it means underneath: `server.exec` says nothing on its own, and the
      // row it sits in has no chevron because there is nowhere to go.
      expect(find.textContaining(l10n.permExec), findsOneWidget);
      expect(find.text(l10n.pluginRunsOnServer), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      await tester.tap(find.text(libL10n.ok));
      await tester.pumpAndSettle();

      expect(await answer, {'server.exec'});
    });

    testWidgets('cancelling grants nothing', (tester) async {
      final answer = askPluginConsent(
        await mount(tester),
        _manifest(['server.exec']),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(libL10n.cancel));
      await tester.pumpAndSettle();

      expect(await answer, isNull);
    });
  });

  group('an update', () {
    /// The common case, and the reason the rule exists: five plugins updating
    /// would be five dialogs describing permissions that have not moved.
    testWidgets('asking nothing new shows no dialog', (tester) async {
      final answer = await askPluginUpgradeConsent(
        await mount(tester),
        _manifest(['server.exec', 'ui.dialog']),
        granted: {'server.exec', 'ui.dialog'},
      );
      await tester.pumpAndSettle();

      expect(find.text(libL10n.ok), findsNothing);
      expect(answer, {'server.exec', 'ui.dialog'});
    });

    testWidgets('a permission the new version adds is asked for', (tester) async {
      final answer = askPluginUpgradeConsent(
        await mount(tester),
        _manifest(['server.exec', 'server.list']),
        granted: {'server.exec'},
      );
      await tester.pumpAndSettle();

      expect(find.text(libL10n.ok), findsOneWidget);
      await tester.tap(find.text(libL10n.ok));
      await tester.pumpAndSettle();

      expect(await answer, {'server.exec', 'server.list'});
    });

    testWidgets('refusing it leaves the update undone', (tester) async {
      final answer = askPluginUpgradeConsent(
        await mount(tester),
        _manifest(['server.exec', 'server.list']),
        granted: {'server.exec'},
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(libL10n.cancel));
      await tester.pumpAndSettle();

      // Null, not the old grant: the caller installs nothing rather than
      // installing the new version with the old permissions, which would be a
      // build running code the user has not seen the terms of.
      expect(await answer, isNull);
    });

    /// The case that decides whether the shortcut is safe. Last time the user
    /// said no to one of two, so the manifest is unchanged and the *grant* is
    /// short of it — which has to read as "there is something to ask about"
    /// rather than "nothing moved".
    testWidgets('a permission refused last time is asked again', (tester) async {
      final answer = askPluginUpgradeConsent(
        await mount(tester),
        _manifest(['server.exec', 'ui.dialog']),
        granted: {'server.exec'},
      );
      await tester.pumpAndSettle();

      expect(find.text(libL10n.ok), findsOneWidget);
      await tester.tap(find.text(libL10n.cancel));
      await tester.pumpAndSettle();
      expect(await answer, isNull);
    });

    /// A version that dropped a permission. Nothing to show — and the answer is
    /// the old grant, which `PluginInstaller.install` then intersects with the
    /// manifest, so the dropped one is not carried into the new record.
    testWidgets('a permission the new version dropped shows no dialog', (
      tester,
    ) async {
      final answer = await askPluginUpgradeConsent(
        await mount(tester),
        _manifest(['server.exec']),
        granted: {'server.exec', 'ui.dialog'},
      );
      await tester.pumpAndSettle();

      expect(find.text(libL10n.ok), findsNothing);
      expect(answer, {'server.exec', 'ui.dialog'});
    });

    testWidgets('a version that asks for nothing shows no dialog', (tester) async {
      final answer = await askPluginUpgradeConsent(
        await mount(tester),
        _manifest([]),
        granted: const {},
      );
      await tester.pumpAndSettle();

      expect(find.text(libL10n.ok), findsNothing);
      expect(answer, isEmpty);
    });
  });
}
