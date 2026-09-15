// ignore_for_file: invalid_use_of_protected_member

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_push.dart';
import 'package:server_box/data/model/server/monitor_settings.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';
import 'package:server_box/view/page/server/monitor_settings/push_edit.dart';

final class MonitorSettingsArgs {
  final MonitorHttpCredential monitor;

  /// What to show under the title: the server's name, or the address when the
  /// server being edited has not been saved yet.
  final String subtitle;

  const MonitorSettingsArgs({required this.monitor, required this.subtitle});
}

/// Editor for a `monitor` agent's own configuration.
///
/// The settings are the agent's `config.toml`, and that file is the only copy:
/// this page reads it on open and writes it back on save. So it needs the
/// agent to be reachable, and says so when it is not, rather than collecting
/// edits that would have nowhere to go.
///
/// Two saves behind one button, because the agent has two endpoints. A
/// notification channel holds a credential the agent will not disclose, and
/// keeping that on its own request is what stops an edit to a collection
/// interval from being able to drop one. Each is sent only if it changed, and
/// a failure in one is reported without claiming the other did not happen.
///
/// Its own [MonitorHttpClient] rather than the one `ServerNotifier` polls
/// with: this page is reachable from the server editor before the server
/// exists, where there is no notifier to borrow from.
final class MonitorSettingsPage extends StatefulWidget {
  final MonitorSettingsArgs args;

  const MonitorSettingsPage({super.key, required this.args});

  static const route = AppRouteArg<void, MonitorSettingsArgs>(
    page: MonitorSettingsPage.new,
    path: '/server/monitor_settings',
  );

  @override
  State<MonitorSettingsPage> createState() => _MonitorSettingsPageState();
}

final class _MonitorSettingsPageState extends State<MonitorSettingsPage> {
  late final _client = MonitorHttpClient(widget.args.monitor);

  final _intervalCtrl = TextEditingController();
  final _extendedCtrl = TextEditingController();
  final _idleThresholdCtrl = TextEditingController();
  final _metricsDaysCtrl = TextEditingController();
  final _alertsDaysCtrl = TextEditingController();
  final _cleanupHoursCtrl = TextEditingController();
  final _maxDbSizeCtrl = TextEditingController();
  final _pushRateCtrl = TextEditingController();

  /// What the agent answered with, kept for [MonitorSettings.liveFields] and
  /// its retention defaults — neither of which this page may invent.
  MonitorSettings? _settings;
  MonitorPushList? _push;

  var _idlePause = true;
  var _retentionEnabled = false;
  var _rules = <MonitorRule>[];
  var _cors = <String>[];
  var _pushes = <MonitorPushEntry>[];

  String? _err;
  var _saving = false;
  var _settingsDirty = false;
  var _pushDirty = false;

