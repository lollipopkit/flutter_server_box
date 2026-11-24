// ignore_for_file: invalid_use_of_protected_member

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show llmL10n;
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/monitor/http.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor/monitor_api_token.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';

/// MCP access (`/api/v1/api-tokens*`, #1681): endpoint URL, global permission
/// ceiling, and per-token scopes and command rules.
final class MonitorApiTokensArgs {
  final MonitorHttpCredential monitor;

  const MonitorApiTokensArgs(this.monitor);
}

final class MonitorApiTokensPage extends StatefulWidget {
  final MonitorApiTokensArgs args;

  const MonitorApiTokensPage({super.key, required this.args});

  static const route = AppRouteArg<void, MonitorApiTokensArgs>(
    page: MonitorApiTokensPage.new,
    path: '/server/monitor_settings/api_tokens',
  );

  @override
  State<MonitorApiTokensPage> createState() => _MonitorApiTokensPageState();
}

final class _MonitorApiTokensPageState extends State<MonitorApiTokensPage> {
  late var _client = MonitorHttpClient(widget.args.monitor);

  List<MonitorApiToken>? _tokens;
  MonitorMcpPolicy? _policy;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MonitorApiTokensPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.args.monitor == oldWidget.args.monitor) return;
    _client.dispose();
    _client = MonitorHttpClient(widget.args.monitor);
    setState(() {
      _tokens = null;
      _policy = null;
      _error = null;
    });
    _load();
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildPage(context);
}

// --- Build ---

extension on _MonitorApiTokensPageState {
  Widget _buildPage(BuildContext context) {
    final tokens = _tokens;
    final policy = _policy;
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.monitorMcpAccess),
        actions: [
          IconButton(
            tooltip: l10n.monitorMcpNewToken,
            icon: const Icon(Icons.add),
            onPressed: (tokens != null && _error == null) ? _create : null,
          ),
        ],
      ),
      body: _error != null
          ? PageIssueView(title: libL10n.error, detail: _error!, onRetry: _load)
          : tokens == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              children: [
                ListTile(
                  leading: const Icon(Icons.link),
                  title: Text(l10n.monitorMcpEndpoint),
                  subtitle: Text(_client.mcpEndpointUrl, style: UIs.textGrey),
                  trailing: Btn.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    onTap: () => Pfs.copy(_client.mcpEndpointUrl),
                  ),
                ).cardx,
                if (policy != null)
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: Text(l10n.monitorMcpGlobalPolicy),
                    subtitle: Text(
                      _scopesSummary(
                        _effectivePolicyScopes(policy),
                        policy.commands,
                      ),
                      style: UIs.textGrey,
                    ),
                    trailing: const Icon(Icons.keyboard_arrow_right),
                    onTap: () => _editGlobalPolicy(policy),
                  ).cardx,
                CenterGreyTitle(l10n.monitorMcpTokens),
                if (tokens.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 27),
                    child: Center(
                      child: Text(l10n.monitorMcpNoTokens, style: UIs.textGrey),
                    ),
                  )
                else
                  for (final token in tokens)
                    ListTile(
                      leading: const Icon(Icons.key_outlined),
                      title: Text(
                        token.expired
                            ? '${token.name} (${l10n.monitorMcpExpired})'
                            : token.name,
                      ),
                      subtitle: Text(
                        _tokenSubtitle(token),
                        style: UIs.textGrey,
                        maxLines: 3,
                      ),
                      onTap: () => _editToken(token),
                      trailing: Btn.icon(
                        icon: const Icon(Icons.delete_outline),
                        onTap: () => _revoke(token),
                      ),
                    ).cardx,
              ],
            ),
    );
  }
}

// --- Actions ---

extension on _MonitorApiTokensPageState {
  Future<void> _load() async {
    final client = _client;
    try {
      final results = await Future.wait([
        client.apiTokens(),
        client.mcpPolicy(),
      ]);
      if (!mounted || !identical(client, _client)) return;
      setState(() {
        _tokens = results[0] as List<MonitorApiToken>;
        _policy = results[1] as MonitorMcpPolicy;
        _error = null;
      });
    } catch (e) {
      if (!mounted || !identical(client, _client)) return;
      setState(() => _error = monitorTokenErrText(e));
    }
  }

  Future<void> _editGlobalPolicy(MonitorMcpPolicy current) async {
    final client = _client;
    final edited = await _askPolicy(context, current);
    if (edited == null || !mounted || !identical(client, _client)) return;
    try {
      final saved = await client.saveMcpPolicy(
        scopes: edited.scopes,
        commands: edited.commands,
      );
      if (!mounted || !identical(client, _client)) return;
      setState(() => _policy = saved);
      Toast.show(libL10n.saved);
    } catch (e) {
      if (!mounted || !identical(client, _client)) return;
      Toast.show(monitorTokenErrText(e));
    }
  }

