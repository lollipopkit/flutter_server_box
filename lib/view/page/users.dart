import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/privileged_exec.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/system_user.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/service/user_manager.dart';

enum _UserFilter { all, regular, system }

enum _UserAction { edit, delete }

final class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key, required this.args});

  final SpiRequiredArgs args;

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: UsersPage.new,
    path: '/users',
  );

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

final class _UsersPageState extends ConsumerState<UsersPage> {
  late final _provider = serverProvider(widget.args.spi.id);

  ServerUserCatalog? _catalog;
  _UserFilter _filter = _UserFilter.all;
  bool _busy = false;
  bool _unsupported = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  void _rebuild(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) {
    final system = ref.watch(_provider.select((state) => state.status.system));
    final supported = system == SystemType.linux;
    final canMutate =
        supported && !_unsupported && _failure == null && _catalog != null;
    return Scaffold(
      appBar: CustomAppBar(
        centerTitle: true,
        title: TwoLineText(
          up: l10n.systemUsers,
          down: widget.args.spi.name,
        ),
        actions: isDesktop
            ? [
                Btn.icon(
                  text: libL10n.refresh,
                  icon: const Icon(Icons.refresh),
                  onTap: _busy ? null : _refresh,
                ),
              ]
            : null,
      ),
      body: RefreshIndicator(onRefresh: _refresh, child: _buildBody()),
      floatingActionButton: canMutate
          ? FloatingActionButton(
              tooltip: libL10n.add,
              onPressed: _busy ? null : () => _editUser(),
              child: const Icon(Icons.person_add_alt_1),
            )
          : null,
    );
  }
}

// --- Widget builders ---

extension on _UsersPageState {
  Widget _buildBody() {
    if (_unsupported) {
      return _issueBody(
        title: libL10n.unsupported,
        explain: l10n.userManagerLinuxOnly,
        icon: Icons.not_interested,
      );
    }
    if (_failure case final failure?) {
      return _issueBody(
        title: libL10n.fail,
        detail: failure,
        icon: Icons.error_outline,
      );
    }
    final catalog = _catalog;
    if (catalog == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [SizedBox(height: 280, child: UIs.centerLoading)],
      );
    }

    final users = switch (_filter) {
      _UserFilter.all => catalog.users,
      _UserFilter.regular => catalog.users
          .where((user) => !user.isSystem(catalog.uidMin))
          .toList(),
      _UserFilter.system => catalog.users
          .where((user) => user.isSystem(catalog.uidMin))
          .toList(),
    };

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildFilters(catalog)),
        if (_busy)
          const SliverToBoxAdapter(
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (users.isEmpty)
          SliverToBoxAdapter(
            child: CenterGreyTitle(libL10n.empty).paddingOnly(top: 80),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildUser(users[index], catalog),
              childCount: users.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }

  Widget _issueBody({
    required String title,
    required IconData icon,
    String? explain,
    String? detail,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: PageIssueView(
            title: title,
            explain: explain,
            detail: detail,
            icon: icon,
            onRetry: _refresh,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(ServerUserCatalog catalog) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final filter in _UserFilter.values)
            FilterChip(
              selected: filter == _filter,
              label: Text(switch (filter) {
                _UserFilter.all => libL10n.all,
                _UserFilter.regular => l10n.userRegularAccount,
                _UserFilter.system => libL10n.system,
              }),
              onSelected: (_) => _rebuild(() => _filter = filter),
            ),
          Chip(
            avatar: const Icon(Icons.login, size: 17),
            label: Text('${l10n.userCurrentAccount}: ${catalog.currentUser}'),
          ),
        ],
      ),
    );
  }

  Widget _buildUser(ServerUser user, ServerUserCatalog catalog) {
    final isCurrent = user.name == catalog.currentUser;
    final isSystem = user.isSystem(catalog.uidMin);
    final editable = UserManager.validName(user.name);
    return ListTile(
      leading: CircleAvatar(
        child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase()),
      ),
      title: Wrap(
        spacing: 7,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(user.name),
          if (isCurrent) _tag(l10n.userCurrentAccount, Colors.green),
          if (user.isRoot) _tag('root', Colors.red),
          if (isSystem && !user.isRoot) _tag(libL10n.system, null),
          if (user.loginDisabled) _tag(libL10n.disabled, Colors.orange),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.userUid}: ${user.uid}  ·  '
              '${l10n.userPrimaryGroup}: ${user.primaryGroup ?? user.gid}',
            ),
            Text('${l10n.homeDir}: ${user.home}'),
            Text('${l10n.userLoginShell}: ${user.shell}'),
            if (user.comment.isNotEmpty)
              Text('${l10n.userComment}: ${user.comment}'),
            if (user.supplementaryGroups.isNotEmpty)
              Text(
                '${l10n.userSupplementaryGroups}: '
                '${user.supplementaryGroups.join(', ')}',
              ),
          ],
        ),
      ),
      trailing: editable && !_busy
          ? PopupMenu<_UserAction>(
              items: [
                PopupMenuItem(
                  value: _UserAction.edit,
                  child: Text(libL10n.edit),
                ),
                if (!user.isRoot && !isCurrent)
                  PopupMenuItem(
                    value: _UserAction.delete,
                    child: Text(libL10n.delete),
                  ),
              ],
              onSelected: (action) => switch (action) {
                _UserAction.edit => _editUser(user),
                _UserAction.delete => _deleteUser(user),
              },
            )
          : null,
    ).cardx.paddingSymmetric(horizontal: 13);
  }

  Widget _tag(String text, Color? color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.14) ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
  }
}

