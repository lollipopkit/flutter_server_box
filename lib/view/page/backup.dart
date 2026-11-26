import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/lkc.dart';
import 'package:server_box/core/sync/category.dart';
import 'package:server_box/core/sync/failure.dart';
import 'package:server_box/core/sync/file_log.dart';
import 'package:server_box/core/sync/lkc_log.dart';
import 'package:server_box/core/sync/lkc_prefs.dart';
import 'package:server_box/core/sync/remotes.dart';
import 'package:server_box/core/sync/secret_key_prefs.dart';
import 'package:server_box/core/sync/sync.dart';
import 'package:server_box/core/utils/pending_ops.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/backup_reader.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/view/page/backup/service.dart';
import 'package:server_box/view/page/backup/source.dart';
import 'package:server_box/view/page/server/widget/server_share.dart';
import 'package:server_box/view/page/setting/group.dart';
import 'package:server_box/view/widget/secret_key_widgets.dart';

part 'backup/sync.dart';

/// Which half of the page to show.
///
/// The two halves answer different questions — "keep this somewhere else" and
/// "bring something in" — and only ever shared a page because both are about
/// moving data. The settings menu lists them as two rows, so each opens on its
/// own.
enum BackupSection { sync, import }

class BackupPage extends ConsumerStatefulWidget {
  /// Null shows all sync and import groups together in one [PageColumns] grid.
  ///
  /// That is the standalone [route], which the DMG notice opens directly: there
  /// is no menu around it to say which half you are looking at, so it shows all
  /// groups together. Inside the settings page the row that opened it already
  /// selects a section.
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
  final lkcOps = PendingOps();
  ValueListenable<bool> get lkcLoading => lkcOps.loading;

  /// A sync started here running.
  final _syncing = false.vn;

  /// The WebDAV settings saved here, which name the server shown.
  final _webdavEdited = 0.vn;
  late Future<bool> _icloudConflict;

  /// The backup password, read again when it is set or removed here.
  late Future<String?> _bakPwd = SecureStoreProps.bakPwd.read();

  /// The client-side secret key, read again when set or auto-generated.
  late Future<String?> _secretKey = SecureStoreProps.syncSecretKey.read();

  /// Built once: a new one each build would subscribe again each time.
  late final _destChanges = Listenable.merge([_SyncDest.changes, _webdavEdited]);
  late final _manualChanges = Listenable.merge([
    _destChanges,
    remoteLoading,
    lkcLoading,
  ]);
  late final _statusChanges = Listenable.merge([
    _syncing,
    bakSync.running,
    bakSync.lastFailure,
    lkcLog.lastFailure,
    fileLog.lastFailure,
    SyncKeyring.passwordMismatch,
    SyncKeyring.secretKeyMissing,
    BakSyncer.remoteTooNew,
    lkcLog.tooNew,
    fileLog.tooNew,
  ]);

  /// Anchor for the sync-channel context menu so every tap opens in one place.
  final _destAnchorKey = GlobalKey();

  /// A channel being switched to.
  bool _selectingDest = false;

