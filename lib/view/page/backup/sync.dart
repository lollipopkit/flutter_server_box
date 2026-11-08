part of '../backup.dart';

/// Where the backup syncs on its own: one at a time.
enum _SyncDest {
  off,
  icloud,
  webdav,
  lkc;

  /// The ones this build offers, [off] first.
  static List<_SyncDest> get offered => [
    off,
    if (isICloudSupported) icloud,
    webdav,
    if (Lkc.enabled) lkc,
  ];

  /// The one on now.
  static _SyncDest get current {
    if (isICloudSupported && PrefProps.icloudSync.get()) return icloud;
    if (PrefProps.webdavSync.get()) return webdav;
    if (Lkc.enabled && LkcSyncPrefs.enabled.get()) return lkc;
    return off;
  }

  /// What turns it on; none for [off].
  PrefPropDefault<bool>? get pref => switch (this) {
    off => null,
    icloud => PrefProps.icloudSync,
    webdav => PrefProps.webdavSync,
    lkc => LkcSyncPrefs.enabled,
  };

  /// Every change [current] follows.
  static Listenable get changes => Listenable.merge([
    for (final d in offered)
      if (d.pref case final p?) p.listenable(),
    if (Lkc.enabled) Lkc.client.user,
  ]);

  String get name => switch (this) {
    off => l10n.syncOff,
    icloud => 'iCloud',
    webdav => 'WebDAV',
    lkc => 'LK Cloud',
  };

  IconData get icon => switch (this) {
    off => Icons.sync_disabled,
    icloud => Icons.cloud,
    webdav => Icons.storage,
    lkc => Icons.cloud_sync,
  };

  /// Which one of its kind: the server, the account.
  String? get note => switch (this) {
    off || icloud => null,
    webdav => switch (SyncRemotes.webdavUrl) {
      final url? => Uri.tryParse(url)?.host ?? url,
      null => null,
    },
    lkc => Lkc.client.user.value?.name ?? libL10n.lkcNotSignedIn,
  };
}

