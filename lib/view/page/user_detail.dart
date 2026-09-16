import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system_user.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/service/user_manager.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/view/page/ssh/page/page.dart';

/// Everything the detail page needs, including the two flows the list already
/// owns. Duplicating the editor here would mean two dialogs to keep in step.
final class UserDetailPageArgs {
  const UserDetailPageArgs({
    required this.spi,
    required this.user,
    required this.catalog,
    required this.onEdit,
    required this.onDelete,
  });

  final Spi spi;
  final ServerUser user;
  final ServerUserCatalog catalog;

  /// Answers true when the account changed, which closes this page: what it
  /// is showing no longer describes anything.
  final Future<bool> Function(ServerUser user) onEdit;
  final Future<bool> Function(ServerUser user) onDelete;
}

enum _DetailAction { delete }

final class UserDetailPage extends ConsumerStatefulWidget {
  const UserDetailPage({super.key, required this.args});

  final UserDetailPageArgs args;

  static const route = AppRouteArg<void, UserDetailPageArgs>(
    page: UserDetailPage.new,
    path: '/user_detail',
  );

  @override
  ConsumerState<UserDetailPage> createState() => _UserDetailPageState();
}

final class _UserDetailPageState extends ConsumerState<UserDetailPage> {
  late final _provider = serverProvider(widget.args.spi.id);

  ServerUserDetail? _detail;
  var _loading = true;

  ServerUser get _user => widget.args.user;

  /// Reachable from the `extension on` blocks below, where `setState` is not.
  void _rebuild(VoidCallback update) => setState(update);

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(up: _user.name, down: widget.args.spi.name),
        actions: [
          Btn.icon(
            text: libL10n.edit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            onTap: () => _run(widget.args.onEdit),
          ),
          if (!_user.isRoot && _user.name != widget.args.catalog.currentUser)
            PopupMenu<_DetailAction>(
              items: [
                PopupMenuItem(
                  value: _DetailAction.delete,
                  child: Text(libL10n.delete),
                ),
              ],
              onSelected: (_) => _run(widget.args.onDelete),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(13, 13, 13, 40),
        children: [
          _buildIdentity(),
          UIs.height13,
          _buildActions(),
          UIs.height13,
          _buildAccountCard(),
          UIs.height13,
          ?_buildSecurityCard(),
          if (_user.isRoot) ...[UIs.height13, _buildRootWarning()],
        ],
      ),
    );
  }
}

// --- Widget builders ---