  @override
  void initState() {
    super.initState();
    for (final ctrl in [
      _intervalCtrl,
      _extendedCtrl,
      _idleThresholdCtrl,
      _metricsDaysCtrl,
      _alertsDaysCtrl,
      _cleanupHoursCtrl,
      _maxDbSizeCtrl,
    ]) {
      ctrl.addListener(_markSettingsDirty);
    }
    _pushRateCtrl.addListener(_markPushDirty);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    for (final ctrl in [
      _intervalCtrl,
      _extendedCtrl,
      _idleThresholdCtrl,
      _metricsDaysCtrl,
      _alertsDaysCtrl,
      _cleanupHoursCtrl,
      _maxDbSizeCtrl,
      _pushRateCtrl,
    ]) {
      ctrl.dispose();
    }
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dirty = _settingsDirty || _pushDirty;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: CustomAppBar(
          centerTitle: true,
          title: TwoLineText(
            up: l10n.monitorSettings,
            down: widget.args.subtitle,
          ),
          actions: [
            if (_settings != null)
              if (_saving)
                const Padding(
                  padding: EdgeInsets.all(13),
                  child: SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Btn.icon(
                  text: libL10n.save,
                  icon: const Icon(Icons.save),
                  onTap: _save,
                ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }
}

// --- Widget build ---

extension on _MonitorSettingsPageState {
  Widget _buildBody() {
    final err = _err;
    if (err != null) return _buildErr(err);

    final settings = _settings;
    if (settings == null) return UIs.centerLoading;

    return ListView(
      padding: const EdgeInsets.only(left: 7, right: 7, top: 7, bottom: 27),
      children: [
        _buildCollection(settings),
        _buildIdlePause(settings),
        _buildRules(settings),
        _buildPush(),
        _buildRetention(),
        _buildCors(),
      ],
    );
  }

  Widget _buildErr(String err) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(libL10n.error, style: UIs.text18),
          UIs.height13,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 27),
            child: Text(err, style: UIs.textGrey, textAlign: TextAlign.center),
          ),
          UIs.height13,
          Btn.text(text: libL10n.retry, onTap: _load),
        ],
      ),
    );
  }

  /// Says whether the field above it is picked up by the running agent or
  /// waits for a restart. Read off what the agent reported rather than a copy
  /// here: the set has changed before, and a wrong answer here is one the user
  /// only finds out about by an alert that never comes.
  Widget _effectNote(MonitorSettings settings, String field) {
    return Padding(
      padding: const EdgeInsets.only(left: 17, bottom: 7),
      child: Text(
        settings.isLive(field) ? l10n.monitorAppliesNow : l10n.monitorNeedsRestart,
        style: UIs.textGrey,
      ),
    );
  }

  Widget _buildCollection(MonitorSettings settings) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle(l10n.updateServerStatusInterval),
        Input(
          controller: _intervalCtrl,
          label: '${l10n.updateServerStatusInterval} (${libL10n.second})',
          type: TextInputType.number,
          suggestion: false,
        ),
        _effectNote(settings, 'interval_seconds'),
        Input(
          controller: _extendedCtrl,
          label: '${l10n.extendedInterval} (${libL10n.second})',
          hint: l10n.monitorAgentDefault,
          type: TextInputType.number,
          suggestion: false,
        ),
        _effectNote(settings, 'extended_interval_secs'),
      ],
    );
  }

  Widget _buildIdlePause(MonitorSettings settings) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle(l10n.idlePause),
        ListTile(
          leading: const Icon(Icons.pause_circle_outline),
          title: TipText(l10n.idlePause, l10n.idlePauseTip),
          trailing: Switch(
            value: _idlePause,
            onChanged: (value) => setState(() {
              _idlePause = value;
              _settingsDirty = true;
            }),
          ),
        ).cardx,
        Input(
          controller: _idleThresholdCtrl,
          label: '${l10n.idlePauseThreshold} (${libL10n.second})',
          hint: l10n.monitorAgentDefault,
          type: TextInputType.number,
          suggestion: false,
        ),
        _effectNote(settings, 'idle_pause_enabled'),
      ],
    );
  }

  Widget _buildRules(MonitorSettings settings) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle(l10n.monitoringRules),
        for (final (idx, rule) in _rules.indexed)
          ListTile(
            leading: const Icon(MingCute.alert_line),
            title: Text(rule.name.isEmpty ? libL10n.empty : rule.name),
            subtitle: Text(
              '${rule.monitorType} ${rule.matcher} ${rule.threshold}',
              style: UIs.textGrey,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, size: 19),
              onPressed: () => setState(() {
                _rules.removeAt(idx);
                _settingsDirty = true;
              }),
            ),
            onTap: () => _editRule(idx),
          ).cardx,
        Btn.text(text: libL10n.add, onTap: () => _editRule(null)),
        _effectNote(settings, 'rules'),
      ],
    );
  }

  Widget _buildPush() {
    final push = _push;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle(l10n.pushChannels),
        Input(
          controller: _pushRateCtrl,
          label: l10n.pushRate,
          hint: '1/1m',
          suggestion: false,
        ),
        for (final (idx, entry) in _pushes.indexed)
          ListTile(
            leading: const Icon(MingCute.notification_line),
            title: Text(entry.name.isEmpty ? libL10n.empty : entry.name),
            subtitle: Text(entry.pushType, style: UIs.textGrey),
            trailing: IconButton(
              icon: const Icon(Icons.delete, size: 19),
              onPressed: () => setState(() {
                _pushes.removeAt(idx);
                _pushDirty = true;
              }),
            ),
            onTap: () => _editPush(idx),
          ).cardx,
        Btn.text(text: libL10n.add, onTap: () => _editPush(null)),
        if (push?.appliesOnRestart ?? true)
          Padding(
            padding: const EdgeInsets.only(left: 17, bottom: 7),
            child: Text(l10n.monitorNeedsRestart, style: UIs.textGrey),
          ),
      ],
    );
  }

  Widget _buildRetention() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle(l10n.dataRetention),
        ListTile(
          leading: const Icon(Icons.auto_delete_outlined),
          title: TipText(l10n.dataRetention, l10n.dataRetentionTip),
          trailing: Switch(
            value: _retentionEnabled,
            onChanged: (value) => setState(() {
              _retentionEnabled = value;
              _settingsDirty = true;
            }),
          ),
        ).cardx,
        if (_retentionEnabled) ...[
          Input(
            controller: _metricsDaysCtrl,
            label: '${l10n.retentionMetrics} (${libL10n.day})',
            type: TextInputType.number,
            suggestion: false,
          ),
          Input(
            controller: _alertsDaysCtrl,
            label: '${l10n.retentionAlerts} (${libL10n.day})',
            type: TextInputType.number,
            suggestion: false,
          ),
          Input(
            controller: _cleanupHoursCtrl,
            label: '${l10n.retentionCleanup} (${libL10n.hour})',
            type: TextInputType.number,
            suggestion: false,
          ),
          Input(
            controller: _maxDbSizeCtrl,
            label: '${l10n.retentionMaxDbSize} (MB)',
            type: TextInputType.number,
            suggestion: false,
          ),
        ],
      ],
    );
  }

  Widget _buildCors() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle(l10n.corsOrigins),
        for (final (idx, origin) in _cors.indexed)
          ListTile(
            leading: const Icon(MingCute.web_line),
            title: Text(origin),
            trailing: IconButton(
              icon: const Icon(Icons.delete, size: 19),
              onPressed: () => setState(() {
                _cors.removeAt(idx);
                _settingsDirty = true;
              }),
            ),
          ).cardx,
        Btn.text(text: libL10n.add, onTap: _addOrigin),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17),
          child: Text(l10n.corsOriginsTip, style: UIs.textGrey),
        ),
      ],
    );
  }
}