/// The sync group: where it goes and how that went, what it carries, and the
/// one-off copies to a file or the clipboard.
extension _SyncWidgets on _BackupPageState {
  /// Beside each other where the pane has room for two columns.
  Widget get _buildSyncSection {
    return LayoutBuilder(
      builder: (context, box) {
        final pad = context.padBottom(UIs.roundRectCardPadding);
        if (box.maxWidth < _twoColumns) {
          return ListView(padding: pad, children: _syncTiles);
        }
        return SingleChildScrollView(
          padding: pad,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: _syncAutoTiles)),
              Expanded(child: Column(children: _syncOtherTiles)),
            ],
          ),
        );
      },
    );
  }

  static const _twoColumns = 720.0;

  List<Widget> get _syncTiles => [..._syncAutoTiles, ..._syncOtherTiles];

  List<Widget> get _syncAutoTiles => [
    CenterGreyTitle(l10n.syncAuto),
    ListenableBuilder(
      listenable: _destChanges,
      builder: (context, _) {
        final dest = _SyncDest.current;
        return Column(
          children: [
            _buildDestPicker(dest),
            if (dest != _SyncDest.off) _buildDestDetails(dest),
          ],
        );
      },
    ),
  ];

  List<Widget> get _syncOtherTiles => [
    CenterGreyTitle(libL10n.content),
    CardX(
      child: Column(
        children: [
          _buildBakPwd,
          _buildSyncedData,
        ],
      ),
    ),
    CenterGreyTitle(libL10n.manual),
    ListenableBuilder(
      listenable: Listenable.merge([_destChanges, remoteLoading, lkcLoading]),
      builder: (context, _) => _buildManual(_SyncDest.current),
    ),
  ];

  /// A file, the clipboard, and the remotes that are not the channel: one
  /// copy, either way, whatever syncs on its own.
  Widget _buildManual(_SyncDest channel) {
    return CardX(
      child: Column(
        children: [
          _manualRow(
            Icons.insert_drive_file_outlined,
            libL10n.file,
            onRestore: () => BackupService.restore(context, FileBackupSource()),
            action: libL10n.export,
            onAction: () => BackupService.backup(context, FileBackupSource()),
          ),
          _manualRow(
            Icons.content_paste,
            libL10n.clipboard,
            onRestore: () => BackupService.restore(context, ClipboardBackupSource()),
            action: libL10n.copy,
            onAction: () => BackupService.backup(context, ClipboardBackupSource()),
          ),
          if (isICloudSupported && channel != _SyncDest.icloud)
            _manualRow(
              _SyncDest.icloud.icon,
              _SyncDest.icloud.name,
              busy: remoteLoading.value,
              onRestore: _onTapIcloudRestore,
            ),
          if (_webdavSet && channel != _SyncDest.webdav)
            _manualRow(
              _SyncDest.webdav.icon,
              _SyncDest.webdav.name,
              busy: remoteLoading.value,
              onRestore: () => _onTapWebdavDl(context),
              action: libL10n.backup,
              onAction: () => _onTapWebdavUp(context),
            ),
          if (Lkc.enabled && Lkc.client.signedIn && channel != _SyncDest.lkc)
            _manualRow(
              _SyncDest.lkc.icon,
              _SyncDest.lkc.name,
              busy: lkcLoading.value,
              onRestore: () => _onTapLkcRestore(context),
            ),
        ],
      ),
    );
  }

  Widget _buildDestPicker(_SyncDest dest) {
    final primary = Theme.of(context).colorScheme.primary;
    return CardX(
      child: Builder(
        builder: (tile) => ListTile(
          leading: Icon(dest.icon, color: primary),
          title: Text(l10n.syncChannel),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dest.name, style: UIs.textGrey),
              const Icon(Icons.expand_more),
            ],
          ),
          onTap: () => showContextMenu(
            tile,
            [
              for (final d in _SyncDest.offered)
                ContextMenuAction(
                  text: d.name,
                  icon: d.icon,
                  note: d.note,
                  checked: d == dest,
                  onTap: () => _selectDest(d),
                ),
            ],
            at: contextMenuAnchorBelow(tile),
          ),
        ),
      ),
    );
  }

  Widget _buildDestDetails(_SyncDest dest) {
    final loading = dest == _SyncDest.lkc ? lkcLoading : remoteLoading;
    return CardX(
      child: Column(
        children: [
          _buildSyncStatus(dest),
          if (dest == _SyncDest.webdav)
            ListTile(
              title: Text(libL10n.server),
              subtitle: Text(
                [SyncRemotes.webdavUrl, SyncRemotes.webdavUser].nonNulls.join(' · '),
                style: UIs.textGrey,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _onTapWebdavSetting(context),
            ),
          if (dest == _SyncDest.lkc) ...[
            ListTile(
              title: Text(libL10n.lkcAccount),
              subtitle: Text(_SyncDest.lkc.note ?? '', style: UIs.textGrey),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => LkcAccountPage.route.go(context, LkcPageArgs(Lkc.client)),
            ),
            ListTile(
              title: Text(l10n.syncKeyRotate),
              trailing: const Icon(Icons.key),
              onTap: () => _onTapRotateSyncKey(context),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 7),
            child: loading.listenVal((busy) {
              if (busy) return const Align(alignment: Alignment.centerRight, child: SizedLoading.small);
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => _onTapDestRestore(dest), child: Text(libL10n.restore)),
                  if (dest == _SyncDest.webdav) ...[
                    UIs.width7,
                    FilledButton.tonal(
                      onPressed: () => _onTapWebdavUp(context),
                      child: Text(libL10n.backup),
                    ),
                  ],
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  /// How the last sync went, and when; the one thing to do about it where
  /// there is one (the password).
  Widget _buildSyncStatus(_SyncDest dest) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _syncing,
        bakSync.running,
        bakSync.lastFailure,
        SyncKey.passwordMismatch,
        BakSyncer.remoteTooNew,
        LogSync.tooNew,
        SegmentSync.tooNew,
      ]),
      builder: (context, _) {
        return FutureBuilder<bool>(
          future: dest == _SyncDest.icloud ? _icloudConflict : null,
          builder: (context, icloudStatus) {
            final scheme = Theme.of(context).colorScheme;
            final failure = bakSync.lastFailure.value;
            final at = bakSync.syncCheckpoint?.$3;
            final last = at == null ? null : l10n.syncLastAt(DateTime.fromMillisecondsSinceEpoch(at).ymdhms());
            // A word for the state; what it is about, or when it last went
            // well, under it.
            final (icon, color, title, detail, onTap) = switch (()) {
              // The last one's outcome is cleared as one starts: none to say
              // until it ends.
              _ when _syncing.value || bakSync.running.value => (
                Icons.sync,
                scheme.primary,
                l10n.syncStateRunning,
                last,
                null,
              ),
              _ when SyncKey.passwordMismatch.value.isNotEmpty => (
                Icons.key_off,
                scheme.error,
                l10n.syncStatePassword,
                l10n.syncPasswordMismatch,
                () => _onTapSetBakPwd(context),
              ),
              _ when BakSyncer.remoteTooNew.value != null || LogSync.tooNew.value || SegmentSync.tooNew.value => (
                Icons.system_update,
                Colors.orange,
                l10n.syncStateUpdate,
                l10n.syncRemoteTooNew,
                null,
              ),
              _ when failure != null => (
                Icons.warning_rounded,
                Colors.orange,
                l10n.syncStateFailed,
                syncFailureText(failure) ?? '$failure',
                null,
              ),
              _ when icloudStatus.data ?? false => (
                Icons.warning_rounded,
                Colors.orange,
                l10n.icloudBackupStateConflict,
                last,
                null,
              ),
              _ when last != null => (Icons.check_circle, Colors.green, l10n.syncDone, last, null),
              // Nothing synced yet, nor failed.
              _ => (Icons.sync, scheme.onSurfaceVariant, l10n.syncNow, null, _syncNow),
            };
            return ListTile(
              leading: Icon(icon, color: color),
              title: Text(title),
              subtitle: detail == null ? null : Text(detail, style: UIs.textGrey),
              onTap: onTap,
              trailing: _syncing.value || bakSync.running.value
                  ? SizedLoading.small
                  : IconButton(onPressed: _syncNow, icon: const Icon(Icons.sync), tooltip: l10n.syncNow),
            );
          },
        );
      },
    );
  }

  /// What the sync carries, switched in a sheet.
  Widget get _buildSyncedData {
    return ListTile(
      leading: const Icon(Icons.tune),
      title: Text(l10n.syncedData),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showRowsSheet<void>(
        context,
        rows: (_) => [
          for (final c in SyncCategory.values)
            if (c == SyncCategory.passphrases)
              Stores.setting.rememberKeyPassphrase.listenable().listenVal(
                (remember) => remember ? _syncCategoryTile(c) : UIs.placeholder,
              )
            else
              _syncCategoryTile(c),
        ],
      ),
    );
  }

  (IconData, String) _category(SyncCategory c) => switch (c) {
    SyncCategory.settings => (Icons.settings, libL10n.setting),
    SyncCategory.ai => (Icons.auto_awesome, libL10n.ai),
    SyncCategory.secrets => (Icons.password, l10n.syncSecrets),
    SyncCategory.passphrases => (Icons.key, l10n.keyPassphrases),
    SyncCategory.files => (Icons.folder, l10n.syncFiles),
    SyncCategory.benchmarks => (Icons.speed, l10n.benchmark),
  };

  Widget _syncCategoryTile(SyncCategory c) {
    final (icon, label) = _category(c);
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: StoreSwitch(prop: c.pref),
    );
  }

  Widget _manualRow(
    IconData icon,
    String title, {
    required VoidCallback onRestore,
    String? action,
    VoidCallback? onAction,
    bool busy = false,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: busy
          ? SizedLoading.small
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: onRestore, child: Text(libL10n.restore)),
                if (action != null && onAction != null) TextButton(onPressed: onAction, child: Text(action)),
              ],
            ),
    );
  }
}

