import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/shares.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/system_user.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/service/shares_manager.dart';
import 'package:server_box/data/service/storage_manager.dart';
import 'package:server_box/data/service/user_manager.dart';

final class SharesPage extends ConsumerStatefulWidget {
  const SharesPage({super.key, required this.args});

  final SpiRequiredArgs args;

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: SharesPage.new,
    path: '/shares',
  );

  @override
  ConsumerState<SharesPage> createState() => _SharesPageState();
}

enum _SharesTab { smb, nfs }

final class _SharesPageState extends ConsumerState<SharesPage> {
  late final _provider = serverProvider(widget.args.spi.id);
  SharesView? _view;
  ShareConnections? _connections;
  List<ServerUser> _users = [];
  int _uidMin = 1000;
  List<String> _folders = [];
  _SharesTab _tab = _SharesTab.smb;
  bool _busy = false;
  bool _unsupported = false;
  bool _connectionsLocked = false;
  String? _failure;
  String? _failureDetail;
  String? _passwordUser;

  void _rebuild(VoidCallback update) {
    if (mounted) setState(update);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  @override
  Widget build(BuildContext context) {
    final linux = ref.watch(
      _provider.select((state) => state.status.system == SystemType.linux),
    );
    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(up: l10n.sharingTitle, down: widget.args.spi.name),
        actions: [
          if (isDesktop)
            Btn.icon(
              text: libL10n.refresh,
              icon: const Icon(Icons.refresh, size: 18),
              onTap: _busy ? null : _refresh,
            ),
        ],
      ),
      body: !linux
          ? PageIssueView(
              title: libL10n.unsupported,
              explain: l10n.sharingConnectionsLinuxOnly,
              icon: Icons.not_interested,
              onRetry: _refresh,
            )
          : RefreshIndicator(onRefresh: _refresh, child: _body()),
      floatingActionButton: _view != null &&
              !_busy &&
              ((_tab == _SharesTab.smb && _view!.tools.contains('smbd')) ||
                  (_tab == _SharesTab.nfs && _view!.tools.contains('exportfs')))
          ? FloatingActionButton(
              tooltip: _tab == _SharesTab.smb
                  ? l10n.sharingAddShare
                  : l10n.sharingAddExport,
              onPressed: _tab == _SharesTab.smb ? _addSmb : _addNfs,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

extension on _SharesPageState {
  Widget _body() {
    if (_unsupported) {
      return _issue(
        title: libL10n.unsupported,
        explain: l10n.sharingConnectionsLinuxOnly,
      );
    }
    if (_failure case final failure?) {
      return _issue(title: libL10n.fail, detail: _failureDetail ?? failure);
    }
    final view = _view;
    if (view == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [SizedBox(height: 280, child: UIs.centerLoading)],
      );
    }
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 8, 13, 13),
            child: SegmentedTabs<_SharesTab>(
              expand: true,
              segments: [
                SegmentedTab(value: _SharesTab.smb, label: l10n.sharingSmb),
                SegmentedTab(value: _SharesTab.nfs, label: l10n.sharingNfs),
              ],
              selected: _tab,
              onSelected: (tab) => _rebuild(() => _tab = tab),
            ),
          ),
        ),
        if (_busy) const SliverToBoxAdapter(child: LinearProgressIndicator()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(13, 0, 13, 90),
          sliver: SliverList.list(
            children: _tab == _SharesTab.smb
                ? _smbContent(view)
                : _nfsContent(view),
          ),
        ),
      ],
    );
  }

  Widget _issue({String? explain, String? detail, required String title}) =>
      ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * .65,
            child: PageIssueView(
              title: title,
              explain: explain,
              detail: detail,
              icon: Icons.error_outline,
              onRetry: _refresh,
            ),
          ),
        ],
      );

  List<Widget> _smbContent(SharesView view) {
    if (!view.tools.contains('smbd')) {
      return [
        _notice(
          l10n.sharingNoSamba,
          l10n.sharingInstallSamba,
          () => _install(nfs: false),
        ),
      ];
    }
    return [
      CardX(
        margin: const EdgeInsets.only(bottom: 11),
        child: Column(
          children: [
            ListTile(
              title: Text(l10n.sharingService),
              subtitle: Text('Samba'),
              trailing: _serviceBadge(view.smbActive),
            ),
            if (!view.tools.contains('smbpasswd'))
              ListTile(
                title: Text(l10n.sharingPasswordsBody),
                trailing: const Icon(Icons.info_outline),
              )
            else
              _smbPasswordRow(),
          ],
        ),
      ),
      if (view.smb.isEmpty)
        _empty(Icons.folder_shared, l10n.sharingNoShares)
      else
        for (final share in view.smb) _smbCard(share),
      _connectionsCard(),
    ];
  }

  List<Widget> _nfsContent(SharesView view) {
    if (!view.tools.contains('exportfs')) {
      return [
        _notice(
          l10n.sharingNoNfs,
          l10n.sharingInstallNfs,
          () => _install(nfs: true),
        ),
      ];
    }
    return [
      CardX(
        margin: const EdgeInsets.only(bottom: 11),
        child: ListTile(
          title: Text(l10n.sharingNfsServer),
          subtitle: Text(l10n.sharingService),
          trailing: _serviceBadge(view.nfsActive),
        ),
      ),
      if (view.nfs.isEmpty)
        _empty(Icons.lan, l10n.sharingNoExports)
      else
        for (final export in view.nfs) _nfsCard(export),
      _connectionsCard(nfs: true),
    ];
  }

  Widget _notice(String text, String action, VoidCallback onTap) => CardX(
    margin: const EdgeInsets.only(bottom: 11),
    child: ListTile(
      title: Text(text),
      trailing: TextButton.icon(
        onPressed: _busy ? null : onTap,
        icon: const Icon(Icons.download, size: 17),
        label: Text(action),
      ),
    ),
  );

  Widget _empty(IconData icon, String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Column(
      children: [Icon(icon, size: 45, color: UIs.textGrey.color), Text(title)],
    ),
  );

  Widget _serviceBadge(bool running) => Chip(
    label: Text(running ? l10n.sharingRunning : l10n.sharingStopped),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Widget _smbCard(SmbShare share) => CardX(
    margin: const EdgeInsets.only(bottom: 11),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(share.name),
          subtitle: Text(share.path, style: const TextStyle(fontFamily: 'monospace')),
          trailing: share.managed
              ? null
              : Chip(
                  label: Text(l10n.sharingElsewhere),
                  visualDensity: VisualDensity.compact,
                ),
        ),
        if (share.comment?.isNotEmpty == true)
          ListTile(dense: true, title: Text(share.comment!)),
        ListTile(
          dense: true,
          title: Text(_smbAccess(share)),
        ),
        if (share.managed)
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _removeSmb(share),
                child: Text(l10n.sharingRemove),
              ),
              TextButton(
                onPressed: _busy ? null : () => _editSmb(share),
                child: Text(l10n.sharingEdit),
              ),
            ],
          ),
      ],
    ),
  );

  Widget _nfsCard(NfsExport export) => CardX(
    margin: const EdgeInsets.only(bottom: 11),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(export.path, style: const TextStyle(fontFamily: 'monospace')),
          trailing: export.managed
              ? null
              : Chip(
                  label: Text(l10n.sharingElsewhere),
                  visualDensity: VisualDensity.compact,
                ),
        ),
        for (final client in export.clients)
          ListTile(
            dense: true,
            title: Text(client.host, style: const TextStyle(fontFamily: 'monospace')),
            subtitle: Text(_clientText(client)),
          ),
        if (export.managed)
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _removeNfs(export),
                child: Text(l10n.sharingRemove),
              ),
              TextButton(
                onPressed: _busy ? null : () => _editNfs(export),
                child: Text(l10n.sharingEdit),
              ),
            ],
          ),
      ],
    ),
  );

  Widget _smbPasswordRow() {
    final accounts = _users
        .where((user) => !user.isSystem(_uidMin) && !user.isRoot)
        .map((user) => user.name)
        .toList();
    final user = _passwordUser ?? accounts.firstOrNull ?? '';
    return ListTile(
      title: Text(l10n.sharingPasswords),
      subtitle: Text(l10n.sharingPasswordsBody),
      trailing: SizedBox(
        width: 190,
        child: Row(
          children: [
            Expanded(
              child: accounts.isEmpty
                  ? const SizedBox.shrink()
                  : DropdownButton<String>(
                      isExpanded: true,
                      value: accounts.contains(user) ? user : accounts.first,
                      items: [
                        for (final account in accounts)
                          DropdownMenuItem(value: account, child: Text(account)),
                      ],
                      onChanged: (value) => _rebuild(() => _passwordUser = value),
                    ),
            ),
            IconButton(
              tooltip: l10n.sharingSetPassword,
              icon: const Icon(Icons.password),
              onPressed: _busy || !viewHas('smbpasswd') || accounts.isEmpty
                  ? null
                  : () => _setPassword(user),
            ),
          ],
        ),
      ),
    );
  }

  bool viewHas(String tool) => _view?.tools.contains(tool) ?? false;

  Widget _connectionsCard({bool nfs = false}) {
    final connections = _connections;
    final locked = _connectionsLocked;
    final labels = nfs
        ? [if (connections != null) ...connections.nfs]
        : [
            if (connections != null)
              for (final item in connections.smb)
                '${item.share} · ${item.user ?? '—'} · ${item.machine}',
          ];
    return CardX(
      margin: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(l10n.sharingConnectedNow),
            trailing: IconButton(
              tooltip: locked
                  ? l10n.sharingShowConnections
                  : libL10n.refresh,
              icon: Icon(locked ? Icons.lock_outline : Icons.refresh),
              onPressed: _busy ? null : _readConnections,
            ),
          ),
          if (locked)
            ListTile(
              title: Text(l10n.sharingShowConnectionsBody),
              trailing: TextButton(
                onPressed: _busy ? null : _readConnections,
                child: Text(l10n.sharingShowConnections),
              ),
            )
          else if (connections != null && labels.isEmpty)
            ListTile(title: Text(l10n.sharingNobodyConnected))
          else
            for (final label in labels) ListTile(dense: true, title: Text(label)),
        ],
      ),
    );
  }

  String _smbAccess(SmbShare share) => [
    share.readOnly ? l10n.sharingReadOnly : l10n.sharingReadWrite,
    if (share.guest) l10n.sharingGuest,
    if (share.timeMachine) l10n.sharingTimeMachine,
    if (share.recycle) l10n.sharingRecycle,
    if (share.users.isNotEmpty) share.users.join(', '),
  ].join(' · ');

  String _clientText(NfsClient client) => [
    client.readOnly ? l10n.sharingReadOnly : l10n.sharingReadWrite,
    switch (client.squash) {
      'all' => l10n.sharingSquashAll,
      'none' => l10n.sharingSquashNone,
      _ => l10n.sharingSquashRoot,
    },
    ...client.options,
  ].join(' · ');
}