// --- Actions ---

extension on _MonitorSettingsPageState {
  Future<void> _load() async {
    setState(() {
      _err = null;
      _settings = null;
    });
    try {
      // Sequential rather than concurrent: both go through the same session,
      // and a first request that has to log in is what the second one waits
      // for anyway.
      final settings = await _client.fetchSettings();
      final push = await _client.fetchPush();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _push = push;
        _apply(settings, push);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e');
    }
  }

  Future<void> _save() async {
    final settings = _settings;
    if (settings == null) return;
    setState(() => _saving = true);

    final failures = <String>[];
    if (_settingsDirty) {
      try {
        await _client.saveSettings(_collectSettings(settings));
        _settingsDirty = false;
      } catch (e) {
        failures.add('$e');
      }
    }
    if (_pushDirty) {
      try {
        // Answers with the saved set read back: after a reorder the
        // `from_index` an editor needs next are the new positions, so what
        // comes back replaces what is on screen.
        final rate = _pushRateCtrl.text.trim();
        final saved = await _client.savePush(
          // Blank is the agent's default of one a minute, expressed as null —
          // an empty string is not a rate it can read.
          MonitorPushList(pushes: _pushes, pushRate: rate.isEmpty ? null : rate),
        );
        _push = saved;
        _pushes = [...saved.pushes];
        _pushDirty = false;
      } catch (e) {
        failures.add('$e');
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (failures.isEmpty) {
      Toast.show(libL10n.saved);
    } else {
      // Named one by one: a failure in one half says nothing about the other,
      // which may well have been written.
      context.showRoundDialog(
        title: libL10n.error,
        child: Text(failures.join('\n\n')),
        actions: Btnx.oks,
      );
    }
  }

  Future<void> _editRule(int? idx) async {
    final rule = idx == null ? null : _rules[idx];
    final name = TextEditingController(text: rule?.name ?? '');
    final type = TextEditingController(text: rule?.monitorType ?? 'cpu');
    final threshold = TextEditingController(text: rule?.threshold ?? '>=80%');
    final matcher = TextEditingController(text: rule?.matcher ?? 'cpu');

    final ok = await context.showRoundDialog<bool>(
      title: l10n.monitoringRules,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Input(controller: name, label: libL10n.name, suggestion: false),
            Input(
              controller: type,
              label: l10n.ruleMonitorType,
              hint: 'cpu / memory / disk / network / temperature',
              suggestion: false,
            ),
            Input(
              controller: threshold,
              label: l10n.ruleThreshold,
              hint: '>=80%',
              suggestion: false,
            ),
            Input(
              controller: matcher,
              label: l10n.ruleMatcher,
              hint: 'cpu / used / rx',
              suggestion: false,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Text(l10n.ruleTip, style: UIs.textGrey),
            ),
          ],
        ),
      ),
      actions: Btnx.cancelOk,
    );