extension _SyncActions on _BackupPageState {
  /// [to] on in place of the one on now, once it synced: a destination that
  /// cannot be reached, or whose key the password here does not open, is not
  /// switched to. Switching between two asks first.
  Future<void> _selectDest(_SyncDest to) async {
    if (_selectingDest) return;
    _selectingDest = true;
    try {
      await _switchDest(to);
    } finally {
      _selectingDest = false;
    }
  }

  Future<void> _switchDest(_SyncDest to) async {
    final from = _SyncDest.current;
    if (to == from) return;
    if (from != _SyncDest.off && to != _SyncDest.off) {
      final ok = await context.showRoundDialog<bool>(
        title: l10n.switchTo(to.name),
        child: Text(l10n.syncSwitchBody(from.name)),
        actions: Btnx.cancelOk,
      );
      if (ok != true || !mounted) return;
    }
    if (to != _SyncDest.off && !await _enable(to)) return;
    // The page may be gone; the choice stands.
    for (final d in _SyncDest.offered) {
      final p = d.pref;
      if (p != null && d != to) await p.set(false);
    }
    await to.pref?.set(true);
  }

  /// Synced once with [to], as the first sync there.
  Future<bool> _enable(_SyncDest to) async {
    if (!await _ensureBakPwd(context)) return false;
    if (!mounted) return false;
    switch (to) {
      case _SyncDest.off:
        return true;
      case _SyncDest.icloud:
        _syncing.value = true;
        try {
          await bakSync.sync(rs: icloud, throttleMilli: 0);
        } finally {
          if (mounted) _syncing.value = false;
        }
        _refreshIcloudStatus();
        return _syncWent();
      case _SyncDest.webdav:
        if (!_webdavSet) await _onTapWebdavSetting(context);
        if (!_webdavSet) {
          Toast.show(l10n.webdavSettingEmpty);
          return false;
        }
        remoteLoading.value = true;
        try {
          await bakSync.sync(rs: SyncRemotes.webdav, throttleMilli: 0);
        } finally {
          if (mounted) remoteLoading.value = false;
        }
        return _syncWent();
      case _SyncDest.lkc:
        if (!Lkc.client.signedIn) {
          unawaited(LkcAccountPage.route.go(context, LkcPageArgs(Lkc.client)));
          return false;
        }
        lkcLoading.value = true;
        try {
          final storage = LkcSyncPrefs.storage;
          // A checkpoint left from an earlier time on would skip the write
          // this needs to see.
          await BakSyncer.forgetCheckpoint();
          final before = storage.writtenTag(Miscs.bakFileName);
          await bakSync.sync(rs: storage, throttleMilli: 0);
          // A cycle that could not read the remote returns without writing,
          // and says so only in the log.
          final after = storage.writtenTag(Miscs.bakFileName);
          if (after == null || after == before) {
            if (_syncWent()) Toast.show(libL10n.fail);
            return false;
          }
          return true;
        } catch (e, s) {
          if (mounted) _showLkcErr(e, s, libL10n.sync);
          return false;
        } finally {
          if (mounted) lkcLoading.value = false;
        }
    }
  }

