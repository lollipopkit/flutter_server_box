import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/inset.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/lkc.dart';
import 'package:server_box/core/sync/category.dart';
import 'package:server_box/core/sync/failure.dart';
import 'package:server_box/core/sync/file_log.dart';
import 'package:server_box/core/sync/key.dart';
import 'package:server_box/core/sync/lkc_log.dart';
import 'package:server_box/core/sync/lkc_prefs.dart';
import 'package:server_box/core/sync/log.dart';
import 'package:server_box/core/sync/remotes.dart';
import 'package:server_box/core/sync/sync.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/backup_reader.dart';
import 'package:server_box/data/model/app/bak/backup_service.dart';
import 'package:server_box/data/model/app/bak/backup_source.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/view/page/server/widget/server_share.dart';

part 'backup/sync.dart';

/// Which half of the page to show.
///
/// The two halves answer different questions — "keep this somewhere else" and
/// "bring something in" — and only ever shared a page because both are about
/// moving data. The settings menu lists them as two rows, so each opens on its
/// own.
enum BackupSection { sync, import }

class BackupPage extends ConsumerStatefulWidget {
  /// Null shows both, side by side, under one heading each.
  ///
  /// That is the standalone [route], which the DMG notice opens directly: there
  /// is no menu around it to say which half you are looking at, so it says so
  /// itself. Inside the settings page the row that opened it already has.
  final BackupSection? section;

  const BackupPage({super.key, this.section});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();

  static const route = AppRouteNoArg(page: BackupPage.new, path: '/backup');
}