    final edited = MonitorRule(
      name: name.text.trim(),
      monitorType: type.text.trim(),
      threshold: threshold.text.trim(),
      matcher: matcher.text.trim(),
    );
    for (final ctrl in [name, type, threshold, matcher]) {
      ctrl.dispose();
    }
    if (ok != true || !mounted) return;

    setState(() {
      if (idx == null) {
        _rules.add(edited);
      } else {
        _rules[idx] = edited;
      }
      _settingsDirty = true;
    });
  }

  Future<void> _editPush(int? idx) async {
    final push = _push;
    final entry =
        idx == null
            ? const MonitorPushEntry(name: '', pushType: 'webhook')
            : _pushes[idx];
    final edited = await MonitorPushEditPage.route.go(
      context,
      MonitorPushEditArgs(
        entry: entry,
        pushTypes: push?.pushTypes ?? const [],
        client: _client,
      ),
    );
    if (edited == null || !mounted) return;
    setState(() {
      if (idx == null) {
        _pushes.add(edited);
      } else {
        _pushes[idx] = edited;
      }
      _pushDirty = true;
    });
  }

  Future<void> _addOrigin() async {
    final ctrl = TextEditingController();
    final ok = await context.showRoundDialog<bool>(
      title: l10n.corsOrigins,
      child: Input(
        controller: ctrl,
        label: 'URL',
        hint: 'https://panel.example.com',
        type: TextInputType.url,
        suggestion: false,
      ),
      actions: Btnx.cancelOk,
    );
    final origin = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || origin.isEmpty || !mounted) return;
    if (_cors.contains(origin)) return;
    setState(() {
      _cors.add(origin);
      _settingsDirty = true;
    });
  }

  Future<void> _confirmDiscard() async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(libL10n.askContinue(libL10n.delete)),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    context.pop();
  }
}

// --- Utils ---

extension on _MonitorSettingsPageState {
  void _markSettingsDirty() => _settingsDirty = true;
  void _markPushDirty() => _pushDirty = true;

  void _apply(MonitorSettings settings, MonitorPushList push) {
    _intervalCtrl.text = '${settings.intervalSeconds}';
    _extendedCtrl.text = settings.extendedIntervalSecs?.toString() ?? '';
    _idlePause = settings.idlePauseEnabled;
    _idleThresholdCtrl.text = settings.idlePauseThresholdSecs?.toString() ?? '';
    _rules = [...settings.rules];
    _cors = [...settings.corsAllowedOrigins];

    // Switched off, the boxes show the agent's own defaults, so switching it
    // on is a save away rather than four fields to fill in. Absent means no
    // cleanup runs at all, which is why this is a switch and not four blanks.
    _retentionEnabled = settings.dataRetention != null;
    final retention = settings.dataRetention ?? settings.dataRetentionDefaults;
    _metricsDaysCtrl.text = '${retention.metricsDays}';
    _alertsDaysCtrl.text = '${retention.alertsDays}';
    _cleanupHoursCtrl.text = '${retention.cleanupIntervalHours}';
    _maxDbSizeCtrl.text = '${retention.maxDbSizeMb}';

    _pushes = [...push.pushes];
    _pushRateCtrl.text = push.pushRate ?? '';

    // Filling the boxes fires their listeners; nothing here is a user edit.
    _settingsDirty = false;
    _pushDirty = false;
  }

  MonitorSettings _collectSettings(MonitorSettings loaded) {
    return loaded.copyWith(
      intervalSeconds:
          int.tryParse(_intervalCtrl.text.trim()) ?? loaded.intervalSeconds,
      extendedIntervalSecs: () => int.tryParse(_extendedCtrl.text.trim()),
      idlePauseEnabled: _idlePause,
      idlePauseThresholdSecs: () => int.tryParse(_idleThresholdCtrl.text.trim()),
      rules: _rules,
      dataRetention: () => _retentionEnabled
          ? MonitorDataRetention(
              metricsDays: int.tryParse(_metricsDaysCtrl.text.trim()) ?? 30,
              alertsDays: int.tryParse(_alertsDaysCtrl.text.trim()) ?? 90,
              cleanupIntervalHours:
                  int.tryParse(_cleanupHoursCtrl.text.trim()) ?? 24,
              maxDbSizeMb: int.tryParse(_maxDbSizeCtrl.text.trim()) ?? 0,
            )
          : null,
      corsAllowedOrigins: _cors,
    );
  }
}