extension on _SharesPageState {
  Future<ServerExec> _exec() => ref.read(_provider.notifier).ensureExec();

  Future<void> _refresh() async {
    if (_busy || !mounted) return;
    _rebuild(() {
      _busy = true;
      _failure = null;
      _failureDetail = null;
      _unsupported = false;
    });
    try {
      final view = await SharesManager.read(await _exec());
      if (!mounted) return;
      _rebuild(() => _view = view);
      unawaited(_loadUsers());
      unawaited(_loadFolders());
      if (view.tools.contains('smbd') || view.tools.contains('exportfs')) {
        unawaited(_readConnections(quiet: true));
      }
    } catch (e, s) {
      Loggers.app.warning('Read shares on ${widget.args.spi.id}', e, s);
      if (mounted) _rebuild(() => _failure = '$e');
    } finally {
      if (mounted) _rebuild(() => _busy = false);
    }
  }

  Future<void> _loadUsers() async {
    try {
      final users = await UserManager.list(await _exec());
      if (mounted) {
        _rebuild(() {
          _users = users.users;
          _uidMin = users.uidMin;
        });
      }
    } catch (e, s) {
      Loggers.app.warning('Read users for shares on ${widget.args.spi.id}', e, s);
    }
  }

  Future<void> _loadFolders() async {
    try {
      final storage = await StorageManager.view(await _exec());
      final system = storage.system.toSet();
      final folders = <String>{
        for (final device in storage.devices)
          if (!system.contains(device.path))
            for (final path in device.mountpoints)
              if (path.startsWith('/') &&
                  path != '/' &&
                  path != '/boot' &&
                  path != '/boot/efi')
                path,
      }.toList();
      if (mounted) _rebuild(() => _folders = folders);
    } catch (e, s) {
      Loggers.app.warning('Read mounted folders on ${widget.args.spi.id}', e, s);
    }
  }

