/// Who may use a `monitor` agent, and for what: its accounts and roles —
/// `docs/dev/monitor-permissions.md`.
///
/// An admin's pages. Every change of access asks the admin's own password
/// again ([askMonitorPassword]), which the agent checks: a phone left unlocked
/// is not enough to hand out a shell.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_grants.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';
import 'package:server_box/view/page/server/monitor_settings/widgets.dart';

/// The agent's minimum, said by the form before the agent says it.
const kMonitorMinPassword = 8;

/// The admin's own password, for the agent to check before a change of
/// access. Null when the dialog was dismissed.
///
/// The controllers are the dialog's to dispose ([DisposeWith]): the answer
/// arrives while its fields are still animating out.
Future<String?> askMonitorPassword(BuildContext context) async {
  final ctrl = TextEditingController();
  final ok = await context.showRoundDialog<bool>(
    title: l10n.monitorCurrentPassword,
    child: DisposeWith(
      notifiers: [ctrl],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.monitorReauthTip, style: UIs.textGrey),
          UIs.height13,
          Input(
            controller: ctrl,
            label: libL10n.pwd,
            icon: Icons.password,
            obscureText: true,
            suggestion: false,
            autoFocus: true,
            onSubmitted: (_) => context.popDialog(true),
          ),
        ],
      ),
    ),
    actions: Btnx.cancelOk,
  );
  if (ok != true || ctrl.text.isEmpty) return null;
  return ctrl.text;
}

/// A new password, typed twice. Null when the dialog was dismissed.
Future<String?> askMonitorNewPassword(BuildContext context) async {
  final first = TextEditingController();
  final second = TextEditingController();
  final ok = await context.showRoundDialog<bool>(
    title: l10n.monitorNewPassword,
    child: DisposeWith(
      notifiers: [first, second],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Input(
            controller: first,
            label: l10n.monitorNewPassword,
            hint: l10n.monitorPasswordTooShort,
            icon: Icons.password,
            obscureText: true,
            suggestion: false,
            autoFocus: true,
          ),
          Input(
            controller: second,
            label: libL10n.confirm,
            icon: Icons.password,
            obscureText: true,
            suggestion: false,
            onSubmitted: (_) => context.popDialog(true),
          ),
        ],
      ),
    ),
    actions: Btnx.cancelOk,
  );
  if (ok != true) return null;
  final (a, b) = (first.text, second.text);
  if (a.length < kMonitorMinPassword) {
    Toast.show(l10n.monitorPasswordTooShort);
    return null;
  }
  if (a != b) {
    Toast.show(l10n.monitorPasswordMismatch);
    return null;
  }
  return a;
}

/// What to tell someone whose change the agent refused.
String monitorAccessErrText(Object e) {
  if (e is! MonitorHttpErr) return '$e';
  return switch (e.type) {
    MonitorHttpErrType.reauth => l10n.monitorErrReauth,
    MonitorHttpErrType.lastAdmin => l10n.monitorErrLastAdmin,
    MonitorHttpErrType.conflict => l10n.monitorErrConflict,
    MonitorHttpErrType.forbidden => l10n.monitorErrForbidden,
    _ => e.message ?? '$e',
  };
}

/// Runs [change] with the admin's password, reporting a refusal. True when it
/// went through.
Future<bool> _withPassword(
  BuildContext context,
  Future<void> Function(String currentPassword) change,
) async {
  final current = await askMonitorPassword(context);
  if (current == null) return false;
  try {
    await change(current);
    return true;
  } catch (e) {
    Toast.show(monitorAccessErrText(e));
    return false;
  }
}

/// A role's grants in a line: what it holds, named.
String monitorRoleSummary(MonitorRole role) {
  final g = role.grants;
  final held = [
    if (g.shell) l10n.monitorGrantShell,
    if (g.files case final mode?)
      '${l10n.monitorGrantFiles} (${mode == MonitorFilesMode.read ? libL10n.read : libL10n.write})',
    if (g.connectAllow != null) l10n.monitorGrantConnect,
    if (g.listen != null) l10n.monitorGrantListen,
    if (g.virt == true) l10n.monitorGrantVirt,
  ];
  return held.isEmpty ? libL10n.read : held.join(', ');
}

// --- Accounts ---

final class MonitorAccountsArgs {
  final MonitorHttpClient client;

  /// Who this app is logged in as, marked in the list.
  final String me;

  const MonitorAccountsArgs({required this.client, required this.me});
}

final class MonitorAccountsPage extends StatefulWidget {
  final MonitorAccountsArgs args;

  const MonitorAccountsPage({super.key, required this.args});

  static const route = AppRouteArg<void, MonitorAccountsArgs>(
    page: MonitorAccountsPage.new,
    path: '/server/monitor_settings/accounts',
  );