final class _BackupPageState extends ConsumerState<BackupPage>
    with AutomaticKeepAliveClientMixin {
  /// A restore from or a backup to the remote (WebDAV, iCloud) running.
  final remoteLoading = false.vn;
  final lkcLoading = false.vn;

  /// A sync started here running.
  final _syncing = false.vn;

  /// The WebDAV settings saved here, which name the server shown.
  final _webdavEdited = 0.vn;
  late Future<_ICloudBackupStatus?> _icloudStatusFuture;

  @override
  void initState() {
    super.initState();
    _icloudStatusFuture = Future.value(null);
    if (isICloudSupported) {
      _refreshIcloudStatus(notify: false);
    }
  }

  @override
  void dispose() {
    remoteLoading.dispose();
    lkcLoading.dispose();
    _syncing.dispose();
    _webdavEdited.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final section = widget.section;
    if (section == null) {
      return Scaffold(
        appBar: CustomAppBar(title: Text(libL10n.backup)),
        body: SafeArea(child: _buildBody),
      );
    }

    // Shown in the settings content pane, which brings the Scaffold and the
    // bar. No heading either, for the reason [AppSettingsPage] gives: the menu
    // names the group and the bar repeats it, so a third would be one too many.
    if (section == BackupSection.sync) return _buildSyncSection;
    return ListView(
      padding: context.padBottom(UIs.roundRectCardPadding),
      children: switch (section) {
        BackupSection.sync || BackupSection.import => _importTiles,
      },
    );
  }

  List<Widget> get _importTiles => [
    _buildImportSharedServer,
    _buildBulkImportServers,
    _buildImportSnippet,
  ];

  /// Both groups in one list, which is also what each of them is on its own
  /// when the settings pane shows one — see above. They were columns beside
  /// each other on a wide window, each scrolling separately inside a row that
  /// scrolled sideways.
  Widget get _buildBody {
    return ListView(
      padding: context.padBottom(UIs.roundRectCardPadding),
      children: [
        CenterGreyTitle(libL10n.sync),
        ..._syncTiles,
        CenterGreyTitle(libL10n.import),
        ..._importTiles,
      ],
    );
  }

  Widget get _buildBakPwd {
    return FutureBuilder<String?>(
      future: SecureStoreProps.bakPwd.read(),
      builder: (context, snapshot) {
        final hasPwd = snapshot.data?.isNotEmpty == true;
        return ListTile(
          leading: const Icon(Icons.lock),
          title: Text(l10n.backupPassword),
          trailing: Text(
            hasPwd ? l10n.bakPwdSet : l10n.bakPwdNotSet,
            style: UIs.textGrey,
          ),
          onTap: () async => _onTapSetBakPwd(context),
        );
      },
    );
  }

  Future<void> _onTapDeleteBakPwd() async {
    if (_hasEnabledRemoteSync) {
      Toast.show(l10n.remoteBackupPasswordRequired);
      return;
    }
    // In iCloud Keychain: gone from every device.
    if (await SecureStoreProps.bakPwd.inSyncedStore()) {
      if (!mounted) return;
      final ok = await context.showRoundDialog<bool>(
        title: libL10n.delete,
        child: Text(l10n.backupPasswordRemoveSynced),
        actions: Btnx.cancelRedOk,
      );
      if (ok != true) return;
    }
    await SecureStoreProps.bakPwd.write(null);
    Toast.show(l10n.backupPasswordRemoved);
    if (mounted) setState(() {});
  }

  bool get _hasEnabledRemoteSync => _remoteSyncOn();

  /// Says why the sync just run stopped, when one did ([SyncIface.lastFailure]);
  /// false then, so the switch stays off.
  bool _syncWent() {
    final e = bakSync.lastFailure.value;
    if (e == null) return true;
    if (mounted) {
      context.showRoundDialog(
        title: libL10n.fail,
        child: Text(syncFailureText(e) ?? '$e'),
        actions: Btnx.oks,
      );
    }
    return false;
  }

  /// Whether an automatic sync destination is on, [but] aside. The one rule
  /// every switch checks, so a new destination cannot be missed by one of them.
  bool _remoteSyncOn({PrefPropDefault<bool>? but}) {
    final props = <PrefPropDefault<bool>>[
      if (isICloudSupported) PrefProps.icloudSync,
      PrefProps.webdavSync,
      if (Lkc.enabled) LkcSyncPrefs.enabled,
    ];
    return props.any((prop) => prop != but && prop.get());
  }

  Future<bool> _onTapSetBakPwd(
    BuildContext context, {
    String? hint,
    String? emptyMessage,
  }) async {
    final currentPwd = await SecureStoreProps.bakPwd.read();
    final controller = TextEditingController(text: currentPwd ?? '');
    final node = FocusNode();
    final result = await context.showRoundDialog<bool>(
      title: l10n.backupPassword,
      // Both disposed by the tree. The focus node has the same problem the
      // controller does — the field holds it while the route animates out —
      // and here they were also disposed on two paths, so an early return had
      // to remember both.
      child: DisposeWith(
        notifiers: [controller, node],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(hint ?? l10n.backupPasswordTip, style: UIs.textGrey),
            UIs.height13,
            Input(
              label: l10n.backupPassword,
              controller: controller,
              node: node,
              obscureText: true,
              onSubmitted: (_) => context.popDialog(true),
            ),
          ],
        ),
      ),
      actions: [
        if (currentPwd?.isNotEmpty ?? false)
          TextButton(
            onPressed: () {
              context.popDialog();
              unawaited(_onTapDeleteBakPwd());
            },
            child: Text(libL10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ...Btnx.oks,
      ],
    );
    if (result != true) return false;

    final pwd = controller.text.trim();
    if (pwd.isEmpty) {
      Toast.show(emptyMessage ?? libL10n.empty);
      return false;
    }
    final previous = currentPwd;
    if (previous != pwd) {
      // First: the remotes' keys are still sealed with it, and a restart
      // before they are sealed again must still open them.
      await SyncKey.passwordChanged(previous);
      await SecureStoreProps.bakPwd.write(pwd);
      // Sealed again now; the syncs then go on with it.
      unawaited(
        SyncKey.recheck().whenComplete(() {
          unawaited(LkcLogSync.sync());
          unawaited(FileLogSync.sync());
          // Not to upload (the backup is sealed to the key): to clear what the
          // last one said of the password.
          if (_hasEnabledRemoteSync) bakSync.syncSoon(milliDelay: 0, throttleMilli: 0);
        }),
      );
    }
    Toast.show(l10n.backupPasswordSet);
    setState(() {});
    return true;
  }

  /// A new key and a new backup password together: a device that still knows
  /// the password reads the new key from LK Cloud.
  Future<void> _onTapRotateSyncKey(BuildContext context) async {
    final ok = await context.showRoundDialog<bool>(
      title: l10n.syncKeyRotate,
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !context.mounted) return;
    // Only with the account's key open here: a new one is put beside it.
    try {
      await LkcLogSync.key();
    } on SyncPasswordMismatch catch (e) {
      return Toast.show(e.toString());
    } catch (e, s) {
      if (mounted) _showLkcErr(e, s, l10n.syncKeyRotate);
      return;
    }
    if (!context.mounted || !await _onTapSetBakPwd(context)) return;
    lkcLoading.value = true;
    try {
      await LkcLogSync.rotateKey();
      Toast.show(libL10n.success);
    } catch (e, s) {
      if (mounted) _showLkcErr(e, s, l10n.syncKeyRotate);
    } finally {
      lkcLoading.value = false;
    }
  }

  void _showLkcErr(Object e, StackTrace s, String operation) {
    final err = e is LkcSyncError ? e.exception : e;
    context.showErrDialog(
      err is LkcException ? err.text(libL10n) : err,
      s,
      operation,
    );
  }

  void _refreshIcloudStatus({bool notify = true}) {
    if (!isICloudSupported) return;

    final future = _loadIcloudStatus();
    if (!notify) {
      _icloudStatusFuture = future;
      return;
    }

    setState(() {
      _icloudStatusFuture = future;
    });
  }

  /// The other half of the share button on a server's page.
  ///
  /// Separate from [_buildBulkImportServers], which takes a plain JSON array
  /// of servers and carries no keys: this one takes an encrypted payload made
  /// by another device, which does.
  Widget get _buildImportSharedServer {
    return CardX(
      child: ListTile(
        title: Text(l10n.shareImportTitle),
        leading: const Icon(Icons.ios_share),
        onTap: () => ServerShareUi.receiveFromFile(context, ref),
        trailing: const Icon(Icons.keyboard_arrow_right),
      ),
    );
  }

  Widget get _buildBulkImportServers {
    return CardX(
      child: ListTile(
        title: Text(libL10n.server),
        leading: const Icon(BoxIcons.bx_server),
        onTap: () => _onBulkImportServers(context),
        trailing: const Icon(Icons.keyboard_arrow_right),
      ),
    );
  }

  Widget get _buildImportSnippet {
    return ListTile(
      title: Text(libL10n.snippet),
      leading: const Icon(MingCute.code_line),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () async {
        final data = await context.showImportDialog(
          title: libL10n.snippet,
          modelDef: Snippet.example.toJson(),
        );
        if (data == null || !context.mounted) return;
        String str;
        try {
          str = utf8.decode(data);
        } on FormatException catch (e, s) {
          context.showErrDialog(e, s, libL10n.error);
          return;
        }
        final text = str.trim();
        if (!await _routeImport(context, text)) return;
        final (list, _) = await context.showLoadingDialog(
          fn: () => compute((s) => json.decode(s) as List, text),
        );
        if (list == null || list.isEmpty || !context.mounted) return;
        final snippets = <Snippet>[];
        final errs = <String>[];
        for (final item in list) {
          try {
            final snippet = Snippet.fromJson(item);
            snippets.add(snippet);
          } catch (e) {
            errs.add(e.toString());
          }
        }
        if (snippets.isEmpty) {
          Toast.show(libL10n.empty);
          return;
        }
        if (errs.isNotEmpty) {
          await context.showRoundDialog(
            title: libL10n.error,
            child: SingleChildScrollView(child: Text(errs.join('\n'))),
          );
          return;
        }
        final snippetNames = snippets.map((e) => e.name).join(', ');
        // The dialog answers; the page acts on the answer, and closes
        // itself. Doing both from the button meant two pops in a row from a
        // callback that can see two navigators.
        final confirmed = await context.showRoundDialog<bool>(
          title: libL10n.attention,
          child: SingleChildScrollView(
            child: Text(
              libL10n.askContinue('${libL10n.import} [$snippetNames]'),
            ),
          ),
          actions: Btn.ok().toList,
        );
        if (confirmed != true || !context.mounted) return;
        final notifier = ref.read(snippetProvider.notifier);
        for (final snippet in snippets) {
          notifier.add(snippet);
        }
        context.pop();
      },
    ).cardx;
  }

  @override
  bool get wantKeepAlive => true;
}