// --- Actions ---

extension on _UsersPageState {
  Future<void> _refresh() async {
    if (!mounted || _busy) return;
    final system = ref.read(_provider).status.system;
    if (system != SystemType.linux) {
      _rebuild(() {
        _unsupported = true;
        _failure = null;
        _catalog = null;
      });
      return;
    }

    _rebuild(() {
      _busy = true;
      _unsupported = false;
      _failure = null;
    });
    try {
      final exec = await ref.read(_provider.notifier).ensureExec();
      final catalog = await UserManager.list(exec);
      if (!mounted) return;
      _rebuild(() => _catalog = catalog);
    } catch (e, s) {
      Loggers.app.warning('List users for ${widget.args.spi.id}', e, s);
      if (mounted) _rebuild(() => _failure = '$e');
    } finally {
      if (mounted) _rebuild(() => _busy = false);
    }
  }

  Future<void> _editUser([ServerUser? user]) async {
    final draft = await _showEditor(user);
    if (draft == null || !mounted) return;
    final script = user == null
        ? UserManager.createScript(draft)
        : UserManager.editScript(user, draft);
    if (await _runMutation(script)) await _refresh();
  }

  Future<void> _deleteUser(ServerUser user) async {
    var removeHome = false;
    final confirmed = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(libL10n.delFmt(libL10n.user, user.name)),
            CheckboxListTile(
              value: removeHome,
              title: Text(l10n.userRemoveHome),
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                setDialogState(() => removeHome = value ?? false);
              },
            ),
          ],
        ),
      ),
      actions: Btnx.cancelRedOk,
    );
    if (confirmed != true || !mounted) return;
    final script = UserManager.deleteScript(user, removeHome: removeHome);
    if (await _runMutation(script)) await _refresh();
  }

  Future<bool> _runMutation(String script) async {
    if (_busy) return false;
    _rebuild(() => _busy = true);
    try {
      final exec = await ref.read(_provider.notifier).ensureExec();
      var result = await PrivilegedExec.run(
        exec,
        script,
        isRoot: widget.args.spi.isRoot || _catalog?.currentUser == 'root',
      );
      if (result.exitCode == kSudoPasswordRejected) {
        if (!mounted) return false;
        final password = await context.showPwdDialog(
          title: libL10n.sudoPassword,
          label: widget.args.spi.ssh?.user ?? _catalog?.currentUser ?? '',
          id: '${widget.args.spi.id}_sudo_users',
        );
        if (password == null || password.isEmpty) return false;
        result = await PrivilegedExec.run(
          exec,
          script,
          isRoot: false,
          password: password,
        );
      }
      if (!result.succeeded) {
        if (mounted) {
          final detail = result.combined.trim();
          Toast.error(libL10n.fail, body: detail.isEmpty ? null : detail);
        }
        return false;
      }
      if (mounted) Toast.success(libL10n.success);
      return true;
    } catch (e, s) {
      Loggers.app.warning('Change user on ${widget.args.spi.id}', e, s);
      if (mounted) Toast.error('$e');
      return false;
    } finally {
      if (mounted) _rebuild(() => _busy = false);
    }
  }
}

// --- Utils ---

