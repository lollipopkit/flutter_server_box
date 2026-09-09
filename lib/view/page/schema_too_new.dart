// ignore_for_file: invalid_use_of_protected_member

import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/db_rescue.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/generated/l10n/l10n.dart';

/// The whole app, when the stored data was written by a newer build.
///
/// `SchemaVersion.migrate` refuses that data — see [SchemaTooNewException] for
/// why — and the refusal used to happen inside `_initApp`, before `runApp`. The
/// zone handler logged it and the launch simply stopped: no window, no message,
/// nothing on screen at all. From the outside that is indistinguishable from a
/// crash, and the one thing the user needed to know — *their data is intact,
/// reinstall the newer build* — was in a file on the device.
///
/// So this replaces the app for that launch. It states the versions, says the
/// data has not been touched, and offers the two things somebody who cannot go
/// back to the newer build actually needs: a copy of the data, and a way to
/// start over.
///
/// Deliberately thin. It runs on a half-initialised app — the database is open
/// because `Stores.init` succeeded, and nothing after `_doDbMigrate` ran — so it
/// touches the database only through [DbRescue] and reads no store, no provider
/// and no setting.
class SchemaTooNewPage extends StatefulWidget {
  const SchemaTooNewPage({super.key, required this.err});

  final SchemaTooNewException err;

  /// Stands in for the share sheet in tests.
  ///
  /// `Pfs.sharePaths` *reveals* the file on desktop — `Process.run('open',
  /// ['--reveal', ...])` — so a suite run on a developer's machine pops a
  /// Finder window per test, and on Linux CI spawns something that may not
  /// exist. It is also the only moment the copy exists: the directory holding
  /// it is temporary and goes as soon as the share returns, so a test that
  /// wants to look at the file has to look from here. Nothing in a shipped
  /// build assigns this.
  @visibleForTesting
  static Future<void> Function(String path)? shareForTest;

  @override
  State<SchemaTooNewPage> createState() => _SchemaTooNewPageState();
}

class _SchemaTooNewPageState extends State<SchemaTooNewPage> {
  /// True once the database has been deleted, which makes every other control
  /// here meaningless — there is nothing left to export.
  bool _wiped = false;

  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 37),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _wiped
                    ? _doneBody(l10n)
                    : _explainBody(l10n),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _explainBody(AppLocalizations l10n) => [
    Icon(
      Icons.history_toggle_off,
      size: 57,
      color: Theme.of(context).colorScheme.error,
    ),
    UIs.height13,
    Text(
      l10n.schemaTooNewTitle,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      textAlign: TextAlign.center,
    ),
    UIs.height13,
    Text(
      l10n.schemaTooNewBody(widget.err.stored, widget.err.supported),
      style: UIs.textGrey,
      textAlign: TextAlign.center,
    ),
    UIs.height13,
    // The way out that costs nothing, stated first and as the plain answer.
    // Everything under it is for somebody who cannot take it.
    Text(
      l10n.schemaTooNewReinstall,
      textAlign: TextAlign.center,
    ),
    UIs.height13,
    const Divider(),
    UIs.height13,
    // The copy is off the UI isolate so this can actually turn. Without it the
    // screen is three greyed-out buttons and no motion for however long tens of
    // megabytes take, which reads as the app having hung — the thing the
    // isolate was added to prevent.
    if (_busy) ...[
      const LinearProgressIndicator(),
      UIs.height13,
    ],
    FilledButton.icon(
      onPressed: _busy ? null : _onExportEncrypted,
      icon: const Icon(Icons.lock_outline),
      label: Text(libL10n.backup),
    ),
    UIs.height7,
    TextButton.icon(
      onPressed: _busy ? null : _onExportPlain,
      icon: const Icon(Icons.lock_open, size: 18),
      label: Text(l10n.schemaTooNewExportPlain),
    ),
    UIs.height13,
    TextButton.icon(
      onPressed: _busy ? null : _onWipe,
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
      icon: const Icon(Icons.delete_outline, size: 18),
      label: Text(l10n.schemaTooNewWipe),
    ),
  ];

  List<Widget> _doneBody(AppLocalizations l10n) => [
    const Icon(Icons.check_circle_outline, size: 57),
    UIs.height13,
    Text(
      l10n.schemaTooNewWipeDone,
      style: const TextStyle(fontSize: 17),
      textAlign: TextAlign.center,
    ),
    UIs.height13,
    // A button, not just the sentence above it. Reopening from the icon or the
    // dock resumes this same process and shows this same dead screen; the
    // database is closed, so nothing here can do anything either, and only a
    // force-quit actually helps. Saying so without offering it leaves the user
    // stuck on a screen that has told them what to do and cannot let them.
    FilledButton.icon(
      onPressed: _busy ? null : _onQuit,
      icon: const Icon(Icons.power_settings_new),
      label: Text(libL10n.exit),
    ),
  ];
}