extension on _BackupPageState {
  /// Hands an imported document to whichever reader owns it, and answers
  /// whether that is the calling tile.
  ///
  /// Every import tile here takes the same dialog and the same document, so a
  /// backup can arrive at any of them. Restoring it is what keeps that from
  /// being an error, since the tile's own reader would answer with a cast
  /// failure — which says what went wrong and not what to do instead.
  ///
  /// A document this answers false for is not the caller's to read: it was a
  /// backup and has been restored, it could not be read and the failure is on
  /// screen, or the page was gone before that could be decided. Every caller's
  /// next step opens another dialog, which is why none of the three continues.
  Future<bool> _routeImport(BuildContext context, String text) async {
    // An encrypted envelope is not JSON, so it is recognised before anything
    // tries to parse it.
    if (AgeCryptor.isEncryptedText(text)) {
      await BackupService.restoreFromText(context, text);
      return false;
    }
    final (isBackup, err) = await context.showLoadingDialog(
      fn: () => compute(BackupReader.isBackup, text),
    );
    // A context that has been deactivated cannot open the dialog every caller
    // leads with, and `showLoadingDialog` closes the one it was reading behind
    // on its own, so this is reachable.
    if (!context.mounted) return false;
    // Reported by `showLoadingDialog` in a dialog of its own already; throwing
    // it raised a second one for the same failure.
    if (err != null) return false;
    if (isBackup != true) return true;
    await BackupService.restoreFromText(context, text);
    return false;
  }