  Future<void> _readConnections({bool quiet = false}) async {
    if (quiet) {
      try {
        final connections = await SharesManager.connections(
          await _exec(),
          isRoot: widget.args.spi.isRoot,
        );
        if (mounted) {
          _rebuild(() {
            _connections = connections;
            _connectionsLocked = false;
          });
        }
      } on SharesManagerException catch (e) {
        if (mounted && e.code == 'sudo_rejected') {
          _rebuild(() => _connectionsLocked = true);
        }
      } catch (e, s) {
        Loggers.app.warning('Read share connections on ${widget.args.spi.id}', e, s);
      }
      return;
    }
    final outcome = await _withSudo<ShareConnections>(
      (exec, password) => SharesManager.connections(
        exec,
        isRoot: widget.args.spi.isRoot,
        password: password,
      ),
    );
    if (outcome.value case final connections?) {
      if (mounted) {
        _rebuild(() {
          _connections = connections;
          _connectionsLocked = false;
        });
      }
    } else if (outcome.error?.code == 'sudo_cancelled' ||
        outcome.error?.code == 'sudo_rejected') {
      if (mounted) _rebuild(() => _connectionsLocked = true);
    } else if (outcome.error != null) {
      _showShareError(outcome.error!);
    }
  }

  Future<_ShareResult<T>> _withSudo<T>(
    Future<T> Function(ServerExec exec, String? password) run, {
    bool quiet = false,
  }) async {
    try {
      var finalError = <SharesManagerException>[];
      final result = await SudoPassword.retry<_ShareAttempt<T>>(
        context,
        widget.args.spi.id,
        label: widget.args.spi.ssh?.user,
        attempt: (password) async {
          try {
            return _ShareAttempt.value(await run(await _exec(), password));
          } on SharesManagerException catch (e) {
            finalError = [e];
            return _ShareAttempt.failure(e);
          }
        },
        rejected: (attempt) => attempt.error?.code == 'sudo_rejected',
      );
      if (result?.value case final value?) return _ShareResult.value(value);
      final error = result?.error ?? finalError.firstOrNull;
      if (error != null) return _ShareResult.failure(error);
      return const _ShareResult.failure(SharesManagerException('sudo_cancelled'));
    } catch (e, s) {
      Loggers.app.warning('Privileged share action on ${widget.args.spi.id}', e, s);
      return _ShareResult.failure(
        SharesManagerException('failed', detail: '$e'),
      );
    }
  }

