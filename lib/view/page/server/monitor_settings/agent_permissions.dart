// ignore_for_file: invalid_use_of_protected_member

import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/monitor/http.dart';
import 'package:server_box/data/model/server/monitor/monitor_agent.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/view/page/server/monitor_settings/widgets.dart';

/// How the agent's Agent tasks have their commands approved
/// (`/api/v1/agent/permissions`), as the panel's page of the same name.
///
/// Its own endpoint and its own save rather than a part of the settings form:
/// the agent keeps it apart from `config.toml`. Its own client too, as the
/// form's: the form replaces its client when the server's login changes.
final class MonitorAgentPermissionsPage extends StatefulWidget {
  final MonitorHttpCredential args;

  const MonitorAgentPermissionsPage({super.key, required this.args});

  static const route = AppRouteArg<void, MonitorHttpCredential>(
    page: MonitorAgentPermissionsPage.new,
    path: '/server/monitor_settings/agent_permissions',
  );

  @override
  State<MonitorAgentPermissionsPage> createState() => _MonitorAgentPermissionsPageState();
}

final class _MonitorAgentPermissionsPageState extends State<MonitorAgentPermissionsPage> {
  late final _client = MonitorHttpClient(widget.args);
  MonitorAgentPermissionsView? _view;
  Object? _err;
  bool _saving = false;

  /// Null while the agent's mode is one this app does not know.
  AgentPermissionMode? _mode;
  var _disableBypass = false;
  final _deny = TextEditingController();
  final _ask = TextEditingController();
  final _allow = TextEditingController();
  final _auto = {for (final k in AgentAutoRuleKind.values) k: TextEditingController()};
  AgentAutoRuleKind? _shown;

  /// What the agent last answered, as it would be sent: the form is dirty
  /// exactly when it would send something else.
  String? _saved;

  Iterable<TextEditingController> get _ctrls => [_deny, _ask, _allow, ..._auto.values];

  bool get _dirty => _saved != null && jsonEncode(_collect().toJson()) != _saved;