  Future<_ICloudBackupStatus?> _loadIcloudStatus() async {
    if (!isICloudSupported) return null;

    final files = await icloud.list();
    final matches = files.where(
      (file) =>
          file.relativePath == Paths.bakName && file.contentChangeDate != null,
    );
    if (matches.isEmpty) return null;

    final file = matches.reduce(
      (latest, current) =>
          current.contentChangeDate!.isAfter(latest.contentChangeDate!)
          ? current
          : latest,
    );
    return _ICloudBackupStatus(
      lastModified: file.contentChangeDate!,
      isUploading: file.isUploading,
      isUploaded: file.isUploaded,
      hasConflict: file.hasUnresolvedConflicts,
    );
  }

  Future<void> _onTapWebdavDl(BuildContext context) async {
    remoteLoading.value = true;
    try {
      final files = await SyncRemotes.webdav.list();
      if (files.isEmpty) return Toast.show(l10n.dirEmpty);

      final fileName = await context.showPickSingleDialog(
        title: libL10n.restore,
        items: files,
      );
      if (fileName == null) return;

      await SyncRemotes.webdav.download(relativePath: fileName);
      final dlFile = await File('${Paths.doc}/$fileName').readAsBytes();
      if (!context.mounted) return;
      await BackupService.restoreData(context, dlFile);
    } catch (e, s) {
      context.showErrDialog(e, s, libL10n.restore);
      Loggers.app.warning('Download webdav backup failed', e, s);
    } finally {
      remoteLoading.value = false;
    }
  }