  @override
  void initState() {
    super.initState();
    _icloudConflict = Future.value(false);
    if (isICloudSupported) {
      _refreshIcloudStatus(notify: false);
    }
    SyncKeyring.secretKeyGenerated.addListener(_onSecretKeyGenerated);
    SyncKeyring.secretKeyMissing.addListener(_onSecretKeyStatusChanged);
    if (SyncKeyring.secretKeyGenerated.value != null || SyncSecretKeyPrefs.backupPending.get()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_checkPendingSecretKeyBackup()));
    }
  }

  @override
  void dispose() {
    SyncKeyring.secretKeyGenerated.removeListener(_onSecretKeyGenerated);
    SyncKeyring.secretKeyMissing.removeListener(_onSecretKeyStatusChanged);
    remoteLoading.dispose();
    lkcOps.dispose();
    _syncing.dispose();
    _webdavEdited.dispose();
    super.dispose();
  }

  void _onSecretKeyStatusChanged() {
    if (!mounted) return;
    setState(() {
      _secretKey = SecureStoreProps.syncSecretKey.read();
    });
  }

  void _onSecretKeyGenerated() {
    final key = SyncKeyring.secretKeyGenerated.value;
    if (key == null) return;
    SyncKeyring.secretKeyGenerated.value = null;
    unawaited(SyncSecretKeyPrefs.backupPending.set(true));
    if (!mounted) return;
    setState(() {
      _secretKey = Future.value(key);
    });
    unawaited(_showSecretKeySheet(context, key, justGenerated: true));
  }

  Future<void> _checkPendingSecretKeyBackup() async {
    if (SyncKeyring.secretKeyGenerated.value != null) {
      _onSecretKeyGenerated();
      return;
    }
    if (!SyncSecretKeyPrefs.backupPending.get()) return;
    final key = await SecureStoreProps.syncSecretKey.read();
    if (!mounted || key == null || key.isEmpty) return;
    setState(() {
      _secretKey = Future.value(key);
    });
    await _showSecretKeySheet(context, key, justGenerated: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final section = widget.section;
    if (section == null) {
      return Scaffold(
        appBar: CustomAppBar(title: Text(libL10n.backup)),
        body: SafeArea(
          top: false,
          bottom: false,
          child: _buildGrid([..._syncGroups, _buildImportGroup]),
        ),
      );
    }

    // Shown in the settings content pane, which brings the Scaffold and the
    // bar. No page heading either, for the reason [AppSettingsPage] gives: the
    // menu names the group and the bar repeats it.
    if (section == BackupSection.sync) return _buildGrid(_syncGroups);
    return _buildGrid([_buildImportGroup]);
  }

  Widget _buildGrid(List<Widget> children) {
    return PageColumns(
      padding: kSettingsGridPadding,
      spacing: kSettingsGridSpacing,
      bottomInset: MediaQuery.paddingOf(context).bottom,
      children: children,
    );
  }

  Widget get _buildImportGroup {
    return SettingsGroupView(
      SettingsGroup(libL10n.import, [
        SettingsRow(l10n.shareImportTitle, () => _buildImportSharedServer),
        SettingsRow(libL10n.server, () => _buildBulkImportServers),
        SettingsRow(libL10n.snippet, () => _buildImportSnippet),
      ]),
    );
  }

  Widget get _buildBakPwd {
    return FutureBuilder<String?>(
      future: _bakPwd,
      builder: (context, snapshot) {
        final hasPwd = snapshot.data?.isNotEmpty == true;
        return ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(l10n.backupPassword),
          trailing: Text(
            hasPwd ? l10n.bakPwdSet : l10n.bakPwdNotSet,
            style: hasPwd
                ? UIs.text15
                : UIs.text15.copyWith(color: UIs.textGrey.color),
          ),
          onTap: () async => _onTapSetBakPwd(context),
        );
      },
    );
  }

  Widget get _buildSecretKey {
    return FutureBuilder<String?>(
      future: _secretKey,
      builder: (context, snapshot) {
        final hasKey = snapshot.data?.isNotEmpty == true;
        return ListTile(
          leading: const Icon(Icons.vpn_key_outlined),
          title: Text(l10n.syncSecretKey),
          trailing: Text(
            hasKey ? l10n.bakPwdSet : l10n.bakPwdNotSet,
            style: hasKey
                ? UIs.text15
                : UIs.text15.copyWith(color: UIs.textGrey.color),
          ),
          onTap: () async => _onTapSecretKey(context),
        );
      },
    );
  }

  Future<bool> _ensureSecretKey(BuildContext context) async {
    final current = await SecureStoreProps.syncSecretKey.read(limited: false);
    if (current != null && current.isNotEmpty) return true;
    if (!context.mounted) return false;
    return _onTapEnterSecretKey(context);
  }

  Future<void> _onTapSecretKey(BuildContext context) async {
    final current = await SecureStoreProps.syncSecretKey.read();
    if (!context.mounted) return;
    if (current != null && current.isNotEmpty) {
      await _showSecretKeySheet(
        context,
        current,
        justGenerated: SyncSecretKeyPrefs.backupPending.get(),
      );
      if (mounted) {
        setState(() {
          _secretKey = SecureStoreProps.syncSecretKey.read();
        });
      }
      return;
    }
    await _onTapEnterSecretKey(context);
  }

  Future<bool> _showSecretKeySheet(
    BuildContext context,
    String key, {
    bool justGenerated = false,
  }) async {
    final acknowledged = (!justGenerated).vn;
    final confirmed = await context.showSheet<bool>(
      title: l10n.syncSecretKey,
      child: DisposeWith(
        notifiers: [acknowledged],
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.syncSecretKeyBackupNote, style: UIs.textGrey),
              UIs.height13,
              const SecretKeyZeroKnowledgeWarning(),
              UIs.height13,
              SecretKeyQrDisplay(
                secretKey: key,
                qrWidth: 200,
                inCard: false,
                showCopyButton: false,
              ),
              if (justGenerated) ...[
                UIs.height13,
                acknowledged.listenVal(
                  (checked) => CheckboxListTile(
                    value: checked,
                    onChanged: (v) => acknowledged.value = v ?? false,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(l10n.syncSecretKeyAck, style: UIs.text13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!justGenerated)
          TextButton(
            onPressed: () {
              context.popSheet(false);
              unawaited(_confirmReplaceSecretKey(context));
            },
            child: Text(l10n.syncSecretKeyReplace),
          ),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: key));
            Toast.success(libL10n.success);
          },
          child: Text(libL10n.copy),
        ),
        if (justGenerated)
          acknowledged.listenVal(
            (checked) => TextButton(
              onPressed: checked ? () => context.popSheet(true) : null,
              child: Text(l10n.syncSecretKeySavedBtn),
            ),
          )
        else
          ...Btnx.oks,
      ],
    );
    if (justGenerated && confirmed == true) {
      await SyncSecretKeyPrefs.backupPending.set(false);
      await SyncSecretKeyPrefs.introDeferred.set(false);
      return true;
    }
    return false;
  }

  Future<void> _confirmReplaceSecretKey(BuildContext context) async {
    final ok = await context.showSheet<bool>(
      title: l10n.syncSecretKeyReplace,
      child: Text(l10n.syncSecretKeyReplaceConfirm),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !context.mounted) return;
    await _onTapEnterSecretKey(context, allowGenerate: false);
  }

  Future<void> _saveSecretKeyAndResume(String normalized) async {
    await SyncKeyring.storeSecretKey(normalized);
    await SyncSecretKeyPrefs.backupPending.set(false);
    await SyncSecretKeyPrefs.introDeferred.set(false);
    if (Lkc.enabled) {
      await Lkc.client.resetPersonalAuth(clearCachedKey: true);
    }
    if (mounted) {
      setState(() {
        _secretKey = Future.value(normalized);
      });
    }
    unawaited(() async {
      try {
        await SyncKeyring.recheck();
      } catch (e, s) {
        Loggers.app.warning('SyncKeyring.recheck failed after saving secret key', e, s);
      }
      unawaited(lkcLog.sync());
      unawaited(fileLog.sync());
      if (_hasEnabledRemoteSync) bakSync.syncSoon(milliDelay: 0, throttleMilli: 0);
    }());
    Toast.success(l10n.syncSecretKeySaved);
  }

  Future<bool> _onTapGenerateSecretKey(BuildContext context) async {
    String generated;
    try {
      await FlRust.ensureInitialized();
      generated = SyncKeyring.generateSecretKey();
    } catch (e, s) {
      Loggers.app.warning('Secret key generation failed', e, s);
      Toast.show(l10n.syncSecretKeyUnavailable);
      return false;
    }
    if (!context.mounted) return false;
    final confirmed = await _showSecretKeySheet(context, generated, justGenerated: true);
    if (!confirmed) return false;
    // Never overwrite a key that arrived concurrently via platform keychain sync.
    final concurrent = await SecureStoreProps.syncSecretKey.read(limited: false);
    if (concurrent != null && concurrent.isNotEmpty) {
      await SyncSecretKeyPrefs.backupPending.set(false);
      await SyncSecretKeyPrefs.introDeferred.set(false);
      if (mounted) {
        setState(() {
          _secretKey = Future.value(concurrent);
        });
      }
      return true;
    }
    await _saveSecretKeyAndResume(generated);
    return true;
  }

  Future<bool> _onTapEnterSecretKey(
    BuildContext context, {
    bool allowGenerate = true,
  }) async {
    final controller = TextEditingController();
    final node = FocusNode();
    final canGenerate = allowGenerate && !SyncKeyring.secretKeyMissing.value;
    final result = await context.showSheet<String>(
      title: l10n.syncSecretKey,
      child: DisposeWith(
        notifiers: [controller, node],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.syncSecretKeyMissingDetail, style: UIs.textGrey),
            UIs.height13,
            Input(
              label: l10n.syncSecretKey,
              hint: 'S1-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX',
              controller: controller,
              node: node,
              suggestion: false,
              onSubmitted: (_) => context.popSheet('import'),
            ),
          ],
        ),
      ),
      actions: [
        if (canGenerate)
          TextButton(
            onPressed: () => context.popSheet('generate'),
            child: Text(l10n.syncSecretKeyTabGenerate),
          ),
        if (isMobile)
          TextButton.icon(
            onPressed: () async {
              final scanned = await BarcodeScannerPage.route.go(
                context,
                args: const BarcodeScannerPageArgs(),
              );
              final text = scanned?.text;
              if (text == null || !context.mounted) return;
              controller.text = text.trim();
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(l10n.syncSecretKeyScan),
          ),
        TextButton(
          onPressed: () => context.popSheet('import'),
          child: Text(libL10n.ok),
        ),
      ],
    );
    if (!context.mounted) return false;
    if (result == 'generate') {
      return _onTapGenerateSecretKey(context);
    }
    if (result != 'import') return false;
    String? normalized;
    try {
      await FlRust.ensureInitialized();
      normalized = SyncKeyring.normalizeSecretKey(controller.text);
    } catch (e, s) {
      Loggers.app.warning('Secret key validation unavailable', e, s);
      Toast.show(l10n.syncSecretKeyUnavailable);
      return false;
    }
    if (normalized == null) {
      Toast.show(l10n.syncSecretKeyInvalid);
      return false;
    }
    await _saveSecretKeyAndResume(normalized);
    return true;
  }

  Future<void> _onTapDeleteBakPwd() async {
    if (_hasEnabledRemoteSync) {
      Toast.show(l10n.remoteBackupPasswordRequired);
      return;
    }
    // In iCloud Keychain: gone from every device.
    if (await SecureStoreProps.bakPwd.inSyncedStore()) {
      if (!mounted) return;
      final ok = await context.showSheet<bool>(
        title: libL10n.delete,
        child: Text(l10n.backupPasswordRemoveSynced),
        actions: Btnx.cancelRedOk,
      );
      if (ok != true) return;
    }
    await SecureStoreProps.bakPwd.write(null);
    Toast.show(l10n.backupPasswordRemoved);
    if (mounted) setState(() => _bakPwd = SecureStoreProps.bakPwd.read());
  }

  bool get _hasEnabledRemoteSync => _SyncDest.current != _SyncDest.off;

  /// Says why the sync just run stopped, when one did ([SyncIface.lastFailure]);
  /// false then, so the switch stays off.
  bool _syncWent() {
    final e = bakSync.lastFailure.value;
    if (e == null) return true;
    if (mounted) {
      context.showSheet(
        title: libL10n.fail,
        child: Text(syncFailureText(e) ?? '$e'),
        actions: Btnx.oks,
      );
    }
    return false;
  }

  Future<bool> _onTapSetBakPwd(
    BuildContext context, {
    String? hint,
    String? emptyMessage,
  }) async {
    final currentPwd = await SecureStoreProps.bakPwd.read();
    if (!context.mounted) return false;
    final controller = TextEditingController(text: currentPwd ?? '');
    final node = FocusNode();
    final result = await context.showSheet<bool>(
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
              onSubmitted: (_) => context.popSheet(true),
            ),
          ],
        ),
      ),
      actions: [
        if (currentPwd?.isNotEmpty ?? false)
          TextButton(
            onPressed: () {
              context.popSheet();
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
      await SyncKeyring.passwordChanged(previous);
      await SecureStoreProps.bakPwd.write(pwd);
      // Sealed again now; serialize account-key passphrase update before
      // resuming LK Cloud syncs so `lkc/identity.age` never races ahead.
      unawaited(() async {
        await SyncKeyring.recheck();
        if (previous != null && previous.isNotEmpty && Lkc.enabled && Lkc.client.signedIn) {
          try {
            await Lkc.client.changePersonalAuthPassphrase(old: previous, newPassphrase: pwd);
          } catch (e, s) {
            Loggers.app.warning('LK Cloud account key passphrase change', e, s);
          }
        }
        unawaited(lkcLog.sync());
        unawaited(fileLog.sync());
        if (_hasEnabledRemoteSync) bakSync.syncSoon(milliDelay: 0, throttleMilli: 0);
      }());
    }
    Toast.show(l10n.backupPasswordSet);
    if (mounted) setState(() => _bakPwd = SecureStoreProps.bakPwd.read());
    return true;
  }

  /// A new key and a new backup password together: a device that still knows
  /// the password reads the new key from LK Cloud.
  Future<void> _onTapRotateSyncKey(BuildContext context) async {
    final ok = await context.showSheet<bool>(
      title: l10n.syncKeyRotate,
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !context.mounted) return;
    await lkcOps.run('rotate-key', () async {
      // Keep the operation registered through password save so it can finish
      // if the page is disposed after the password is confirmed.
      try {
        await lkcLog.key();
      } on SyncPasswordMismatch catch (e) {
        Toast.show(syncFailureText(e) ?? l10n.syncPasswordMismatch);
        return;
      } on SyncSecretKeyMissing catch (e) {
        Toast.show(syncFailureText(e) ?? l10n.syncSecretKeyMissingDetail);
        return;
      } catch (e, s) {
        if (mounted) _showLkcErr(e, s, l10n.syncKeyRotate);
        return;
      }
      if (!context.mounted || !await _onTapSetBakPwd(context)) return;
      try {
        await lkcLog.rotateKey();
        Toast.show(libL10n.success);
      } catch (e, s) {
        if (mounted) {
          _showLkcErr(e, s, l10n.syncKeyRotate);
        } else {
          Loggers.app.warning('Failed to rotate the LK Cloud sync key', e, s);
          Toast.show(l10n.syncKeyRotate, body: libL10n.fail);
        }
      }
    });
  }

  void _showLkcErr(Object e, StackTrace s, String operation) {
    final err = e is LkcSyncError ? e.exception : e;
    context.showErrSheet(
      err is LkcException ? err.text(libL10n) : err,
      s,
      operation,
    );
  }

  void _refreshIcloudStatus({bool notify = true}) {
    // Also after a sync that outlived the page.
    if (!isICloudSupported || !mounted) return;

    final future = _loadIcloudConflict();
    if (!notify) {
      _icloudConflict = future;
      return;
    }

    setState(() {
      _icloudConflict = future;
    });
  }

  /// The other half of the share button on a server's page.
  ///
  /// Separate from [_buildBulkImportServers], which takes a plain JSON array
  /// of servers and carries no keys: this one takes an encrypted payload made
  /// by another device, which does.
  Widget get _buildImportSharedServer {
    return ListTile(
      title: Text(l10n.shareImportTitle),
      leading: const Icon(Icons.ios_share),
      onTap: () => ServerShareUi.receiveFromFile(context, ref),
      trailing: const Icon(Icons.keyboard_arrow_right),
    );
  }

  Widget get _buildBulkImportServers {
    return ListTile(
      title: Text(libL10n.server),
      leading: const Icon(BoxIcons.bx_server),
      onTap: () => _onBulkImportServers(context),
      trailing: const Icon(Icons.keyboard_arrow_right),
    );
  }

  Widget get _buildImportSnippet {
    return ListTile(
      title: Text(libL10n.snippet),
      leading: const Icon(MingCute.code_line),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () async {
        final data = await context.showImportSheet(
          title: libL10n.snippet,
          modelDef: Snippet.example.toJson(),
        );
        if (data == null || !context.mounted) return;
        String str;
        try {
          str = utf8.decode(data);
        } on FormatException catch (e, s) {
          context.showErrSheet(e, s, libL10n.error);
          return;
        }
        final text = str.trim();
        if (!await _routeImport(context, text)) return;
        final (list, _) = await context.showLoadingSheet(
          fn: () => compute((s) => json.decode(s) as List, text),
        );
        if (list == null || list.isEmpty || !context.mounted) return;
        final snippets = <Snippet>[];
        final errs = <String>[];
        for (final item in list) {
          try {
            final snippet = Snippet.fromJson(
              Map<String, dynamic>.from(item as Map),
            );
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
          await context.showSheet(
            title: libL10n.error,
            child: SingleChildScrollView(child: Text(errs.join('\n'))),
          );
          return;
        }
        final snippetNames = snippets.map((e) => e.name).join(', ');
        // The dialog answers; the page acts on the answer, and closes
        // itself. Doing both from the button meant two pops in a row from a
        // callback that can see two navigators.
        final confirmed = await context.showSheet<bool>(
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
    );
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
    final (isBackup, err) = await context.showLoadingSheet(
      fn: () => compute(BackupReader.isBackup, text),
    );
    // A context that has been deactivated cannot open the dialog every caller
    // leads with, and `showLoadingSheet` closes the one it was reading behind
    // on its own, so this is reachable.
    if (!context.mounted) return false;
    // Reported by `showLoadingSheet` in a dialog of its own already; throwing
    // it raised a second one for the same failure.
    if (err != null) return false;
    if (isBackup != true) return true;
    await BackupService.restoreFromText(context, text);
    return false;
  }

  /// Whether iCloud holds versions of the backup it could not reconcile.
  Future<bool> _loadIcloudConflict() async {
    if (!isICloudSupported) return false;
    final files = await icloud.list();
    return files.any((file) => file.relativePath == Paths.bakName && file.hasUnresolvedConflicts);
  }

  Future<void> _onTapWebdavDl(BuildContext context) async {
    remoteLoading.value = true;
    try {
      final files = await SyncRemotes.webdav.list();
      if (files.isEmpty) return Toast.show(l10n.dirEmpty);

      final fileName = await context.showPickSingleSheet(
        title: libL10n.restore,
        items: files,
      );
      if (fileName == null) return;

      await SyncRemotes.webdav.download(relativePath: fileName);
      final dlFile = await File('${Paths.doc}/$fileName').readAsBytes();
      if (!context.mounted) return;
      await BackupService.restoreData(context, dlFile);
    } catch (e, s) {
      context.showErrSheet(e, s, libL10n.restore);
      Loggers.app.warning('Download webdav backup failed', e, s);
    } finally {
      if (mounted) remoteLoading.value = false;
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
      context.showErrSheet(e, s, libL10n.upload);
      Loggers.app.warning('Upload webdav backup failed', e, s);
    } finally {
      if (mounted) remoteLoading.value = false;
    }
  }

  /// The synced backup as it is, or one of the versions LK Cloud kept of it.
  Future<void> _onTapLkcRestore(BuildContext context) async {
    if (!Lkc.client.signedIn) return Toast.show(libL10n.lkcNotSignedIn);
    await lkcOps.run('restore', () async {
      Directory? dir;
      try {
        // First: nothing of the account is listed while the password here does
        // not open its key.
        final SyncKeyHandle key;
        try {
          key = await lkcLog.key(create: false);
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
        final picked = await context.showPickSingleSheet(
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
        final bytes = await key.open(sealed: await File(path).readAsBytes());
        if (context.mounted) await BackupService.restoreData(context, bytes);
      } on SyncPasswordMismatch catch (e) {
        // Said as the card above says it: no error to report.
        Toast.show(syncFailureText(e) ?? l10n.syncPasswordMismatch);
      } on SyncSecretKeyMissing catch (e) {
        Toast.show(syncFailureText(e) ?? l10n.syncSecretKeyMissingDetail);
      } catch (e, s) {
        if (context.mounted) _showLkcErr(e, s, libL10n.restore);
        Loggers.app.warning('Restore LK Cloud backup failed', e, s);
      } finally {
        await dir?.delete(recursive: true);
      }
    });
  }

  Future<void> _onTapWebdavSetting(BuildContext context) async {
    final url = TextEditingController(text: SyncRemotes.webdavUrl);
    final user = TextEditingController(text: SyncRemotes.webdavUser);
    final pwd = TextEditingController(text: SyncRemotes.webdavPwd);
    final nodeUser = FocusNode();
    final nodePwd = FocusNode();
    final result = await context.showSheet<bool>(
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
            onSubmitted: (_) => context.popSheet(true),
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
        context.showErrSheet(e, s, 'Webdav');
      }
    }
    url.dispose();
    user.dispose();
    pwd.dispose();
    nodeUser.dispose();
    nodePwd.dispose();
  }

  void _onBulkImportServers(BuildContext context) async {
    final data = await context.showImportSheet(
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
      context.showErrSheet(e, s, libL10n.error);
      return;
    }

    try {
      text = text.trim();
      if (!await _routeImport(context, text)) return;
      final (spis, err) = await context.showLoadingSheet(
        fn: () => compute((String val) {
          final list = json.decode(val) as List;
          return [
            for (final e in list)
              (
                spi: Spi.fromJson(Map<String, dynamic>.from(e as Map)),
                pve: PveConfig.fromServerRecord(e),
              ),
          ];
        }, text),
      );
      if (err != null || spis == null) return;
      final sure = await context.showSheet<bool>(
        title: libL10n.import,
        child: Text(libL10n.askContinue('${spis.length} ${libL10n.server}')),
        actions: Btnx.oks,
      );
      if (sure == true) {
        final (suc, err) = await context.showLoadingSheet(
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
      if (context.mounted) context.showErrSheet(e, s, libL10n.import);
      Loggers.app.warning('Import servers failed', e, s);
    }
  }

  Future<bool> _ensureBakPwd(BuildContext context) async {
    final saved = await SecureStoreProps.bakPwd.read();
    if (saved != null && saved.isNotEmpty) return true;

    // Remote backups contain credentials and private keys, so encryption is
    // mandatory rather than an optional warning.
    final result = await context.showSheet<bool>(
      title: l10n.backupPassword,
      child: Text(l10n.remoteBackupPasswordRequired, style: UIs.textGrey),
      actions: [
        TextButton(
          onPressed: () => context.popSheet(false),
          child: Text(libL10n.cancel),
        ),
        TextButton(
          onPressed: () => context.popSheet(true),
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