extension on _UsersPageState {
  Future<ServerUserDraft?> _showEditor(ServerUser? user) async {
    final catalog = _catalog;
    if (catalog == null) return null;
    final nameCtrl = TextEditingController(text: user?.name);
    final commentCtrl = TextEditingController(text: user?.comment);
    final homeCtrl = TextEditingController(text: user?.home);
    final shellCtrl = TextEditingController(text: user?.shell ?? '/bin/bash');
    final primaryGroupCtrl = TextEditingController(text: user?.primaryGroup);
    final groupsCtrl = TextEditingController(
      text: user?.supplementaryGroups.join(','),
    );
    final passwordCtrl = TextEditingController();
    var createHome = true;
    var moveHome = false;
    var systemAccount = user?.isSystem(catalog.uidMin) ?? false;

    try {
      while (mounted) {
        final submitted = await context.showRoundDialog<bool>(
          title: user == null ? libL10n.add : libL10n.edit,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
            ),
            child: StatefulBuilder(
              builder: (context, setDialogState) => SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Input(
                      controller: nameCtrl,
                      label: libL10n.user,
                      icon: Icons.person_outline,
                      enabled: user == null,
                      autoFocus: user == null,
                      suggestion: false,
                    ),
                    Input(
                      controller: commentCtrl,
                      label: l10n.userComment,
                      icon: Icons.badge_outlined,
                    ),
                    Input(
                      controller: homeCtrl,
                      label: l10n.homeDir,
                      hint: '/home/${nameCtrl.text}',
                      icon: Icons.home_outlined,
                      suggestion: false,
                    ),
                    Input(
                      controller: shellCtrl,
                      label: l10n.userLoginShell,
                      hint: '/bin/bash',
                      icon: Icons.terminal,
                      suggestion: false,
                    ),
                    Input(
                      controller: primaryGroupCtrl,
                      label: l10n.userPrimaryGroup,
                      icon: Icons.group_outlined,
                      suggestion: false,
                    ),
                    Input(
                      controller: groupsCtrl,
                      label: l10n.userSupplementaryGroups,
                      hint: 'docker,wheel',
                      icon: Icons.groups_outlined,
                      suggestion: false,
                    ),
                    Input(
                      controller: passwordCtrl,
                      label: libL10n.pwd,
                      icon: Icons.password,
                      obscureText: true,
                      suggestion: false,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Text(
                        user == null
                            ? l10n.userPasswordCreateTip
                            : l10n.userPasswordEditTip,
                        style: UIs.textGrey,
                      ),
                    ),
                    if (user == null)
                      SwitchListTile(
                        value: systemAccount,
                        title: Text(l10n.userSystemAccount),
                        onChanged: (value) {
                          setDialogState(() {
                            systemAccount = value;
                            if (value) createHome = false;
                          });
                        },
                      ),
                    if (user == null)
                      SwitchListTile(
                        value: createHome,
                        title: Text(l10n.userCreateHome),
                        onChanged: (value) {
                          setDialogState(() => createHome = value);
                        },
                      ),
                    if (user != null)
                      SwitchListTile(
                        value: moveHome,
                        title: Text(l10n.userMoveHome),
                        onChanged: (value) {
                          setDialogState(() => moveHome = value);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: Btnx.cancelOk,
        );
        if (submitted != true || !mounted) return null;

        final groups = groupsCtrl.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final password = passwordCtrl.text;
        final draft = ServerUserDraft(
          name: nameCtrl.text.trim(),
          comment: commentCtrl.text.trim(),
          home: homeCtrl.text.trim(),
          shell: shellCtrl.text.trim(),
          primaryGroup: primaryGroupCtrl.text.trim(),
          supplementaryGroups: groups,
          createHome: createHome,
          moveHome: moveHome,
          system: systemAccount,
          password: password.isEmpty ? null : password,
        );
        final duplicate = user == null &&
            catalog.users.any((existing) => existing.name == draft.name);
        final validation = UserManager.validateDraft(draft);
        if (validation != null || duplicate) {
          Toast.error(
            validation ?? l10n.nameAlreadyExistsFmt(draft.name),
          );
          continue;
        }
        return draft;
      }
      return null;
    } finally {
      nameCtrl.dispose();
      commentCtrl.dispose();
      homeCtrl.dispose();
      shellCtrl.dispose();
      primaryGroupCtrl.dispose();
      groupsCtrl.dispose();
      passwordCtrl.dispose();
    }
  }
}