extension _Actions on _SchemaTooNewPageState {
  /// The copy's name, which is all this decides — the directory is a temporary
  /// one made per export.
  ///
  /// Named for the version that wrote the data, since that is what a future
  /// reader has to match it against.
  String _outName(String suffix) =>
      'serverbox-rescue-v${widget.err.stored}$suffix.db';

  Future<void> _onExportEncrypted() async {
    final pwd = await context.showPwdDialog(title: libL10n.pwd);
    if (pwd == null || pwd.isEmpty) return;
    await _export(password: pwd, suffix: '');
  }

  Future<void> _onExportPlain() async {
    final l10n = context.l10n;
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(l10n.schemaTooNewPlainWarn),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true) return;
    await _export(password: null, suffix: '-plain');
  }

  /// Writes the copy and hands it to the system share sheet.
  ///
  /// Shared rather than merely written, because a file inside the app's
  /// container is not somewhere the user can reach on iOS — and reaching it is
  /// the entire point of making it.
  Future<void> _export({required String? password, required String suffix}) async {
    setState(() => _busy = true);
    // A temp directory, not `Paths.doc`, and removed afterwards. `sharePaths`
    // *reveals* the file on desktop rather than sending it, so writing it
    // beside `store.db` points the user's file manager straight at the app's
    // private data — and this file is the entire database, unencrypted on the
    // plain path. `server_share.dart` learned the same thing about a single
    // encrypted server record.
    // Sync, and symmetric with the sync delete in `finally`. Also what keeps
    // this reachable from a `testWidgets` body: real async file I/O started in
    // that fake-async zone completes on a callback the zone never pumps.
    final dir = Directory.systemTemp.createTempSync('sbx-rescue-');
    try {
      final path = dir.path.joinPath(_outName(suffix));
      // Awaited: it runs on its own isolate, so the page keeps drawing.
      await DbRescue.exportTo(path, password: password);
      final share = SchemaTooNewPage.shareForTest;
      if (share != null) {
        await share(path);
      } else {
        await Pfs.sharePaths(paths: [path], title: libL10n.backup);
      }
    } catch (e, s) {
      Loggers.app.warning('Rescue export failed', e, s);
      if (mounted) {
        await context.showRoundDialog(
          title: libL10n.fail,
          child: Text('$e'),
        );
      }
    } finally {
      // Once the sheet has been answered. On iOS the share is a copy, so
      // nothing downstream still needs this; on desktop the reveal has already
      // happened and a window pointing at a directory that is about to go is
      // the price of not leaving the database in one.
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Ends the process, which is the only thing left that helps.
  ///
  /// `SystemNavigator.pop` is the polite form and does nothing on desktop, so
  /// that falls through to `exit`. Not something to reach for anywhere else —
  /// here the alternative is a screen the user cannot leave.
  Future<void> _onQuit() async {
    await SystemNavigator.pop();
    if (isDesktop) exit(0);
  }

  Future<void> _onWipe() async {
    final l10n = context.l10n;
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(l10n.schemaTooNewWipeConfirm),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true) return;

    // Before the call, not after it: `wipe` closes the connection first and
    // deletes second, so a delete that fails leaves the database shut with the
    // export buttons still on screen. Tapping one then reports "the database is
    // not open", which is both true and useless — and it was the user's last
    // chance to get the data out.
    setState(() {
      _busy = true;
      _wiped = true;
    });
    try {
      await DbRescue.wipe();
    } catch (e, s) {
      Loggers.app.warning('Rescue wipe failed', e, s);
      if (mounted) {
        await context.showRoundDialog(
          title: libL10n.fail,
          child: Text('$e'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// What `main` runs instead of the app.
///
/// Its own `MaterialApp` because `MyApp` reads settings out of a database this
/// build has just refused to touch.
class SchemaTooNewApp extends StatelessWidget {
  const SchemaTooNewApp({super.key, required this.err});

  final SchemaTooNewException err;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // `LibLocalizations.delegate` first, exactly as `MyApp` does it:
      // `AppLocalizations.localizationsDelegates` does not include it, and
      // without it every `libL10n.*` string here — the Backup button, both
      // dialog titles, the password label, OK and Cancel — stays English while
      // this page's own text is translated.
      localizationsDelegates: const [
        LibLocalizations.delegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: LocaleUtil.resolve,
      // The system's, since the stored preference is in the database this
      // cannot read.
      themeMode: ThemeMode.system,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      // The other half of it: `libL10n` is a global that only this call
      // replaces, and `MyApp` makes it from its own home builder.
      home: Builder(
        builder: (context) {
          context.setLibL10n();
          return SchemaTooNewPage(err: err);
        },
      ),
    );
  }
}