  Future<void> _create() async {
    final client = _client;
    final secret = await _askAndMintToken(
      context,
      client,
      isActive: () => mounted && identical(client, _client),
    );
    if (secret == null || !mounted || !identical(client, _client)) return;
    await _showToken(context, secret);
    if (!mounted || !identical(client, _client)) return;
    await _load();
  }

  Future<void> _editToken(MonitorApiToken token) async {
    final client = _client;
    final edited = await _askEditToken(context, token);
    if (edited == null || !mounted || !identical(client, _client)) return;
    try {
      await client.updateApiToken(
        token.id,
        name: edited.name,
        scopes: edited.scopes,
        commands: edited.commands,
      );
      if (!mounted || !identical(client, _client)) return;
      await _load();
      Toast.show(libL10n.saved);
    } catch (e) {
      if (!mounted || !identical(client, _client)) return;
      Toast.show(monitorTokenErrText(e));
    }
  }

  Future<void> _revoke(MonitorApiToken token) async {
    final client = _client;
    final ok = await context.showSheet<bool>(
      title: l10n.monitorMcpRevoke,
      child: Text(l10n.monitorMcpRevokeHint(token.name)),
      actions: Btnx.cancelOk,
    );
    if (ok != true || !mounted || !identical(client, _client)) return;
    try {
      await client.revokeApiToken(token.id);
      if (!mounted || !identical(client, _client)) return;
      await _load();
    } catch (e) {
      if (!mounted || !identical(client, _client)) return;
      Toast.show(monitorTokenErrText(e));
    }
  }
}

// --- Utils & Sheets ---

String monitorScopeLabel(String scope) => switch (scope) {
  MonitorApiToken.scopeRead => l10n.monitorMcpScopeRead,
  MonitorApiToken.scopeFsRead => l10n.monitorMcpScopeFsRead,
  MonitorApiToken.scopeFsWrite => l10n.monitorMcpScopeFsWrite,
  MonitorApiToken.scopeExec => l10n.monitorMcpScopeExec,
  MonitorApiToken.scopeProcess => l10n.monitorMcpScopeProcess,
  MonitorApiToken.scopeService => l10n.monitorMcpScopeService,
  MonitorApiToken.scopeContainer => l10n.monitorMcpScopeContainer,
  MonitorApiToken.scopeCron => l10n.monitorMcpScopeCron,
  MonitorApiToken.scopeVirt => l10n.monitorMcpScopeVirt,
  MonitorApiToken.scopeStacks => l10n.monitorMcpScopeStacks,
  MonitorApiToken.scopePower => l10n.monitorMcpScopePower,
  _ => scope,
};

String monitorTokenErrText(Object e) {
  if (e is! MonitorHttpErr) return '$e';
  return switch (e.type) {
    MonitorHttpErrType.reauth => l10n.monitorErrReauth,
    MonitorHttpErrType.forbidden => l10n.monitorNoRemoteAccess,
    _ => e.message ?? '$e',
  };
}

List<String> _effectivePolicyScopes(MonitorMcpPolicy p) => [
  for (final s in p.scopes)
    if (p.configScopes.contains(s)) s,
];

String _formatUtcStamp(String raw) {
  final iso = raw.contains('T') ? raw : '${raw.replaceFirst(' ', 'T')}Z';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return raw;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}

String _scopesSummary(List<String> scopes, MonitorMcpCommandPolicy cmds) {
  final all = MonitorApiToken.allScopes.every(scopes.contains);
  final scopePart = all
      ? l10n.monitorMcpAllScopes
      : scopes.isEmpty
      ? '—'
      : scopes.map(monitorScopeLabel).join(' · ');
  final cmdPart = cmds.mode == MonitorMcpCommandPolicy.modeAllowlist
      ? l10n.monitorMcpAllowlist
      : cmds.deny.isNotEmpty
      ? '${llmL10n.permModeBypass} (-${cmds.deny.length})'
      : null;
  return cmdPart == null ? scopePart : '$scopePart · $cmdPart';
}

String _tokenSubtitle(MonitorApiToken token) {
  final used = token.lastUsedAt == null
      ? l10n.monitorMcpNeverUsed
      : '${l10n.monitorMcpLastUsed}: ${_formatUtcStamp(token.lastUsedAt!)}';
  final exp = '${l10n.monitorMcpExpires}: ${_formatUtcStamp(token.expiresAt)}';
  return '${_scopesSummary(token.scopes, token.commands)} · $used · $exp';
}