  Future<void> _write<T>(Future<T> Function(ServerExec, String?) action) async {
    if (_busy) return;
    _rebuild(() => _busy = true);
    try {
      final outcome = await _withSudo<bool>((exec, password) async {
        await action(exec, password);
        return true;
      });
      if (outcome.value == true) {
        if (mounted) {
          Toast.success(libL10n.success);
          _rebuild(() => _busy = false);
        }
        await _refresh();
      } else if (outcome.error?.code != 'sudo_cancelled') {
        _showShareError(outcome.error!);
      }
    } finally {
      if (mounted) _rebuild(() => _busy = false);
    }
  }

  void _showShareError(SharesManagerException error) {
    final message = switch (error.code) {
      'sudo_rejected' => l10n.virtErrSudoRejected,
      'notAFolder' => l10n.sharingNotAFolder(error.path ?? ''),
      'refused' => l10n.sharingRefused(error.detail ?? ''),
      'duplicate' => l10n.sharingDuplicate,
      'invalidName' => l10n.sharingInvalidName,
      'invalidPath' => l10n.sharingInvalidPath,
      'invalidUser' || 'invalidClient' => l10n.sharingInvalidClient,
      'invalidSquash' || 'invalidComment' => l10n.sharingInvalidPath,
      'invalidPassword' => l10n.sharingInvalidPassword,
      _ => error.detail ?? error.code,
    };
    Toast.error(message);
  }