  Future<void> _onTapWebdavUp(BuildContext context) async {
    remoteLoading.value = true;
    final date = DateTime.now().ymdhms(ymdSep: '-', hmsSep: '-', sep: '-');
    final bakName = '$date-${Miscs.exportBakFileName}';
    try {
      final ok = await _ensureBakPwd(context);
      if (!ok) return;
      await BackupV2.backup(bakName, await SecureStoreProps.bakPwd.read());
      await SyncRemotes.webdav.upload(relativePath: bakName);
      Loggers.app.info('Upload webdav backup success');
    } catch (e, s) {
      context.showErrDialog(e, s, libL10n.upload);
      Loggers.app.warning('Upload webdav backup failed', e, s);
    } finally {
      remoteLoading.value = false;
    }
  }

  /// The synced backup as it is, or one of the versions LK Cloud kept of it.
  Future<void> _onTapLkcRestore(BuildContext context) async {
    if (!Lkc.client.signedIn) return Toast.show(libL10n.lkcNotSignedIn);
    lkcLoading.value = true;
    Directory? dir;
    try {
      // First: nothing of the account is listed while the password here does
      // not open its key.
      final SyncKey key;
      try {
        key = await LkcLogSync.key(create: false);
      } on SyncKeyNotHere {
        return Toast.show(l10n.dirEmpty);
      }
      dir = await Directory.systemTemp.createTemp('sb-lkc-restore-');
      final sync = await Lkc.client.sync(Lkc.app);
      final name = Miscs.bakFileName;
      final current = (await sync.list()).where((f) => f.name == name);
      final versions = await sync.versions(name: name);
      final items = [
        for (final f in current) (f.etag, f.updatedAt, true),
        for (final v in versions) (v.etag, v.writtenAt, false),
      ];
      if (items.isEmpty) return Toast.show(l10n.dirEmpty);
      if (!context.mounted) return;

      String when(String at) =>
          DateTime.tryParse(at)?.toLocal().ymdhms() ?? at;
      final picked = await context.showPickSingleDialog(
        title: libL10n.restore,
        items: items,
        display: (e) => e.$3 ? '${when(e.$2)} ✓' : when(e.$2),
      );
      if (picked == null) return;

      final path = '${dir.path}/$name';
      final fetched = picked.$3
          ? await sync.download(name: name, to: path)
          : await sync.downloadVersion(name: name, etag: picked.$1, to: path);
      if (fetched.missing) return Toast.show(l10n.dirEmpty);
      final bytes = await key.openFresh(await File(path).readAsBytes());
      if (context.mounted) await BackupService.restoreData(context, bytes);
    } on SyncPasswordMismatch catch (e) {
      // Said as the card above says it: no error to report.
      Toast.show(e.toString());
    } catch (e, s) {
      if (context.mounted) _showLkcErr(e, s, libL10n.restore);
      Loggers.app.warning('Restore LK Cloud backup failed', e, s);
    } finally {
      await dir?.delete(recursive: true);
      lkcLoading.value = false;
    }
  }

