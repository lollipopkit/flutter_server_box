// ignore_for_file: invalid_use_of_protected_member

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
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
  ];
}

extension _Actions on _SchemaTooNewPageState {
  /// A path in the app's own documents directory.
  ///
  /// Named for the version that wrote it, since that is what a future reader
  /// has to match, and stamped so two attempts do not fight over one file.
  String _outPath(String suffix) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return Paths.doc.joinPath(
      'serverbox-rescue-v${widget.err.stored}-$stamp$suffix.db',
    );
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

  /// Writes the copy and hands it to the system share sheet.
  ///
  /// Shared rather than merely written, because a file inside the app's
  /// container is not somewhere the user can reach on iOS — and reaching it is
  /// the entire point of making it.
  Future<void> _export({required String? password, required String suffix}) async {
    setState(() => _busy = true);
    try {
      final path = _outPath(suffix);
      // Synchronous, and on the UI isolate: the database handle belongs to it,
      // and a rescue copy of a settings database is small enough that the
      // alternative is not worth the second connection.
      DbRescue.exportTo(path, password: password);
      await Pfs.sharePaths(paths: [path], title: libL10n.backup);
    } catch (e, s) {
      Loggers.app.warning('Rescue export failed', e, s);
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

  Future<void> _onWipe() async {
    final l10n = context.l10n;
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(l10n.schemaTooNewWipeConfirm),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await DbRescue.wipe();
      if (mounted) setState(() => _wiped = true);
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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The system's, since the stored preference is in the database this
      // cannot read.
      themeMode: ThemeMode.system,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: SchemaTooNewPage(err: err),
    );
  }
}
