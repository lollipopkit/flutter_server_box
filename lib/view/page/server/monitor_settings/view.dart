// ignore_for_file: invalid_use_of_protected_member

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_push.dart';
import 'package:server_box/data/model/server/monitor_settings.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';
import 'package:server_box/view/page/server/monitor_settings/lists.dart';
import 'package:server_box/view/page/server/monitor_settings/widgets.dart';

/// The bar's half of [MonitorSettingsView].
///
/// The view owns the form and the two requests; whoever hosts it owns the bar
/// the save button sits in — `MonitorSettingsPage`'s app bar when it was
/// opened from a server, and the tab's own bar when it is a column of one. So
/// what that button needs to know lives here and the view drives it, rather
/// than each host reaching into the view's state.
final class MonitorSettingsController extends ChangeNotifier {
  bool _ready = false;
  bool _saving = false;
  bool _dirty = false;
  Future<void> Function()? _save;

  /// Whether the agent has answered. Nothing can be saved before it has.
  bool get ready => _ready;
  bool get saving => _saving;

  /// Whether there are edits the agent has not been told about. Read by a host
  /// that has somewhere to navigate away to.
  bool get dirty => _dirty;

  Future<void> save() async => _save?.call();

  void _bind(Future<void> Function() save) => _save = save;

  void _set({bool? ready, bool? saving, bool? dirty}) {
    final changed =
        (ready != null && ready != _ready) ||
        (saving != null && saving != _saving) ||
        (dirty != null && dirty != _dirty);
    _ready = ready ?? _ready;
    _saving = saving ?? _saving;
    _dirty = dirty ?? _dirty;
    if (changed) notifyListeners();
  }
}

/// Editor for a `monitor` agent's own configuration.
///
/// The settings are the agent's `config.toml`, and that file is the only copy:
/// this reads it on open and writes it back on save. So it needs the agent to
/// be reachable, and says so when it is not, rather than collecting edits that
/// would have nowhere to go.
///
/// Two saves behind one button, because the agent has two endpoints. A
/// notification channel holds a credential the agent will not disclose, and
/// keeping that on its own request is what stops an edit to a collection
/// interval from being able to drop one. Each is sent only if it changed, and
/// a failure in one is reported without claiming the other did not happen.
///
/// A widget rather than a page, because one of its two hosts is a tab column:
/// choosing a different agent there rebuilds the column, and pushing a route
/// instead would stack one copy per choice. The page wrapper is
/// `MonitorSettingsPage`.
///
/// Its own [MonitorHttpClient] rather than the one `ServerNotifier` polls
/// with: what this edits is the agent's own configuration, which is asked of
/// `Spix.monitor` directly — `ServerConnectCredential.fromSpi` may answer SSH
/// for a server that has both.
final class MonitorSettingsView extends StatefulWidget {
  final MonitorHttpCredential monitor;

  /// Driven by this view, read by whoever draws the bar. Optional, because a
  /// host with no bar of its own does not need one.
  final MonitorSettingsController? controller;

  const MonitorSettingsView({
    super.key,
    required this.monitor,
    this.controller,
  });

  @override
  State<MonitorSettingsView> createState() => _MonitorSettingsViewState();
}

final class _MonitorSettingsViewState extends State<MonitorSettingsView> {
  late var _client = MonitorHttpClient(widget.monitor);

  /// Bumped by every [_load]. An answer that comes back from an earlier one —
  /// after the credential was edited under this view, which the tab's key does
  /// not catch because the server is the same — must not land in the form.
  var _loadGeneration = 0;

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

  // Through setters so every assignment reaches the controller, of which there
  // are a dozen scattered across the form below. A `_syncController()` call
  // beside each one is a call that will eventually be forgotten beside a new
  // one.
  var _savingValue = false;
  var _settingsDirtyValue = false;
  var _pushDirtyValue = false;

  // Write-only: what reads it is the bar, which belongs to the host and asks
  // the controller.
  set _saving(bool value) {
    _savingValue = value;
    _syncController();
  }

  bool get _settingsDirty => _settingsDirtyValue;
  set _settingsDirty(bool value) {
    _settingsDirtyValue = value;
    _syncController();
  }

  bool get _pushDirty => _pushDirtyValue;
  set _pushDirty(bool value) {
    _pushDirtyValue = value;
    _syncController();
  }

  void _syncController() {
    widget.controller?._set(
      ready: _settings != null && _err == null,
      saving: _savingValue,
      dirty: _settingsDirtyValue || _pushDirtyValue,
    );
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._bind(_save);
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
    // The controller outlives any one view — the tab keeps one per server — so
    // a fresh view has to say so, or the bar goes on showing the save button
    // and the dirty flag the previous one left behind.
    _syncController();
    Future.microtask(_load);
  }