  Future<void> _onTapWebdavSetting(BuildContext context) async {
    final url = TextEditingController(text: SyncRemotes.webdavUrl);
    final user = TextEditingController(text: SyncRemotes.webdavUser);
    final pwd = TextEditingController(text: SyncRemotes.webdavPwd);
    final nodeUser = FocusNode();
    final nodePwd = FocusNode();
    final result = await context.showRoundDialog<bool>(
      title: 'WebDAV',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Input(
            label: 'URL',
            hint: 'https://example.com/sub/',
            controller: url,
            suggestion: false,
            onSubmitted: (p0) => FocusScope.of(context).requestFocus(nodeUser),
          ),
          Input(
            label: libL10n.user,
            controller: user,
            node: nodeUser,
            suggestion: false,
            onSubmitted: (p0) => FocusScope.of(context).requestFocus(nodePwd),
          ),
          Input(
            label: libL10n.pwd,
            controller: pwd,
            node: nodePwd,
            suggestion: false,
            onSubmitted: (_) => context.popDialog(true),
          ),
        ],
      ),
      actions: Btnx.oks,
    );
    if (result == true) {
      try {
        final url_ = url.text;
        final user_ = user.text;
        final pwd_ = pwd.text;

        await Webdav.test(url_, user_, pwd_);
        Toast.success(libL10n.success);

        SyncRemotes.setWebdav(url: url_, user: user_, pwd: pwd_);
        // The sync shortcut remembers a tag from *a* WebDAV server, and the
        // backend's type is the same whichever one it points at. Pointing it
        // somewhere new is exactly when the skip would be wrong.
        await BakSyncer.forgetCheckpoint();
        // The server it names is shown.
        _webdavEdited.value++;
      } catch (e, s) {
        context.showErrDialog(e, s, 'Webdav');
      }
    }
    url.dispose();
    user.dispose();
    pwd.dispose();
    nodeUser.dispose();
    nodePwd.dispose();
  }

  void _onBulkImportServers(BuildContext context) async {
    final data = await context.showImportDialog(
      title: libL10n.server,
      // `pve` beside the server's own fields: it is a table of its own, not
      // part of `Spi`, and this is the one place the import shape is shown.
      modelDef: {...Spix.example.toJson(), 'pve': PveConfig.example.toJson()},
    );
    if (data == null) return;
    String text;
    try {
      text = utf8.decode(data);
    } on FormatException catch (e, s) {
      context.showErrDialog(e, s, libL10n.error);
      return;
    }

    try {
      text = text.trim();
      if (!await _routeImport(context, text)) return;
      final (spis, err) = await context.showLoadingDialog(
        fn: () => compute((String val) {
          final list = json.decode(val) as List;
          return [
            for (final e in list)
              (spi: Spi.fromJson(e), pve: PveConfig.fromServerRecord(e)),
          ];
        }, text),
      );
      if (err != null || spis == null) return;
      final sure = await context.showRoundDialog<bool>(
        title: libL10n.import,
        child: Text(libL10n.askContinue('${spis.length} ${libL10n.server}')),
        actions: Btnx.oks,
      );
      if (sure == true) {
        final (suc, err) = await context.showLoadingDialog(
          fn: () async {
            final usedIds = <String>{};
            for (final (:spi, :pve) in spis) {
              // Preserve valid ids while resolving missing or duplicate ids
              // within this import.
              final isIdUsed = spi.id.isEmpty || usedIds.contains(spi.id);
              final spiWithId = isIdUsed
                  ? spi.copyWith(id: ShortId.generate())
                  : spi;
              Stores.server.put(spiWithId);
              // Only when the record has one: an import adds, and a record
              // without PVE says nothing about a server that already had it.
              if (pve != null) Stores.pve.put(spiWithId.id, pve);
              usedIds.add(spiWithId.id);
            }
            return true;
          },
        );
        if (err != null || suc != true) return;
        Toast.success(libL10n.success);
      }
    } catch (e, s) {
      if (context.mounted) context.showErrDialog(e, s, libL10n.import);
      Loggers.app.warning('Import servers failed', e, s);
    }
  }

  Future<bool> _ensureBakPwd(BuildContext context) async {
    final saved = await SecureStoreProps.bakPwd.read();
    if (saved != null && saved.isNotEmpty) return true;

    // Remote backups contain credentials and private keys, so encryption is
    // mandatory rather than an optional warning.
    final result = await context.showRoundDialog<bool>(
      title: l10n.backupPassword,
      child: Text(l10n.remoteBackupPasswordRequired, style: UIs.textGrey),
      actions: [
        TextButton(
          onPressed: () => context.popDialog(false),
          child: Text(libL10n.cancel),
        ),
        TextButton(
          onPressed: () => context.popDialog(true),
          child: Text(libL10n.setting),
        ),
      ],
    );

    if (result == true) {
      return _onTapSetBakPwd(
        context,
        hint: l10n.remoteBackupPasswordRequired,
        emptyMessage: l10n.remoteBackupPasswordRequired,
      );
    }

    return false;
  }
}

final class _ICloudBackupStatus {
  const _ICloudBackupStatus({
    required this.lastModified,
    required this.isUploading,
    required this.isUploaded,
    required this.hasConflict,
  });

  final DateTime lastModified;
  final bool isUploading;
  final bool isUploaded;
  final bool hasConflict;
}
