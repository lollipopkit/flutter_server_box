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
import 'package:server_box/src/rust/api/plugin.dart' as ffi;
import 'package:server_box/view/widget/plugin/consent.dart';

ffi.PluginManifestInfo _manifest(List<String> permissions) =>
    ffi.PluginManifestInfo(
      id: 'app.serverbox.test',
      version: '1.1.0',
      abi: 2,
      name: 'Test',
      description: 'A plugin.',
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

  group('a first install', () {
    testWidgets('asks, and answers what the manifest wants', (tester) async {
      final answer = askPluginConsent(
        await mount(tester),
        _manifest(['server.exec']),
      );
      await tester.pumpAndSettle();

      // The permission is named, and the sentence that says what it means is
      // there too — `server.exec` is a name, and the warning is the meaning.
      expect(find.text(libL10n.cmd), findsOneWidget);
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