List<String> _orderedScopes(Set<String> picked) => [
  for (final s in MonitorApiToken.allScopes)
    if (picked.contains(s)) s,
];

List<String> _parseLines(String raw) => raw
    .split('\n')
    .map((l) => l.trim())
    .where((l) => l.isNotEmpty)
    .toList();

Widget _buildPermissionFields({
  required Set<String> scopes,
  Set<String>? configScopes,
  required String mode,
  required ValueChanged<String> onModeChanged,
  required TextEditingController denyCtrl,
  required TextEditingController allowCtrl,
  required StateSetter setSheet,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 7,
        runSpacing: 5,
        children: [
          for (final scope in MonitorApiToken.allScopes)
            FilterChip(
              label: Text(monitorScopeLabel(scope)),
              selected:
                  scopes.contains(scope) &&
                  (configScopes?.contains(scope) ?? true),
              onSelected:
                  (configScopes != null && !configScopes.contains(scope))
                  ? null
                  : (on) => setSheet(() {
                      on ? scopes.add(scope) : scopes.remove(scope);
                    }),
            ),
        ],
      ),
      if (scopes.contains(MonitorApiToken.scopeExec)) ...[
        UIs.height13,
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: MonitorMcpCommandPolicy.modeAllowAll,
              label: Text(llmL10n.permModeBypass),
            ),
            ButtonSegment(
              value: MonitorMcpCommandPolicy.modeAllowlist,
              label: Text(l10n.monitorMcpAllowlist),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (next) => setSheet(() => onModeChanged(next.first)),
        ),
        UIs.height7,
        Input(
          controller: denyCtrl,
          label: llmL10n.permDeny,
          hint: 'rm -rf *',
          maxLines: 3,
          minLines: 1,
          suggestion: false,
        ),
        if (mode == MonitorMcpCommandPolicy.modeAllowlist)
          Input(
            controller: allowCtrl,
            label: llmL10n.permAllow,
            hint: 'df *',
            maxLines: 3,
            minLines: 1,
            suggestion: false,
          ),
      ],
    ],
  );
}

final class _EditedPolicy {
  final List<String> scopes;
  final MonitorMcpCommandPolicy commands;

  const _EditedPolicy(this.scopes, this.commands);
}

Future<_EditedPolicy?> _askPolicy(
  BuildContext context,
  MonitorMcpPolicy initial,
) async {
  final configScopes = {...initial.configScopes};
  final scopes = {
    for (final s in initial.scopes)
      if (configScopes.contains(s)) s,
  };
  var mode = initial.commands.mode;
  final denyCtrl = TextEditingController(text: initial.commands.deny.join('\n'));
  final allowCtrl = TextEditingController(
    text: initial.commands.allow.join('\n'),
  );

  return context.showSheet<_EditedPolicy>(
    title: l10n.monitorMcpGlobalPolicy,
    child: StatefulBuilder(
      builder: (context, setSheet) => DisposeWith(
        notifiers: [denyCtrl, allowCtrl],
        child: SingleChildScrollView(
          child: _buildPermissionFields(
            scopes: scopes,
            configScopes: configScopes,
            mode: mode,
            onModeChanged: (m) => mode = m,
            denyCtrl: denyCtrl,
            allowCtrl: allowCtrl,
            setSheet: setSheet,
          ),
        ),
      ),
    ),
    actions: [
      Btn.cancel(),
      Btn.ok(
        onTap: () => context.popSheet(
          _EditedPolicy(
            _orderedScopes(scopes),
            MonitorMcpCommandPolicy(
              mode: mode,
              allow: _parseLines(allowCtrl.text),
              deny: _parseLines(denyCtrl.text),
            ),
          ),
        ),
      ),
    ],
  );
}