  @override
  State<MonitorAccountsPage> createState() => _MonitorAccountsPageState();
}

final class _MonitorAccountsPageState extends State<MonitorAccountsPage> {
  MonitorHttpClient get _client => widget.args.client;

  List<MonitorUser>? _users;
  List<MonitorRole> _roles = const [];
  String? _err;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _err = null);
    try {
      final users = await _client.fetchUsers();
      final roles = await _client.fetchRoles();
      if (!mounted) return;
      setState(() {
        _users = users;
        _roles = roles;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = monitorAccessErrText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.monitorAccounts)),
      body: switch ((_err, users)) {
        (final err?, _) => _MonitorErr(err: err, onRetry: _load),
        (_, null) => UIs.centerLoading,
        (_, final users?) => MonitorUi.column(
          children: [
            for (final user in users)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(
                  user.username == widget.args.me
                      ? '${user.username} (${l10n.monitorYou})'
                      : user.username,
                ),
                subtitle: Text(user.role, style: UIs.textGrey),
                trailing: ContextMenuButton(
                  actions: () => [
                    ContextMenuAction(
                      icon: Icons.badge_outlined,
                      text: l10n.monitorRole,
                      onTap: () => _changeRole(user),
                    ),
                    ContextMenuAction(
                      icon: Icons.password,
                      text: l10n.monitorChangePassword,
                      onTap: () => _resetPassword(user),
                    ),
                    ContextMenuAction(
                      icon: Icons.delete,
                      text: libL10n.delete,
                      destructive: true,
                      onTap: () => _delete(user),
                    ),
                  ],
                ),
              ).cardx,
            MonitorUi.addBtn(_create),
          ],
        ),
      },
    );
  }

  /// One of [_roles], picked in a dialog; null when dismissed.
  Future<String?> _pickRole(String? current) {
    return context.showRoundDialog<String>(
      title: l10n.monitorRole,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final role in _roles)
            ListTile(
              title: Text(role.name),
              subtitle: Text(monitorRoleSummary(role), style: UIs.textGrey),
              trailing: role.name == current ? const Icon(Icons.check) : null,
              onTap: () => context.popDialog(role.name),
            ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final pwd = TextEditingController();
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.add,
      child: DisposeWith(
        notifiers: [name, pwd],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Input(
              controller: name,
              label: libL10n.user,
              icon: Icons.person_outline,
              suggestion: false,
              autoFocus: true,
            ),
            Input(
              controller: pwd,
              label: libL10n.pwd,
              hint: l10n.monitorPasswordTooShort,
              icon: Icons.password,
              obscureText: true,
              suggestion: false,
            ),
          ],
        ),
      ),
      actions: Btnx.cancelOk,
    );
    // Read now: the fields are gone once the dialog has finished leaving.
    final (username, password) = (name.text.trim(), pwd.text);
    if (ok != true || !mounted || username.isEmpty) return;
    if (password.length < kMonitorMinPassword) {
      Toast.show(l10n.monitorPasswordTooShort);
      return;
    }
    final role = await _pickRole(null);
    if (role == null || !mounted) return;
    final done = await _withPassword(
      context,
      (current) => _client.createUser(
        username: username,
        password: password,
        role: role,
        currentPassword: current,
      ),
    );
    if (done) await _load();
  }

  Future<void> _changeRole(MonitorUser user) async {
    final role = await _pickRole(user.role);
    if (role == null || role == user.role || !mounted) return;
    final done = await _withPassword(
      context,
      (current) => _client.updateUser(
        user.username,
        role: role,
        currentPassword: current,
      ),
    );
    if (done) await _load();
  }

  Future<void> _resetPassword(MonitorUser user) async {
    final password = await askMonitorNewPassword(context);
    if (password == null || !mounted) return;
    final done = await _withPassword(
      context,
      (current) => _client.updateUser(
        user.username,
        password: password,
        currentPassword: current,
      ),
    );
    if (done) Toast.success(libL10n.success);
  }

  Future<void> _delete(MonitorUser user) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(libL10n.askContinue('${libL10n.delete} ${user.username}')),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    final done = await _withPassword(
      context,
      (current) =>
          _client.deleteUser(user.username, currentPassword: current),
    );
    if (done) await _load();
  }
}

// --- Roles ---

final class MonitorRolesArgs {
  final MonitorHttpClient client;

  const MonitorRolesArgs({required this.client});
}

final class MonitorRolesPage extends StatefulWidget {
  final MonitorRolesArgs args;

  const MonitorRolesPage({super.key, required this.args});

  static const route = AppRouteArg<void, MonitorRolesArgs>(
    page: MonitorRolesPage.new,
    path: '/server/monitor_settings/roles',
  );