  Future<void> _install({required bool nfs}) async {
    final ok = await _confirm(
      nfs ? l10n.sharingInstallNfs : l10n.sharingInstallSamba,
      nfs ? l10n.sharingInstallNfsBody : l10n.sharingInstallSambaBody,
    );
    if (!ok || !mounted) return;
    await _write<void>(
      (exec, password) => SharesManager.install(
        exec,
        nfs: nfs,
        isRoot: widget.args.spi.isRoot,
        password: password,
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _removeSmb(SmbShare share) async {
    final ok = await _confirm(
      l10n.sharingRemove,
      l10n.sharingRemoveSmbBody(share.name),
    );
    if (!ok || !mounted) return;
    await _write(
      (exec, password) => SharesManager.setSmb(
        exec,
        _managedSmb(_view!.smb.where((item) => item.name != share.name).toList()),
        isRoot: widget.args.spi.isRoot,
        password: password,
      ),
    );
  }

  Future<void> _removeNfs(NfsExport export) async {
    final ok = await _confirm(
      l10n.sharingRemove,
      l10n.sharingRemoveNfsBody(export.path),
    );
    if (!ok || !mounted) return;
    await _write(
      (exec, password) => SharesManager.setNfs(
        exec,
        _view!.nfs.where((item) => item.path != export.path).toList(),
        isRoot: widget.args.spi.isRoot,
        password: password,
      ),
    );
  }

  Future<void> _setPassword(String user) async {
    final password = TextEditingController();
    final repeated = TextEditingController();
    final ok = await context.showRoundDialog<bool>(
      title: l10n.sharingSetPassword,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Input(
            controller: password,
            label: l10n.sharingNewPassword,
            obscureText: true,
          ),
          Input(
            controller: repeated,
            label: l10n.sharingNewPasswordAgain,
            obscureText: true,
          ),
        ],
      ),
      actions: Btnx.cancelOk,
    );
    final value = password.text;
    final matches = value == repeated.text;
    _disposeLater([password, repeated]);
    if (ok != true || !mounted) return;
    if (!matches || value.isEmpty) {
      Toast.error(matches ? l10n.sharingInvalidPassword : l10n.sharingPasswordsDiffer);
      return;
    }
    await _write<void>(
      (exec, sudoPassword) => SharesManager.setSmbPassword(
        exec,
        user,
        value,
        isRoot: widget.args.spi.isRoot,
        sudoPassword: sudoPassword,
      ),
    );
  }

  Future<void> _addSmb() => _editSmb();

  Future<void> _editSmb([SmbShare? original]) async {
    final name = TextEditingController(text: original?.name ?? '');
    final path = TextEditingController(text: original?.path ?? '/mnt/');
    final comment = TextEditingController(text: original?.comment ?? '');
    var readOnly = original?.readOnly ?? false;
    var guest = original?.guest ?? false;
    var timeMachine = original?.timeMachine ?? false;
    var recycle = original?.recycle ?? false;
    final users = [...?original?.users];
    final ok = await context.showRoundDialog<bool>(
      title: original == null ? l10n.sharingAddShare : l10n.sharingEdit,
      child: StatefulBuilder(
        builder: (context, setDialogState) => SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Input(controller: name, label: l10n.storageName),
                Input(
                  controller: path,
                  label: l10n.sharingFolder,
                  hint: l10n.sharingFolderHint,
                  suggestion: false,
                ),
                if (_folders.isNotEmpty)
                  Wrap(
                    spacing: 5,
                    children: [
                      for (final folder in _folders)
                        ActionChip(
                          label: Text(folder),
                          onPressed: () => path.text = folder,
                        ),
                    ],
                  ),
                Input(controller: comment, label: l10n.sharingComment),
                CheckboxListTile(
                  value: readOnly,
                  title: Text(l10n.sharingReadOnly),
                  onChanged: (value) => setDialogState(() => readOnly = value ?? false),
                ),
                CheckboxListTile(
                  value: guest,
                  title: Text(l10n.sharingGuestLabel),
                  onChanged: (value) => setDialogState(() => guest = value ?? false),
                ),
                CheckboxListTile(
                  value: timeMachine,
                  title: Text(l10n.sharingTimeMachineOption),
                  onChanged: (value) => setDialogState(() => timeMachine = value ?? false),
                ),
                CheckboxListTile(
                  value: recycle,
                  title: Text(l10n.sharingRecycleOption),
                  onChanged: (value) => setDialogState(() => recycle = value ?? false),
                ),
                if (_users.isNotEmpty) ...[
                  Text(l10n.sharingUsersHint, style: UIs.text12Grey),
                  for (final user in _users.where((u) => !u.isSystem(_uidMin) && !u.isRoot))
                    CheckboxListTile(
                      dense: true,
                      value: users.contains(user.name),
                      title: Text(user.name),
                      onChanged: (value) => setDialogState(() {
                        if (value == true) {
                          users.add(user.name);
                        } else {
                          users.remove(user.name);
                        }
                      }),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: Btnx.cancelOk,
    );
    final draft = SmbShare(
      name: name.text.trim(),
      path: path.text.trim(),
      comment: comment.text.trim().isEmpty ? null : comment.text.trim(),
      readOnly: readOnly,
      guest: guest,
      users: users,
      timeMachine: timeMachine,
      recycle: recycle,
      managed: true,
    );
    _disposeLater([name, path, comment]);
    if (ok != true || !mounted) return;
    final confirmed = await _confirm(
      l10n.sharingSave,
      l10n.sharingSaveSmbBody(draft.name, draft.path),
    );
    if (!confirmed || !mounted) return;
    final next = _managedSmb([
      ...?_view?.smb.where((item) => item.managed && item.name != original?.name),
      draft,
    ]);
    await _write(
      (exec, password) => SharesManager.setSmb(
        exec,
        next,
        isRoot: widget.args.spi.isRoot,
        password: password,
      ),
    );
  }

  Future<void> _addNfs() => _editNfs();

  Future<void> _editNfs([NfsExport? original]) async {
    final path = TextEditingController(text: original?.path ?? '/mnt/');
    final clients = <_NfsClientDraft>[
      for (final client in original?.clients ?? const [
        NfsClient(host: '', readOnly: false, squash: 'root', options: []),
      ])
        _NfsClientDraft(client),
    ];
    final ok = await context.showRoundDialog<bool>(
      title: original == null ? l10n.sharingAddExport : l10n.sharingEdit,
      child: StatefulBuilder(
        builder: (context, setDialogState) => SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Input(controller: path, label: l10n.sharingFolder),
                Text(l10n.sharingClientsHint, style: UIs.text12Grey),
                for (final client in clients)
                  Row(
                    children: [
                      Expanded(
                        child: Input(
                          controller: client.host,
                          label: l10n.sharingClient,
                        ),
                      ),
                      DropdownButton<String>(
                        value: client.squash,
                        items: [
                          DropdownMenuItem(value: 'root', child: Text(l10n.sharingSquashRoot)),
                          DropdownMenuItem(value: 'all', child: Text(l10n.sharingSquashAll)),
                          DropdownMenuItem(value: 'none', child: Text(l10n.sharingSquashNone)),
                        ],
                        onChanged: (value) => setDialogState(() => client.squash = value ?? 'root'),
                      ),
                      Checkbox(
                        value: client.readOnly,
                        onChanged: (value) => setDialogState(() => client.readOnly = value ?? false),
                      ),
                      IconButton(
                        tooltip: l10n.sharingRemove,
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: clients.length == 1
                            ? null
                            : () => setDialogState(() => clients.remove(client)),
                      ),
                    ],
                  ),
                TextButton.icon(
                  onPressed: () => setDialogState(() => clients.add(_NfsClientDraft.empty())),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.sharingAddClient),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: Btnx.cancelOk,
    );
    final draft = NfsExport(
      path: path.text.trim(),
      clients: [
        for (final client in clients)
          if (client.host.text.trim().isNotEmpty)
            NfsClient(
              host: client.host.text.trim(),
              readOnly: client.readOnly,
              squash: client.squash,
              options: const [],
            ),
      ],
      managed: true,
    );
    _disposeLater([path, ...clients.map((client) => client.host)]);
    if (ok != true || !mounted) return;
    final confirmed = await _confirm(
      l10n.sharingSave,
      l10n.sharingSaveNfsBody(draft.path),
    );
    if (!confirmed || !mounted) return;
    final next = [
      ...?_view?.nfs.where((item) => item.managed && item.path != original?.path),
      draft,
    ];
    await _write(
      (exec, password) => SharesManager.setNfs(
        exec,
        next,
        isRoot: widget.args.spi.isRoot,
        password: password,
      ),
    );
  }

  List<SmbShare> _managedSmb(List<SmbShare> list) => [
    for (final item in list)
      if (item.managed) item,
  ];

  Future<bool> _confirm(String title, String body) async =>
      await context.showRoundDialog<bool>(
        title: libL10n.attention,
        child: Text(body),
        actions: Btnx.cancelRedOk,
      ) ==
      true;

  void _disposeLater(List<TextEditingController> controllers) {
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
  }
}

final class _ShareAttempt<T> {
  const _ShareAttempt.value(this.value) : error = null;
  const _ShareAttempt.failure(this.error) : value = null;

  final T? value;
  final SharesManagerException? error;
}

final class _ShareResult<T> {
  const _ShareResult.value(this.value) : error = null;
  const _ShareResult.failure(this.error) : value = null;

  final T? value;
  final SharesManagerException? error;

  bool get succeeded => error == null && value != null;
}

final class _NfsClientDraft {
  _NfsClientDraft(NfsClient client)
    : host = TextEditingController(text: client.host),
      readOnly = client.readOnly,
      squash = client.squash;

  factory _NfsClientDraft.empty() => _NfsClientDraft(
    const NfsClient(host: '', readOnly: false, squash: 'root', options: []),
  );

  final TextEditingController host;
  bool readOnly;
  String squash;
}