  /// The same server can arrive with a different address, login or TLS
  /// setting — edited in the server editor while this view is alive behind
  /// another tab. The key the tab gives this widget is the server's id, so
  /// that case rebuilds nothing and the old session would go on being used.
  @override
  void didUpdateWidget(covariant MonitorSettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.monitor == oldWidget.monitor) return;
    _client.dispose();
    _client = MonitorHttpClient(widget.monitor);
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
  Widget build(BuildContext context) => _buildBody();
}

// --- Widget build ---

extension on _MonitorSettingsViewState {
  Widget _buildBody() {
    final err = _err;
    if (err != null) return _buildErr(err);

    final settings = _settings;
    if (settings == null) return UIs.centerLoading;

    // The same grid the server editor lays its form out in, rather than a
    // full-width list. This is a form of the same kind and the same length, and
    // on a tablet or a desktop window one column of it spanning the whole
    // surface is a line of text nobody can follow from end to end.
    //
    // Each entry below is one group. A group rather than a field, because the
    // grid places its children across the columns in turn — field by field,
    // a section's heading and the boxes under it would land in different
    // columns.
    //
    // Each carries a heading, and the heading names the category rather than
    // the first row under it: a title that repeats the label below it is the
    // reason these were dropped once. It is also what makes the grid's own
    // spacing between two groups readable — without it, the extra four points
    // where one group ends is a gap belonging to nothing.
    return PageColumns(
      children: [
        _buildCollection(settings),
        _buildAlerts(settings),
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

  Widget _buildCollection(MonitorSettings settings) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle(l10n.monitorCollection),
        Input(
          controller: _intervalCtrl,
          label: '${l10n.updateServerStatusInterval} (${libL10n.second})',
          icon: Icons.timer_outlined,
          type: TextInputType.number,
          suggestion: false,
        ),
        MonitorUi.effectNote(settings, 'interval_seconds'),
        Input(
          controller: _extendedCtrl,
          label: '${l10n.extendedInterval} (${libL10n.second})',
          hint: l10n.monitorAgentDefault,
          icon: Icons.more_time,
          type: TextInputType.number,
          suggestion: false,
        ),
        MonitorUi.effectNote(settings, 'extended_interval_secs'),
        ListTile(
          leading: const Icon(Icons.pause_circle_outline),
          title: TipText(l10n.idlePause, l10n.idlePauseTip),
          trailing: SwitchX(
            value: _idlePause,
            onChanged: (value) => setState(() {
              _idlePause = value;
              _settingsDirty = true;
            }),
          ),
        ).cardx,
        MonitorUi.effectNote(settings, 'idle_pause_enabled'),
        Input(
          controller: _idleThresholdCtrl,
          label: '${l10n.idlePauseThreshold} (${libL10n.second})',
          hint: l10n.monitorAgentDefault,
          icon: Icons.hourglass_empty,
          type: TextInputType.number,
          suggestion: false,
        ),
        // Its own field, not the switch's. Both are live today, so both draw
        // nothing and passing the wrong one here would look identical —
        // `live_fields` is the agent's answer and has changed before, and the
        // day it moves one of these two the mark has to land on the right box.
        MonitorUi.effectNote(settings, 'idle_pause_threshold_secs'),
      ],
    );
  }

