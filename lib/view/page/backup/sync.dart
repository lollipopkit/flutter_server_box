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
    webdav => _webdavHostLabel(SyncRemotes.webdavUrl),
    lkc => Lkc.client.user.value?.name ?? libL10n.lkcNotSignedIn,
  };
}

enum _WebdavEditOutcome { saved, removed }

String? _webdavHostLabel(String? url) {
  if (url == null || url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return url;
  final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
  return path.isEmpty ? uri.host : '${uri.host}$path';
}

bool _isSyncKeyOrVersionFailure(Object e) =>
    e is WrongPasswordException ||
    e is SyncPasswordMismatch ||
    e is SyncPasswordMissing ||
    e is RemoteBackupPasswordMissing ||
    e is SchemaTooNewException ||
    e is SyncLogTooNew;

/// The sync group: where it goes and how that went, what it carries, and the
/// one-off copies to a file or the clipboard.
extension _SyncWidgets on _BackupPageState {
  List<Widget> get _syncGroups => [
    _buildSyncAutoGroup,
    _buildSyncContentGroup,
    _buildSyncManualGroup,
  ];

  Widget get _buildSyncAutoGroup {
    return ListenableBuilder(
      listenable: _destChanges,
      builder: (context, _) {
        final dest = _SyncDest.current;
        return SettingsGroupView(
          SettingsGroup(l10n.syncAuto, [
            SettingsRow(l10n.syncChannel, () => _buildDestPicker(dest)),
            if (dest != _SyncDest.off) ..._buildDestDetailRows(dest),
          ]),
        );
      },
    );
  }

  Widget get _buildSyncContentGroup {
    return SettingsGroupView(
      SettingsGroup(libL10n.content, [
        SettingsRow(l10n.backupPassword, () => _buildBakPwd),
        SettingsRow(l10n.syncedData, () => _buildSyncedData),
      ]),
    );
  }

  /// A file, the clipboard, and the remotes that are not the channel: one
  /// copy, either way, whatever syncs on its own.
  Widget get _buildSyncManualGroup {
    return ListenableBuilder(
      listenable: _manualChanges,
      builder: (context, _) {
        final channel = _SyncDest.current;
        return SettingsGroupView(
          SettingsGroup(libL10n.manual, [
            SettingsRow(
              libL10n.file,
              () => _manualRow(
                Icons.insert_drive_file_outlined,
                libL10n.file,
                onRestore: () => BackupService.restore(context, FileBackupSource()),
                action: libL10n.export,
                onAction: () => BackupService.backup(context, FileBackupSource()),
              ),
            ),
            SettingsRow(
              libL10n.clipboard,
              () => _manualRow(
                Icons.content_paste,
                libL10n.clipboard,
                onRestore: () => BackupService.restore(context, ClipboardBackupSource()),
                action: libL10n.copy,
                onAction: () => BackupService.backup(context, ClipboardBackupSource()),
              ),
            ),
            if (isICloudSupported && channel != _SyncDest.icloud)
              SettingsRow(
                _SyncDest.icloud.name,
                () => _manualRow(
                  _SyncDest.icloud.icon,
                  _SyncDest.icloud.name,
                  busy: remoteLoading.value,
                  onRestore: _onTapIcloudRestore,
                ),
              ),
            if (SyncRemotes.hasWebdav && channel != _SyncDest.webdav)
              SettingsRow(
                _SyncDest.webdav.name,
                () => _manualRow(
                  _SyncDest.webdav.icon,
                  _SyncDest.webdav.name,
                  subtitle: _webdavSubtitle,
                  onTap: () => _onTapWebdavSetting(context),
                  busy: remoteLoading.value,
                  onRestore: () => _onTapWebdavDl(context),
                  action: libL10n.backup,
                  onAction: () => _onTapWebdavUp(context),
                ),
              ),
            if (Lkc.enabled && Lkc.client.signedIn && channel != _SyncDest.lkc)
              SettingsRow(
                _SyncDest.lkc.name,
                () => _manualRow(
                  _SyncDest.lkc.icon,
                  _SyncDest.lkc.name,
                  busy: lkcLoading.value,
                  onRestore: () => _onTapLkcRestore(context),
                ),
              ),
          ]),
        );
      },
    );
  }

  Widget _buildDestPicker(_SyncDest dest) {
    final scheme = Theme.of(context).colorScheme;
    List<ContextMenuAction> actions() => [
      for (final d in _SyncDest.offered)
        ContextMenuAction(
          text: d.name,
          icon: d.icon,
          note: d.note,
          checked: d == dest,
          onTap: () => _selectDest(d),
        ),
    ];
    return ListTile(
      leading: Icon(
        dest.icon,
        color: dest == _SyncDest.off ? null : scheme.primary,
      ),
      title: Text(l10n.syncChannel),
      trailing: IconTheme.merge(
        key: _destAnchorKey,
        data: IconThemeData(color: scheme.onSurfaceVariant),
        child: ContextMenuButton.value(
          Text(
            dest.name,
            style: dest == _SyncDest.off
                ? UIs.text15.copyWith(color: UIs.textGrey.color)
                : UIs.text15,
          ),
        ),
      ),
      onTap: () {
        final anchor = _destAnchorKey.currentContext ?? context;
        showContextMenu(
          anchor,
          actions(),
          at: contextMenuAnchorBelow(anchor),
        );
      },
    );
  }

  List<SettingsRow> _buildDestDetailRows(_SyncDest dest) {
    final loading = dest == _SyncDest.lkc ? lkcLoading : remoteLoading;
    return [
      SettingsRow(l10n.syncNow, () => _buildSyncStatus(dest)),
      if (dest == _SyncDest.webdav)
        SettingsRow(
          libL10n.server,
          () => ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(libL10n.server),
            subtitle: Text(
              _webdavSubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: UIs.textGrey,
            ),
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: () => _editWebdavAndResync(context),
          ),
        ),
      if (dest == _SyncDest.lkc) ...[
        SettingsRow(
          libL10n.lkcAccount,
          () => ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(libL10n.lkcAccount),
            subtitle: Text(_SyncDest.lkc.note ?? '', style: UIs.textGrey),
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: () => LkcAccountPage.route.go(context, LkcPageArgs(Lkc.client)),
          ),
        ),
        SettingsRow(
          l10n.syncKeyRotate,
          () => ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text(l10n.syncKeyRotate),
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: () => _onTapRotateSyncKey(context),
          ),
        ),
      ],
      SettingsRow(
        libL10n.restore,
        () => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          child: loading.listenVal((busy) {
            if (busy) {
              return const Align(
                alignment: Alignment.centerRight,
                child: SizedLoading.small,
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _onTapDestRestore(dest),
                  child: Text(libL10n.restore),
                ),
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
      ),
    ];
  }

  /// How the last sync went, and when; the one thing to do about it where
  /// there is one (the password).
  Widget _buildSyncStatus(_SyncDest dest) {
    return ListenableBuilder(
      listenable: _statusChanges,
      builder: (context, _) {
        return FutureBuilder<bool>(
          future: dest == _SyncDest.icloud ? _icloudConflict : null,
          builder: (context, icloudStatus) {
            final scheme = Theme.of(context).colorScheme;
            final failure = bakSync.lastFailure.value ??
                switch (dest) {
                  _SyncDest.lkc => lkcLog.lastFailure.value,
                  _SyncDest.icloud || _SyncDest.webdav => fileLog.lastFailure.value,
                  _SyncDest.off => null,
                };
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
              _ when SyncKeyring.passwordMismatch.value.isNotEmpty => (
                Icons.key_off,
                scheme.error,
                l10n.syncStatePassword,
                l10n.syncPasswordMismatch,
                () => _onTapSetBakPwd(context),
              ),
              _ when SchemaVersion.readsAhead || BakSyncer.remoteTooNew.value != null || lkcLog.tooNew.value || fileLog.tooNew.value => (
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
                dest == _SyncDest.webdav
                    ? () => _editWebdavAndResync(
                        context,
                        initialError: syncFailureText(failure) ?? '$failure',
                      )
                    : null,
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
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => showRowsSheet<void>(
        context,
        title: l10n.syncedData,
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
    String? subtitle,
    VoidCallback? onTap,
    required VoidCallback onRestore,
    String? action,
    VoidCallback? onAction,
    bool busy = false,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null || subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: UIs.textGrey,
            ),
      onTap: busy ? null : onTap,
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
      final ok = await context.showSheet<bool>(
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
        final prevFailure = bakSync.lastFailure.value;
        final prevTooNew = BakSyncer.remoteTooNew.value;
        final triedIds = <String>{};
        void rollbackAttempt() {
          if (_SyncDest.current == _SyncDest.webdav) return;
          for (final id in triedIds) {
            SyncKeyring.release(id);
          }
          bakSync.lastFailure.value = prevFailure;
          BakSyncer.remoteTooNew.value = prevTooNew;
        }
        if (!SyncRemotes.hasWebdav) {
          final outcome = await _onTapWebdavSetting(context);
          if (!mounted || outcome != _WebdavEditOutcome.saved || !SyncRemotes.hasWebdav) {
            return false;
          }
        }
        while (mounted && SyncRemotes.hasWebdav) {
          if (fileLog.storeIdOf(SyncRemotes.webdav) case final id?) {
            triedIds.add(id);
          }
          Object? err;
          remoteLoading.value = true;
          try {
            await bakSync.sync(rs: SyncRemotes.webdav, throttleMilli: 0);
            err = bakSync.lastFailure.value;
          } catch (e, s) {
            Loggers.app.warning('Enable WebDAV sync failed', e, s);
            bakSync.lastFailure.value = e;
            err = e;
          } finally {
            if (mounted) remoteLoading.value = false;
          }
          if (err == null) return true;
          if (_isSyncKeyOrVersionFailure(err)) {
            _syncWent();
            rollbackAttempt();
            return false;
          }
          if (!mounted) {
            rollbackAttempt();
            return false;
          }
          final errText = syncFailureText(err) ?? '$err';
          final edit = await context.showSheet<bool>(
            title: l10n.syncStateFailed,
            child: Text(errText),
            actions: [
              TextButton(
                onPressed: () => context.popSheet(false),
                child: Text(libL10n.close),
              ),
              FilledButton.tonal(
                onPressed: () => context.popSheet(true),
                child: Text(libL10n.edit),
              ),
            ],
          );
          if (edit != true || !mounted) {
            rollbackAttempt();
            return false;
          }
          final outcome = await _onTapWebdavSetting(context, initialError: errText);
          if (outcome != _WebdavEditOutcome.saved) {
            rollbackAttempt();
            return false;
          }
        }
        rollbackAttempt();
        return false;
      case _SyncDest.lkc:
        if (!Lkc.client.signedIn) {
          unawaited(LkcAccountPage.route.go(context, LkcPageArgs(Lkc.client)));
          return false;
        }
        final ok = await lkcOps.run('enable-sync', () async {
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
          }
        });
        return ok == true;
    }
  }

  String get _webdavSubtitle => [SyncRemotes.webdavUrl, SyncRemotes.webdavUser].nonNulls.join(' · ');

  Future<void> _editWebdavAndResync(
    BuildContext context, {
    String? initialError,
  }) async {
    final outcome = await _onTapWebdavSetting(context, initialError: initialError);
    if (mounted && outcome == _WebdavEditOutcome.saved && _SyncDest.current == _SyncDest.webdav) {
      unawaited(_syncNow());
    }
  }

  /// The backup and the log, now; what went wrong is the status line's.
  Future<void> _syncNow() async {
    if (_syncing.value) return;
    _syncing.value = true;
    try {
      await bakSync.sync(throttleMilli: 0);
      await Future.wait([lkcLog.sync(), fileLog.sync()]);
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
      if (mounted) context.showErrSheet(e, s, libL10n.restore);
      Loggers.app.warning('Restore iCloud backup failed', e, s);
    } finally {
      await dir?.delete(recursive: true);
      if (mounted) remoteLoading.value = false;
    }
  }
}