  @override
  void initState() {
    super.initState();
    for (final c in _ctrls) {
      c.addListener(_changed);
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    _client.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return PopGuard(
      enabled: _dirty,
      confirm: () => MonitorUi.confirmDiscard(context),
      child: Scaffold(
        appBar: CustomAppBar(
          title: Text(l10n.agentPermsTitle),
          actions: [
            if (_view != null)
              if (_saving)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  tooltip: libL10n.save,
                  icon: const Icon(Icons.save),
                  onPressed: _save,
                ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final err = _err;
    if (_view == null && err != null) {
      return PageIssueView(title: libL10n.error, detail: '$err', onRetry: _load);
    }
    final view = _view;
    if (view == null) return UIs.centerLoading;
    return MonitorUi.column(
      children: [
        _buildMode(),
        CenterGreyTitle(l10n.agentPermsRules),
        _buildRules(),
        CenterGreyTitle(l10n.agentPermsAutoRules),
        _buildAuto(view),
      ],
    );
  }

  Widget _buildMode() {
    final note = switch (_mode) {
      AgentPermissionMode.manual => l10n.agentPermsManualNote,
      AgentPermissionMode.auto => l10n.agentPermsAutoNote,
      AgentPermissionMode.bypass => l10n.agentPermsBypassNote,
      null => null,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(l10n.agentPermsDefaultMode),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<AgentPermissionMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: AgentPermissionMode.manual, label: Text(l10n.agentModeManual)),
                      ButtonSegment(value: AgentPermissionMode.auto, label: Text(l10n.agentModeAuto)),
                      ButtonSegment(
                        value: AgentPermissionMode.bypass,
                        label: Text(l10n.agentModeBypass),
                        enabled: !_disableBypass,
                      ),
                    ],
                    emptySelectionAllowed: true,
                    selected: {?_mode},
                    onSelectionChanged: (s) {
                      if (s.isNotEmpty) setState(() => _mode = s.first);
                    },
                  ),
                ),
                if (note != null) ...[
                  UIs.height7,
                  Text(note, style: UIs.textGrey),
                ],
              ],
            ),
          ),
        ).cardx,
        ListTile(
          title: Text(l10n.agentPermsDisableBypass),
          subtitle: Text(l10n.agentPermsDisableBypassSub, style: UIs.textGrey),
          trailing: Switch(
            value: _disableBypass,
            onChanged: (v) => setState(() {
              _disableBypass = v;
              if (v && _mode == AgentPermissionMode.bypass) _mode = AgentPermissionMode.manual;
            }),
          ),
        ).cardx,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
          child: Text(l10n.agentPermsDangerAsks, style: UIs.text12Grey),
        ),
      ],
    );
  }

  Widget _buildRules() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _lines(_deny, l10n.agentPermsDeny, 'rm -rf *'),
        _lines(_ask, l10n.agentPermsAsk, 'systemctl stop *'),
        _lines(_allow, l10n.agentPermsAllow, 'systemctl restart nginx'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
          child: Text(l10n.agentPermsRulesHint, style: UIs.text12Grey),
        ),
      ],
    );
  }

  Widget _buildAuto(MonitorAgentPermissionsView view) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
          child: Text(l10n.agentPermsAutoHint, style: UIs.text12Grey),
        ),
        for (final k in AgentAutoRuleKind.values) ...[
          _lines(_auto[k]!, _autoLabel(k), l10n.agentPermsBuiltIn),
          _buildDefaults(k, view.defaults[k] ?? const []),
        ],
      ],
    );
  }

  Widget _buildDefaults(AgentAutoRuleKind k, List<String> defaults) {
    final shown = _shown == k;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Btn.text(
            text: l10n.agentPermsShowDefaults(defaults.length),
            textStyle: UIs.text13Grey,
            onTap: () => setState(() => _shown = shown ? null : k),
          ),
        ),
        if (shown)
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 0, 17, 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final d in defaults)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text('· $d', style: UIs.text12Grey),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _lines(TextEditingController ctrl, String label, String hint) {
    return Input(
      controller: ctrl,
      label: label,
      hint: hint,
      minLines: 2,
      maxLines: 8,
      type: TextInputType.multiline,
      action: TextInputAction.newline,
      suggestion: false,
      autoCorrect: false,
    );
  }

  String _autoLabel(AgentAutoRuleKind k) => switch (k) {
    AgentAutoRuleKind.environment => l10n.agentPermsEnvironment,
    AgentAutoRuleKind.allow => l10n.agentPermsAllow,
    AgentAutoRuleKind.softDeny => l10n.agentPermsSoftDeny,
    AgentAutoRuleKind.hardDeny => l10n.agentPermsHardDeny,
  };
}

extension on _MonitorAgentPermissionsPageState {
  Future<void> _load() async {
    setState(() => _err = null);
    try {
      _fill(await _client.agentPermissions());
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  void _fill(MonitorAgentPermissionsView view) {
    final p = view.permissions;
    if (!mounted) return;
    setState(() {
      _view = view;
      _mode = p.defaultMode;
      _disableBypass = p.disableBypass;
      _deny.text = p.deny.join('\n');
      _ask.text = p.ask.join('\n');
      _allow.text = p.allow.join('\n');
      for (final k in AgentAutoRuleKind.values) {
        _auto[k]!.text = (p.autoMode[k] ?? const []).join('\n');
      }
      _saved = jsonEncode(_collect().toJson());
    });
  }

  MonitorAgentPermissions _collect() {
    List<String> lines(TextEditingController c) => [
      for (final l in c.text.split('\n'))
        if (l.trim().isNotEmpty) l.trim(),
    ];
    final base = _view?.permissions ?? const MonitorAgentPermissions();
    return base.copyWith(
      defaultMode: _mode,
      disableBypass: _disableBypass,
      deny: lines(_deny),
      ask: lines(_ask),
      allow: lines(_allow),
      autoMode: {
        // Empty is the built-in list.
        for (final k in AgentAutoRuleKind.values)
          if (lines(_auto[k]!) case final l when l.isNotEmpty) k: l,
      },
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      _fill(await _client.saveAgentPermissions(_collect()));
      Toast.show(libL10n.success);
    } catch (e) {
      if (mounted) context.showErrDialog(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