  /// When to alert, and where the alert goes.
  ///
  /// One group because they are one decision split in two: a rule decides that
  /// something is wrong and a channel decides who hears about it, and either
  /// one alone does nothing. Each is a row that opens a page — laid out here
  /// the two lists were most of the form.
  Widget _buildAlerts(MonitorSettings settings) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle(l10n.monitorAlerts),
        MonitorUi.navTile(
          icon: MingCute.alert_line,
          title: l10n.monitoringRules,
          names: [for (final rule in _rules) rule.name],
          onTap: () => MonitorRulesPage.route.go(
            context,
            MonitorRulesArgs(
              rules: _rules,
              settings: settings,
              onChanged: (rules) => setState(() {
                _rules = rules;
                _settingsDirty = true;
              }),
            ),
          ),
        ),
        MonitorUi.navTile(
          icon: MingCute.notification_line,
          title: l10n.pushChannels,
          names: [for (final entry in _pushes) entry.name],
          onTap: () => MonitorPushListPage.route.go(
            context,
            MonitorPushListArgs(
              pushes: _pushes,
              push: _push,
              rateCtrl: _pushRateCtrl,
              client: _client,
              onChanged: (pushes) => setState(() {
                _pushes = pushes;
                _pushDirty = true;
              }),
            ),
          ),
        ),
      ],
    );
  }

  /// Who may reach this agent from a browser.
  ///
  /// Its own group rather than a row among the alert lists: what it decides is
  /// which origins the agent answers, which is nothing to do with when it
  /// alerts. One row under a heading is what the server editor gives PVE and
  /// BMC too.
  Widget _buildCors() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle(libL10n.network),
        MonitorUi.navTile(
          icon: MingCute.web_line,
          title: l10n.corsOrigins,
          names: _cors,
          onTap: () => MonitorCorsPage.route.go(
            context,
            MonitorCorsArgs(
              origins: _cors,
              onChanged: (origins) => setState(() {
                _cors = origins;
                _settingsDirty = true;
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRetention() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle(libL10n.storage),
        ListTile(
          leading: const Icon(Icons.auto_delete_outlined),
          title: TipText(l10n.dataRetention, l10n.dataRetentionTip),
          trailing: SwitchX(
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
            icon: Icons.show_chart,
            type: TextInputType.number,
            suggestion: false,
          ),
          Input(
            controller: _alertsDaysCtrl,
            label: '${l10n.retentionAlerts} (${libL10n.day})',
            icon: MingCute.alert_line,
            type: TextInputType.number,
            suggestion: false,
          ),
          Input(
            controller: _cleanupHoursCtrl,
            label: '${l10n.retentionCleanup} (${libL10n.hour})',
            icon: Icons.cleaning_services_outlined,
            type: TextInputType.number,
            suggestion: false,
          ),
          Input(
            controller: _maxDbSizeCtrl,
            label: '${l10n.retentionMaxDbSize} (MB)',
            icon: Icons.storage,
            type: TextInputType.number,
            suggestion: false,
          ),
        ],
      ],
    );
  }

}

// --- Actions ---

extension on _MonitorSettingsViewState {
  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final client = _client;
    setState(() {
      _err = null;
      _settings = null;
    });
    _syncController();
    try {
      // Sequential rather than concurrent: both go through the same session,
      // and a first request that has to log in is what the second one waits
      // for anyway.
      final settings = await client.fetchSettings();
      final push = await client.fetchPush();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _settings = settings;
        _push = push;
        _apply(settings, push);
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _err = '$e');
    }
    _syncController();
  }

  Future<void> _save() async {
    final settings = _settings;
    if (settings == null) return;

    // Before either request: a rejected field must not leave the push half
    // saved and the settings half not, which is what validating inside the
    // first request would do.
    final retention = _retention();
    if (retention.invalid case final field?) {
      Toast.show('${libL10n.invalid}: $field');
      return;
    }

    setState(() => _saving = true);

    final failures = <String>[];
    if (_settingsDirty) {
      try {
        await _client.saveSettings(_collectSettings(settings, retention.value));
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

}

// --- Utils ---

extension on _MonitorSettingsViewState {
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

  /// The retention fields, or the label of the first one the agent would
  /// refuse.
  ///
  /// No local fallbacks. A blank box used to become a hardcoded 30/90/24 — a
  /// second copy of the agent's defaults, which is what `dataRetentionDefaults`
  /// exists to avoid — and a blank size cap became 0, which is not a default
  /// but *no cap at all*. The bounds mirror `DataRetentionConfig::validate`;
  /// the agent checks them again, and would have, but never saw the blank.
  ({MonitorDataRetention? value, String? invalid}) _retention() {
    if (!_retentionEnabled) return (value: null, invalid: null);

    final metrics = int.tryParse(_metricsDaysCtrl.text.trim());
    if (metrics == null || metrics < 1) {
      return (value: null, invalid: l10n.retentionMetrics);
    }
    final alerts = int.tryParse(_alertsDaysCtrl.text.trim());
    if (alerts == null || alerts < 1) {
      return (value: null, invalid: l10n.retentionAlerts);
    }
    final cleanup = int.tryParse(_cleanupHoursCtrl.text.trim());
    if (cleanup == null || cleanup < 1) {
      return (value: null, invalid: l10n.retentionCleanup);
    }
    // 0 is the one legitimate zero here: it turns the cap off.
    final maxDb = int.tryParse(_maxDbSizeCtrl.text.trim());
    if (maxDb == null || maxDb < 0) {
      return (value: null, invalid: l10n.retentionMaxDbSize);
    }

    return (
      value: MonitorDataRetention(
        metricsDays: metrics,
        alertsDays: alerts,
        cleanupIntervalHours: cleanup,
        maxDbSizeMb: maxDb,
      ),
      invalid: null,
    );
  }

  MonitorSettings _collectSettings(
    MonitorSettings loaded,
    MonitorDataRetention? retention,
  ) {
    return loaded.copyWith(
      intervalSeconds:
          int.tryParse(_intervalCtrl.text.trim()) ?? loaded.intervalSeconds,
      extendedIntervalSecs: () => int.tryParse(_extendedCtrl.text.trim()),
      idlePauseEnabled: _idlePause,
      idlePauseThresholdSecs: () => int.tryParse(_idleThresholdCtrl.text.trim()),
      rules: _rules,
      dataRetention: () => retention,
      corsAllowedOrigins: _cors,
    );
  }
}