Future<String?> _askAndMintToken(
  BuildContext context,
  MonitorHttpClient client, {
  required bool Function() isActive,
}) async {
  final nameCtrl = TextEditingController();
  final daysCtrl = TextEditingController(text: '90');
  final passwordCtrl = TextEditingController();
  final denyCtrl = TextEditingController();
  final allowCtrl = TextEditingController();
  final scopes = {...MonitorApiToken.allScopes};
  var mode = MonitorMcpCommandPolicy.modeAllowAll;
  var submitting = false;
  BuildContext? sheetContext;

  return context.showSheet<String>(
    title: l10n.monitorMcpNewToken,
    child: StatefulBuilder(
      builder: (innerContext, setSheet) {
        sheetContext = innerContext;
        return DisposeWith(
        notifiers: [nameCtrl, daysCtrl, passwordCtrl, denyCtrl, allowCtrl],
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Input(
                controller: nameCtrl,
                label: libL10n.name,
                icon: Icons.label_outline,
                autoFocus: true,
              ),
              Input(
                controller: daysCtrl,
                label: l10n.monitorMcpDays,
                icon: Icons.timer_outlined,
                type: TextInputType.number,
                suggestion: false,
              ),
              Input(
                controller: passwordCtrl,
                label: l10n.monitorCurrentPassword,
                icon: Icons.password,
                obscureText: true,
                suggestion: false,
              ),
              UIs.height7,
              _buildPermissionFields(
                scopes: scopes,
                mode: mode,
                onModeChanged: (m) => mode = m,
                denyCtrl: denyCtrl,
                allowCtrl: allowCtrl,
                setSheet: setSheet,
              ),
            ],
          ),
        ),
      );
      },
    ),
    actions: [
      Btn.cancel(),
      Btn.ok(
        onTap: () async {
          if (submitting || !isActive()) return;
          final trimmed = nameCtrl.text.trim();
          final life = int.tryParse(daysCtrl.text.trim());
          if (trimmed.isEmpty) {
            Toast.show(l10n.monitorMcpNameRequired);
            return;
          }
          if (scopes.isEmpty) {
            Toast.show(l10n.monitorMcpScopesRequired);
            return;
          }
          if (life == null || life < 1 || life > 3650) {
            Toast.show('${libL10n.invalid}: ${l10n.monitorMcpDays}');
            return;
          }
          if (passwordCtrl.text.isEmpty) {
            Toast.show(l10n.monitorMcpPasswordRequired);
            return;
          }
          submitting = true;
          try {
            final created = await client.createApiToken(
              name: trimmed,
              password: passwordCtrl.text,
              scopes: _orderedScopes(scopes),
              commands: MonitorMcpCommandPolicy(
                mode: mode,
                allow: _parseLines(allowCtrl.text),
                deny: _parseLines(denyCtrl.text),
              ),
              days: life,
            );
            final ctx = sheetContext;
            if (ctx != null && ctx.mounted) {
              ctx.popSheet(created.value);
            }
          } catch (e) {
            if (sheetContext?.mounted == true) {
              Toast.show(monitorTokenErrText(e));
            }
          } finally {
            submitting = false;
          }
        },
      ),
    ],
  );
}

final class _EditedToken {
  final String name;
  final List<String> scopes;
  final MonitorMcpCommandPolicy commands;

  const _EditedToken(this.name, this.scopes, this.commands);
}

Future<_EditedToken?> _askEditToken(
  BuildContext context,
  MonitorApiToken token,
) async {
  final nameCtrl = TextEditingController(text: token.name);
  final denyCtrl = TextEditingController(text: token.commands.deny.join('\n'));
  final allowCtrl = TextEditingController(
    text: token.commands.allow.join('\n'),
  );
  final scopes = {...token.scopes};
  var mode = token.commands.mode;

  return context.showSheet<_EditedToken>(
    title: token.name,
    child: StatefulBuilder(
      builder: (context, setSheet) => DisposeWith(
        notifiers: [nameCtrl, denyCtrl, allowCtrl],
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Input(
                controller: nameCtrl,
                label: libL10n.name,
                icon: Icons.label_outline,
              ),
              UIs.height7,
              _buildPermissionFields(
                scopes: scopes,
                mode: mode,
                onModeChanged: (m) => mode = m,
                denyCtrl: denyCtrl,
                allowCtrl: allowCtrl,
                setSheet: setSheet,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      Btn.cancel(),
      Btn.ok(
        onTap: () {
          final trimmed = nameCtrl.text.trim();
          if (trimmed.isEmpty) {
            Toast.show(l10n.monitorMcpNameRequired);
            return;
          }
          if (scopes.isEmpty) {
            Toast.show(l10n.monitorMcpScopesRequired);
            return;
          }
          context.popSheet(
            _EditedToken(
              trimmed,
              _orderedScopes(scopes),
              MonitorMcpCommandPolicy(
                mode: mode,
                allow: _parseLines(allowCtrl.text),
                deny: _parseLines(denyCtrl.text),
              ),
            ),
          );
        },
      ),
    ],
  );
}

Future<void> _showToken(BuildContext context, String value) async {
  await context.showSheet<void>(
    title: l10n.monitorMcpCreated,
    child: SelectableText(
      value,
      style: const TextStyle(fontFamily: 'monospace', height: 1.5),
    ),
    actions: [
      Btn.text(text: libL10n.copy, onTap: () => Pfs.copy(value)),
      Btn.ok(onTap: () => context.popSheet()),
    ],
  );
}