  @override
  State<MonitorRolesPage> createState() => _MonitorRolesPageState();
}

final class _MonitorRolesPageState extends State<MonitorRolesPage> {
  MonitorHttpClient get _client => widget.args.client;

  List<MonitorRole>? _roles;
  String? _err;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _err = null);
    try {
      final roles = await _client.fetchRoles();
      if (!mounted) return;
      setState(() => _roles = roles);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = monitorAccessErrText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = _roles;
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.monitorRoles)),
      body: switch ((_err, roles)) {
        (final err?, _) => _MonitorErr(err: err, onRetry: _load),
        (_, null) => UIs.centerLoading,
        (_, final roles?) => MonitorUi.column(
          children: [
            for (final role in roles)
              ListTile(
                leading: Icon(
                  role.admin ? Icons.admin_panel_settings : Icons.badge_outlined,
                ),
                title: Text(
                  role.builtin
                      ? '${role.name} (${l10n.monitorBuiltin})'
                      : role.name,
                ),
                subtitle: Text(monitorRoleSummary(role), style: UIs.textGrey),
                trailing: role.builtin
                    ? null
                    : IconButton(
                        tooltip: libL10n.delete,
                        icon: const Icon(Icons.delete, size: 19),
                        onPressed: () => _delete(role),
                      ),
                onTap: () => _edit(role),
              ).cardx,
            MonitorUi.addBtn(() => _edit(null)),
          ],
        ),
      },
    );
  }

  Future<void> _edit(MonitorRole? role) async {
    final saved = await MonitorRoleEditPage.route.go(
      context,
      MonitorRoleEditArgs(
        client: _client,
        role: role,
        // A role read from this agent says whether it knows `virt`.
        virtKnown: _roles?.any((r) => r.grants.virt != null) ?? false,
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _delete(MonitorRole role) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(libL10n.askContinue('${libL10n.delete} ${role.name}')),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    final done = await _withPassword(
      context,
      (current) => _client.deleteRole(role.name, currentPassword: current),
    );
    if (done) await _load();
  }
}

// --- One role ---

final class MonitorRoleEditArgs {
  final MonitorHttpClient client;

  /// Null for a new one.
  final MonitorRole? role;

  /// Whether the agent knows `virt`, for a new role — see
  /// [MonitorRoleGrants.virt].
  final bool virtKnown;

  const MonitorRoleEditArgs({
    required this.client,
    this.role,
    this.virtKnown = false,
  });
}

/// One role's grants, and their options.
///
/// Answers true when it saved. A page rather than a dialog: five grants, three
/// of them with options, are more than a dialog holds readably.
final class MonitorRoleEditPage extends StatefulWidget {
  final MonitorRoleEditArgs args;

  const MonitorRoleEditPage({super.key, required this.args});

  static const route = AppRouteArg<bool, MonitorRoleEditArgs>(
    page: MonitorRoleEditPage.new,
    path: '/server/monitor_settings/role',
  );

  @override
  State<MonitorRoleEditPage> createState() => _MonitorRoleEditPageState();
}

final class _MonitorRoleEditPageState extends State<MonitorRoleEditPage> {
  MonitorRole? get _existing => widget.args.role;

  late final _name = TextEditingController(text: _existing?.name ?? '');
  late var _grants =
      _existing?.grants ??
      MonitorRoleGrants(virt: widget.args.virtKnown ? false : null);
  late final _allow = TextEditingController(
    text: (_existing?.grants.connectAllow ?? const []).join('\n'),
  );
  late final _ports = TextEditingController(
    text: switch (_existing?.grants.listen?.ports) {
      (final lo, final hi) => '$lo-$hi',
      null => '',
    },
  );
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _allow.dispose();
    _ports.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = _existing;
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(existing?.name ?? l10n.monitorRoles),
        actions: [
          IconButton(
            tooltip: libL10n.save,
            icon: const Icon(Icons.save),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: MonitorUi.column(
        children: [
          // Fixed once made: accounts point at it by name.
          if (existing == null)
            Input(
              controller: _name,
              label: libL10n.name,
              hint: l10n.monitorRoleNameRule,
              icon: Icons.badge_outlined,
              suggestion: false,
            ),
          if (existing?.admin ?? false)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: Text(l10n.monitorAdminRoleTip, style: UIs.textGrey),
            ).cardx,
          _switch(
            icon: Icons.terminal,
            title: l10n.monitorGrantShell,
            tip: l10n.monitorGrantShellTip,
            value: _grants.shell,
            onChanged: (v) => _grants = _grants.copyWith(shell: v),
          ),
          if (_grants.virt case final virt?)
            _switch(
              icon: Icons.dns_outlined,
              title: l10n.monitorGrantVirt,
              tip: l10n.monitorGrantVirtTip,
              value: virt,
              onChanged: (v) => _grants = _grants.copyWith(virt: v),
            ),
          _buildFiles(),
          _switch(
            icon: Icons.call_made,
            title: l10n.monitorGrantConnect,
            tip: l10n.monitorGrantConnectTip,
            value: _grants.connectAllow != null,
            onChanged: (v) => _grants = _grants.copyWith(
              connectAllow: () => v ? const [] : null,
            ),
          ),
          if (_grants.connectAllow != null)
            Input(
              controller: _allow,
              label: l10n.monitorGrantConnectAllow,
              hint: '127.0.0.1:3389\n10.0.0.0/8',
              icon: Icons.filter_alt_outlined,
              maxLines: 5,
              minLines: 2,
              suggestion: false,
            ),
          _switch(
            icon: Icons.call_received,
            title: l10n.monitorGrantListen,
            tip: l10n.monitorGrantListenTip,
            value: _grants.listen != null,
            onChanged: (v) => _grants = _grants.copyWith(
              listen: () => v ? const MonitorListenGrant() : null,
            ),
          ),
          if (_grants.listen case final listen?) ...[
            _switch(
              icon: Icons.public,
              title: l10n.monitorGrantListenPublic,
              value: listen.public,
              onChanged: (v) => _grants = _grants.copyWith(
                listen: () =>
                    MonitorListenGrant(public: v, ports: listen.ports),
              ),
            ),
            Input(
              controller: _ports,
              label: l10n.monitorGrantPorts,
              hint: '1024-65535',
              icon: Icons.numbers,
              suggestion: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _switch({
    required IconData icon,
    required String title,
    String? tip,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: tip == null ? Text(title) : TipText(title, tip),
      trailing: SwitchX(
        value: value,
        onChanged: (v) => setState(() => onChanged(v)),
      ),
    ).cardx;
  }

  Widget _buildFiles() {
    final mode = _grants.files;
    String label(MonitorFilesMode? m) => switch (m) {
      null => l10n.monitorGrantOff,
      MonitorFilesMode.read => libL10n.read,
      MonitorFilesMode.write => libL10n.write,
    };
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(l10n.monitorGrantFiles),
      trailing: ContextMenuButton(
        actions: () => [
          for (final m in <MonitorFilesMode?>[null, ...MonitorFilesMode.values])
            ContextMenuAction(
              text: label(m),
              checked: m == mode,
              onTap: () =>
                  setState(() => _grants = _grants.copyWith(files: () => m)),
            ),
        ],
        child: ContextMenuButton.value(Text(label(mode))),
      ),
    ).cardx;
  }

  /// [_ports] as a range, null for empty; throws [FormatException] for text
  /// that is neither.
  (int, int)? _parsePorts() {
    final text = _ports.text.trim();
    if (text.isEmpty) return null;
    final parts = text.split('-').map((e) => int.tryParse(e.trim())).toList();
    final (lo, hi) = switch (parts) {
      [final a?] => (a, a),
      [final a?, final b?] => (a, b),
      _ => throw FormatException(text),
    };
    if (lo < 1 || hi > 65535 || lo > hi) throw FormatException(text);
    return (lo, hi);
  }

  Future<void> _save() async {
    final name = _existing?.name ?? _name.text.trim();
    if (!MonitorRole.namePattern.hasMatch(name)) {
      Toast.show(l10n.monitorRoleNameRule);
      return;
    }
    final (int, int)? ports;
    try {
      ports = _parsePorts();
    } on FormatException {
      Toast.show(l10n.monitorGrantPorts);
      return;
    }
    final grants = _grants.copyWith(
      connectAllow: () => _grants.connectAllow == null
          ? null
          : [
              for (final line in _allow.text.split(RegExp(r'[\n,]')))
                if (line.trim().isNotEmpty) line.trim(),
            ],
      listen: () => switch (_grants.listen) {
        final listen? => MonitorListenGrant(public: listen.public, ports: ports),
        null => null,
      },
    );
    final role = (_existing ?? MonitorRole(name: name)).copyWith(
      name: name,
      grants: grants,
    );
    setState(() => _saving = true);
    final client = widget.args.client;
    final done = await _withPassword(
      context,
      (current) => _existing == null
          ? client.createRole(role, currentPassword: current)
          : client.updateRole(role, currentPassword: current),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (done) context.pop(true);
  }
}

class _MonitorErr extends StatelessWidget {
  const _MonitorErr({required this.err, required this.onRetry});

  final String err;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 27),
            child: Text(err, style: UIs.textGrey, textAlign: TextAlign.center),
          ),
          UIs.height13,
          Btn.text(text: libL10n.retry, onTap: onRetry),
        ],
      ),
    );
  }
}