  bool get _webdavSet =>
      SyncRemotes.webdavUrl != null && SyncRemotes.webdavUser != null && SyncRemotes.webdavPwd != null;

  /// The backup and the log, now; what went wrong is the status line's.
  Future<void> _syncNow() async {
    if (_syncing.value) return;
    _syncing.value = true;
    try {
      await bakSync.sync(throttleMilli: 0);
      await Future.wait([LkcLogSync.sync(), FileLogSync.sync()]);
    } catch (e, s) {
      Loggers.app.warning('Sync now', e, s);
    } finally {
      if (mounted) _syncing.value = false;
      _refreshIcloudStatus();
    }
  }

  Future<void> _onTapDestRestore(_SyncDest dest) => switch (dest) {
    _SyncDest.off => Future.value(),
    _SyncDest.icloud => _onTapIcloudRestore(),
    _SyncDest.webdav => _onTapWebdavDl(context),
    _SyncDest.lkc => _onTapLkcRestore(context),
  };

  /// The backup iCloud holds, as it is.
  Future<void> _onTapIcloudRestore() async {
    remoteLoading.value = true;
    Directory? dir;
    try {
      if (!await icloud.exists(Paths.bakName)) return Toast.show(l10n.dirEmpty);
      dir = await Directory.systemTemp.createTemp('sb-icloud-restore-');
      final path = '${dir.path}/${Paths.bakName}';
      await icloud.download(relativePath: Paths.bakName, localPath: path);
      final bytes = await File(path).readAsBytes();
      if (mounted) await BackupService.restoreData(context, bytes);
    } catch (e, s) {
      if (mounted) context.showErrDialog(e, s, libL10n.restore);
      Loggers.app.warning('Restore iCloud backup failed', e, s);
    } finally {
      await dir?.delete(recursive: true);
      if (mounted) remoteLoading.value = false;
    }
  }
}
