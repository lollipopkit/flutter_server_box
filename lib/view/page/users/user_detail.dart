import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/admin/user_manager.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system_user.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/terminal/terminal_source.dart';
import 'package:server_box/src/rust/api/users.dart' as users_ffi;
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/page/users/widgets.dart';

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
  final SystemUser user;
  final UserCatalog catalog;

  /// Answers true when the account changed, which closes this page: what it
  /// is showing no longer describes anything.
  final Future<bool> Function(SystemUser user) onEdit;
  final Future<bool> Function(SystemUser user) onDelete;
}

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

  UserDetail? _detail;
  var _loading = true;
  var _busy = false;

  SystemUser get _user => widget.args.user;

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
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedLoading.small,
            )
          else ...[
            Btn.icon(
              text: libL10n.edit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => _run(widget.args.onEdit),
            ),
            if (UserManager.userDeletable(_user, current: widget.args.catalog.currentUser))
              DeleteOverflowButton(onDelete: () => _run(widget.args.onDelete)),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(13, 13, 13, 40),
        children: [
          UserIdentityHeader(
            name: _user.name,
            subtitle: _subtitle(),
            isRoot: _user.isRoot,
          ),
          UIs.height13,
          _buildActions(),
          UIs.height13,
          _buildAccountCard(),
          UIs.height13,
          ?_buildSecurityCard(),
          if (_user.isRoot) ...[UIs.height13, const RootChangesWarning()],
        ],
      ),
    );
  }
}

// --- Widget builders ---

extension on _UserDetailPageState {

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
    return DetailCard(l10n.userDetailAccount, [
      DetailField(l10n.userUid, '${_user.uid}', mono: true),
      DetailField(l10n.userPrimaryGroup, group, mono: true),
      if (_user.supplementaryGroups.isNotEmpty)
        DetailField(
          l10n.userSupplementaryGroups,
          _user.supplementaryGroups.join(' · '),
          mono: true,
        ),
      DetailField(l10n.homeDir, _user.home, mono: true),
      DetailField(l10n.userLoginShell, _user.shell, mono: true),
      if (_user.comment.isNotEmpty) DetailField(l10n.userComment, _user.comment),
    ]);
  }

  /// Null when nothing was readable. Every one of its sources is root-only on
  /// a normal system, and a card of empty labels says less than no card.
  Widget? _buildSecurityCard() {
    if (_loading) {
      return DetailCard(l10n.userDetailSecurity, const [
        SizedBox(height: 40, child: UIs.centerLoading),
      ]);
    }
    final detail = _detail;
    if (detail == null || detail.isEmpty) return null;

    final keys = detail.sshKeyTypes;
    return DetailCard(l10n.userDetailSecurity, [
      if (detail.passwordState case final state?)
        DetailField(libL10n.pwd, _passwordText(state, detail.passwordChanged)),
      if (keys != null)
        DetailField(
          l10n.userSshKeys,
          keys.isEmpty ? '0' : '${keys.length} (${keys.join(', ')})',
          mono: true,
        ),
      if (detail.sudoRule case final rule?) DetailField('Sudo', rule),
      if (detail.neverExpires)
        DetailField(l10n.userExpires, l10n.userNever, grey: true)
      else if (detail.expires case final date?)
        DetailField(l10n.userExpires, date.toLocal().ymd()),
    ]);
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

  String _passwordText(PasswordState state, DateTime? changed) {
    final label = switch (state) {
      PasswordState.set_ => l10n.userPasswordSet,
      PasswordState.locked => l10n.userPasswordLocked,
      PasswordState.none => l10n.userPasswordNone,
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

  Future<void> _run(Future<bool> Function(SystemUser user) action) async {
    if (_busy) return;
    _rebuild(() => _busy = true);
    var popped = false;
    try {
      final changed = await action(_user);
      if (changed && mounted) {
        popped = true;
        context.pop();
      }
    } finally {
      if (!popped && mounted) _rebuild(() => _busy = false);
    }
  }

  /// Types `su - <name>` rather than running it: the shell that opens is the
  /// server's own, and switching user is a command the user should see before
  /// it runs.
  ///
  /// Quoted even so. The name comes out of the server's own `/etc/passwd`,
  /// which this app does not get to choose the contents of, and a command
  /// typed into a terminal is one Enter away from running.
  void _openShell() {
    final isCurrent = _user.name == widget.args.catalog.currentUser;
    SSHPage.route.go(
      context,
      SshPageArgs(
        source: ServerSource(widget.args.spi),
        initCmd: isCurrent
            ? null
            : users_ffi.usersLoginShellCommand(user: _user.name),
        notFromTab: true,
      ),
    );
  }
}