extension on _UserDetailPageState {
  Widget _buildIdentity() {
    final scheme = Theme.of(context).colorScheme;
    final root = _user.isRoot;
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: root
              ? scheme.errorContainer
              : scheme.primaryContainer,
          child: Text(
            _user.name.isEmpty ? '?' : _user.name[0].toUpperCase(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: root ? scheme.onErrorContainer : scheme.onPrimaryContainer,
            ),
          ),
        ),
        UIs.width13,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (root) ...[
                    UIs.width7,
                    _tag('root', scheme.onErrorContainer, scheme.errorContainer),
                  ],
                ],
              ),
              Text(
                _subtitle(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: UIs.text12Grey,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Only the shell. The design also offers an SSH-keys button, which is not
  /// here: what it would show is the count already in Security below, and what
  /// it would edit is a file with no editor of its own yet.
  /// TODO: open `authorized_keys` in the file editor once that is reachable
  /// from a page that is not the file browser.
  Widget _buildActions() {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.tonalIcon(
        onPressed: _openShell,
        icon: const Icon(Icons.terminal, size: 17),
        label: Text(l10n.userOpenShell),
      ),
    );
  }

  Widget _buildAccountCard() {
    final group = _user.primaryGroup == null
        ? '${_user.gid}'
        : '${_user.primaryGroup} (GID ${_user.gid})';
    return _card(l10n.userDetailAccount, [
      _field(l10n.userUid, '${_user.uid}', mono: true),
      _field(l10n.userPrimaryGroup, group, mono: true),
      if (_user.supplementaryGroups.isNotEmpty)
        _field(
          l10n.userSupplementaryGroups,
          _user.supplementaryGroups.join(' · '),
          mono: true,
        ),
      _field(l10n.homeDir, _user.home, mono: true),
      _field(l10n.userLoginShell, _user.shell, mono: true),
      if (_user.comment.isNotEmpty) _field(l10n.userComment, _user.comment),
    ]);
  }

  /// Null when nothing was readable. Every one of its sources is root-only on
  /// a normal system, and a card of empty labels says less than no card.
  Widget? _buildSecurityCard() {
    if (_loading) {
      return _card(l10n.userDetailSecurity, const [
        SizedBox(height: 40, child: UIs.centerLoading),
      ]);
    }
    final detail = _detail;
    if (detail == null || detail.isEmpty) return null;

    final keys = detail.sshKeyTypes;
    return _card(l10n.userDetailSecurity, [
      if (detail.passwordState case final state?)
        _field(libL10n.pwd, _passwordText(state, detail.passwordChanged)),
      if (keys != null)
        _field(
          l10n.userSshKeys,
          keys.isEmpty ? '0' : '${keys.length} (${keys.join(', ')})',
          mono: true,
        ),
      if (detail.sudoRule case final rule?) _field('Sudo', rule),
      if (detail.neverExpires)
        _field(l10n.userExpires, l10n.userNever, grey: true)
      else if (detail.expires case final date?)
        _field(l10n.userExpires, date.toLocal().ymd()),
    ]);
  }

  Widget _buildRootWarning() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber, size: 15, color: UIs.textGrey.color),
        UIs.width7,
        Expanded(
          child: Text(l10n.userRootChangesWarning, style: UIs.text12Grey),
        ),
      ],
    );
  }

  Widget _card(String title, List<Widget> children) {
    return CardX(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: UIs.text11Grey),
            UIs.height7,
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String value, {bool mono = false, bool grey = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: UIs.text12Grey)),
          UIs.width13,
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: mono ? 'monospace' : null,
                color: grey ? UIs.textGrey.color : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color foreground, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: foreground)),
    );
  }
}

// --- Utils ---

extension on _UserDetailPageState {
  String _subtitle() {
    return [
      if (_user.isRoot) l10n.userSuperuser,
      if (_user.isSystem(widget.args.catalog.uidMin) && !_user.isRoot)
        libL10n.system,
      _user.loginDisabled ? libL10n.disabled : l10n.userLoginEnabled,
    ].join(' · ');
  }

  String _passwordText(ServerUserPasswordState state, DateTime? changed) {
    final label = switch (state) {
      ServerUserPasswordState.set => l10n.userPasswordSet,
      ServerUserPasswordState.locked => l10n.userPasswordLocked,
      ServerUserPasswordState.none => l10n.userPasswordNone,
    };
    if (changed == null) return label;
    return '$label · ${changed.toLocal().toAgoStr()}';
  }
}

// --- Actions ---

extension on _UserDetailPageState {
  Future<void> _load() async {
    try {
      final exec = await ref.read(_provider.notifier).ensureExec();
      final detail = await UserManager.detail(exec, _user);
      if (mounted) _rebuild(() => _detail = detail);
    } catch (e, s) {
      Loggers.app.warning('Read user detail for ${_user.name}', e, s);
    } finally {
      if (mounted) _rebuild(() => _loading = false);
    }
  }

  Future<void> _run(Future<bool> Function(ServerUser user) action) async {
    final changed = await action(_user);
    if (changed && mounted) context.pop();
  }

  /// Types `su - <name>` rather than running it: the shell that opens is the
  /// server's own, and switching user is a command the user should see before
  /// it runs.
  void _openShell() {
    final isCurrent = _user.name == widget.args.catalog.currentUser;
    SSHPage.route.go(
      context,
      SshPageArgs(
        source: ServerSource(widget.args.spi),
        initCmd: isCurrent ? null : 'su - ${_user.name}',
        notFromTab: true,
      ),
    );
  }
}
