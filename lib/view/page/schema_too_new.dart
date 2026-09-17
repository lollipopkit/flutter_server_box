// ignore_for_file: invalid_use_of_protected_member

import 'dart:io';

import 'package:file_picker/file_picker.dart';
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

  @override
  State<SchemaTooNewPage> createState() => _SchemaTooNewPageState();
}

class _SchemaTooNewPageState extends State<SchemaTooNewPage> {
  /// True once the wipe has been *attempted*, which is what makes the export
  /// controls meaningless: `DbRescue.wipe` closes the connection before it
  /// deletes anything, so there is nothing left to read either way.
  bool _wipeStarted = false;

  /// True once it also succeeded.
  ///
  /// Separate from [_wipeStarted] because the two answers differ, and the
  /// difference is the whole message: a delete that failed leaves a database on
  /// disk that this build still cannot open. Telling that user their data is
  /// gone is wrong in both directions — it is not gone, and the app is not
  /// usable.
  bool _wipedOk = false;

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
                children: _wipeStarted
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
    Icon(
      _wipedOk ? Icons.check_circle_outline : Icons.error_outline,
      size: 57,
      color: _wipedOk ? null : Theme.of(context).colorScheme.error,
    ),
    UIs.height13,
    Text(
      _wipedOk ? l10n.schemaTooNewWipeDone : l10n.schemaTooNewWipeFailed,
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
  /// The copy's name.
  ///
  /// Named for the version that wrote the data, since that is what a future
  /// reader has to match it against, and for when it was made, so a second
  /// export into the same directory sits beside the first.
  String _outName(String suffix) {
    final at = DateTime.now().ymdhms(ymdSep: '', hmsSep: '', sep: '-');
    return 'serverbox-rescue-v${widget.err.stored}-$at$suffix.db';
  }

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

  /// Writes the copy and hands it to the user: into a directory they pick on
  /// desktop, through the share sheet on mobile.
  ///
  /// Handed over rather than merely written, because a file inside the app's
  /// container is not somewhere the user can reach on iOS — and reaching it is
  /// the entire point of making it.
  Future<void> _export({required String? password, required String suffix}) async {
    // Asked before the export, so a cancel costs nothing and no copy of the
    // database exists while the picker is open.
    //
    // Not `Pfs.sharePaths`, which on desktop only *reveals* the file and
    // returns at once, so removing the temp copy afterwards left the file
    // manager opening on a file that was already gone.
    //
    // Not a save panel either: file_picker_darwin sets the panel's content
    // type after its file name, and for an extension no app has registered —
    // `db` is one — macOS then appends it a second time and saves `.db.db`.
    final String? destDir;
    if (isDesktop) {
      destDir = await FilePicker.getDirectoryPath(dialogTitle: libL10n.backup);
      if (destDir == null || !mounted) return;
    } else {
      destDir = null;
    }

    setState(() => _busy = true);
    String? savedTo;
    Object? error;
    // A temp directory, not `Paths.doc`, and removed on every platform: this
    // file is the entire database, unencrypted on the plain path, and the only
    // copy that should outlive this call is the one the user put somewhere.
    // Sync, and symmetric with the sync delete in `finally`. Also what keeps
    // this reachable from a `testWidgets` body: real async file I/O started in
    // that fake-async zone completes on a callback the zone never pumps.
    final dir = Directory.systemTemp.createTempSync('sbx-rescue-');
    try {
      final name = _outName(suffix);
      final path = dir.path.joinPath(name);
      // Awaited: it runs on its own isolate, so the page keeps drawing.
      await DbRescue.exportTo(path, password: password);
      if (destDir == null) {
        await Pfs.sharePaths(paths: [path], title: libL10n.backup);
      } else {
        savedTo = _copyInto(path, destDir, name);
      }
    } catch (e, s) {
      Loggers.app.warning('Rescue export failed', e, s);
      error = e;
    } finally {
      // Before either dialog below, which waits on the user: the sheet or the
      // copy has taken what it needs, and the database should not sit in the
      // temp directory for as long as a dialog stays open.
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      if (mounted) setState(() => _busy = false);
    }

    if (!mounted) return;
    if (error != null) {
      await context.showRoundDialog(
        title: libL10n.fail,
        child: Text('$error'),
        actions: Btnx.oks,
      );
    } else if (savedTo != null) {
      // Nothing else on this screen changes once the copy has landed, and there
      // is no toast host in this app to say so. The path is the answer to
      // "where did it go".
      await context.showRoundDialog(
        title: libL10n.success,
        child: SelectableText(savedTo),
        actions: Btnx.oks,
      );
    }
  }

  /// Copies [src] into [destDir] as [name], and answers the path it took.
  ///
  /// Never over an existing file. The name carries the second it was made, but
  /// two exports in one second, or a clock set back, would otherwise replace a
  /// backup the user already has — with a copy of the same data at best.
  ///
  /// Sync for the reason the temp directory is. Copying a finished file is
  /// plain I/O, milliseconds even at tens of megabytes; reading and
  /// re-encrypting every table is the part that needed its own isolate.
  String _copyInto(String src, String destDir, String name) {
    final stem = name.substring(0, name.length - '.db'.length);
    var dest = destDir.joinPath(name);
    for (var n = 2; File(dest).existsSync(); n++) {
      dest = destDir.joinPath('$stem-$n.db');
    }
    try {
      File(src).copySync(dest);
    } catch (_) {
      // Half a database in the user's directory looks like a backup. The path
      // was free a moment ago, so what is there now is this attempt's.
      final partial = File(dest);
      if (partial.existsSync()) partial.deleteSync();
      rethrow;
    }
    return dest;
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
      _wipeStarted = true;
    });
    try {
      await DbRescue.wipe();
      if (mounted) setState(() => _wipedOk = true);
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
