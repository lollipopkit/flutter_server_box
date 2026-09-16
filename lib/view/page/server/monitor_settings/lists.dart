/// The three collections a `monitor` agent's settings hold, each on a page of
/// its own.
///
/// Pages rather than sections of the settings form: laid out there they were
/// most of its length, so the intervals at the top could not be reached without
/// scrolling past every rule and channel a configured agent happens to have.
///
/// Each takes the list it edits and a callback, rather than answering with the
/// edited list when it closes. A page can be left by a back gesture, which
/// answers `null` and cannot be told apart from "changed nothing"; reporting
/// each change as it is made means the form's dirty flag is set exactly when
/// something actually changed.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/monitor_push.dart';
import 'package:server_box/data/model/server/monitor_settings.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/view/page/server/monitor_settings/push_edit.dart';
import 'package:server_box/view/page/server/monitor_settings/widgets.dart';


/// What a rule's `monitor_type` may be, in the spellings the agent's
/// `RuleKind::parse` (`monitor/src/monitoring/rules.rs`) canonicalises to.
///
/// Offered rather than typed because the agent answers an unrecognised one with
/// a `warn!` in its own log and a rule that never fires again — nothing reaches
/// this app, so a typo here is an alert that silently stops arriving. The
/// aliases a migrated Go config holds (`mem`, `net`, `temp`) are still accepted
/// and are not offered; one already in a rule is kept, the way
/// [MonitorPushEditPage] keeps a push type it no longer offers.
const _kRuleTypes = [
  'cpu',
  'memory',
  'swap',
  'disk',
  'network',
  'temperature',
];

/// Metrics whose `matcher` the agent reads and ignores — see the docs page this
/// list links to, and `check_disk_rule` / `check_temperature_rule`.
const _kIgnoresMatcher = {'disk', 'temperature', 'temp'};

// --- Alert rules ---

final class MonitorRulesArgs {
  final List<MonitorRule> rules;

  /// What the agent answered with, for the live/restart note under the list.
  final MonitorSettings settings;

  final void Function(List<MonitorRule>) onChanged;

  const MonitorRulesArgs({
    required this.rules,
    required this.settings,
    required this.onChanged,
  });
}

final class MonitorRulesPage extends StatefulWidget {
  final MonitorRulesArgs args;

  const MonitorRulesPage({super.key, required this.args});

  static const route = AppRouteArg<void, MonitorRulesArgs>(
    page: MonitorRulesPage.new,
    path: '/server/monitor_settings/rules',
  );

  @override
  State<MonitorRulesPage> createState() => _MonitorRulesPageState();
}

final class _MonitorRulesPageState extends State<MonitorRulesPage> {
  late final _rules = [...widget.args.rules];

  void _edited(void Function() change) {
    setState(change);
    widget.args.onChanged([..._rules]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.monitoringRules)),
      body: MonitorUi.column(
        children: [
          // The docs site rather than a paragraph here. What is worth knowing
          // about a rule is what a form cannot show: that a threshold with no
          // comparator means `<`, that a unit which does not fit its metric
          // never fires, and that a network rule is quiet for one cycle after
          // the agent starts. None of that fits beside a text box, and all of
          // it is the difference between a rule that works and one that is
          // silently inactive.
          ListTile(
            leading: const Icon(MingCute.doc_line),
            title: Text(libL10n.doc),
            trailing: const Icon(Icons.open_in_new, size: 17),
            onTap: Urls.monitorRulesDoc.launchUrl,
          ).cardx,
          for (final (idx, rule) in _rules.indexed)
            ListTile(
              leading: MonitorUi.index(idx),
              title: Text(rule.name.isEmpty ? libL10n.empty : rule.name),
              subtitle: Text(_summary(rule), style: UIs.textGrey),
              trailing: IconButton(
                icon: const Icon(Icons.delete, size: 19),
                onPressed: () => _edited(() => _rules.removeAt(idx)),
              ),
              onTap: () => _editRule(idx),
            ).cardx,
          MonitorUi.addBtn(() => _editRule(null)),
          MonitorUi.effectNote(widget.args.settings, 'rules'),
        ],
      ),
    );
  }

  /// What a rule watches, with the parts that say nothing left out.
  ///
  /// The agent ignores `matcher` for a disk or a temperature rule, and for a
  /// whole-CPU rule it repeats the metric — the row read `cpu cpu >=80%`. Shown
  /// only where it picks something out: one core, one memory field, one
  /// direction.
  String _summary(MonitorRule rule) {
    final type = rule.monitorType;
    final matcher = rule.matcher.trim();
    final picks =
        matcher.isNotEmpty &&
        matcher != type &&
        !_kIgnoresMatcher.contains(type);
    return picks
        ? '$type · $matcher ${rule.threshold}'
        : '$type ${rule.threshold}';
  }

  Future<void> _editRule(int? idx) async {
    final rule = idx == null ? null : _rules[idx];
    final name = TextEditingController(text: rule?.name ?? '');
    final threshold = TextEditingController(text: rule?.threshold ?? '>=80%');
    final matcher = TextEditingController(text: rule?.matcher ?? 'cpu');
    var type = rule?.monitorType ?? _kRuleTypes.first;

    final ok = await context.showRoundDialog<bool>(
      title: l10n.monitoringRules,
      child: SingleChildScrollView(
        child: StatefulBuilder(
          builder: (_, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Input(
                controller: name,
                label: libL10n.name,
                icon: BoxIcons.bx_rename,
                suggestion: false,
              ),
              // Whatever the rule already says is in the list, so a spelling
              // the agent accepts but no longer offers cannot be lost by
              // opening the rule that holds it.
              ListTile(
                leading: const Icon(MingCute.alert_line),
                title: Text(l10n.ruleMonitorType),
                trailing: PopupMenu<String>(
                  initialValue: type,
                  items: [
                    for (final e in {..._kRuleTypes, type})
                      PopupMenuItem(value: e, child: Text(e)),
                  ],
                  onSelected: (value) => setDialogState(() => type = value),
                  child: Text(type),
                ),
              ).cardx,
              Input(
                controller: threshold,
                label: l10n.ruleThreshold,
                icon: Icons.show_chart,
                hint: '>=80%',
                suggestion: false,
              ),
              Input(
                controller: matcher,
                label: l10n.ruleMatcher,
                icon: MingCute.search_line,
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
      ),
      actions: Btnx.cancelOk,
    );

    final edited = MonitorRule(
      name: name.text.trim(),
      monitorType: type,
      threshold: threshold.text.trim(),
      matcher: matcher.text.trim(),
    );
    for (final ctrl in [name, threshold, matcher]) {
      ctrl.dispose();
    }
    if (ok != true || !mounted) return;

    _edited(() {
      if (idx == null) {
        _rules.add(edited);
      } else {
        _rules[idx] = edited;
      }
    });
  }
}

// --- Notification channels ---

final class MonitorPushListArgs {
  final List<MonitorPushEntry> pushes;

  /// What the agent answered with: the types it can deliver through, and
  /// whether its push configuration needs a restart.
  final MonitorPushList? push;

  /// The rate limit, owned and disposed by the settings form — its listener is
  /// what marks the push half dirty.
  final TextEditingController rateCtrl;

  /// Borrowed, not owned: a test send goes through the same session the list
  /// was loaded with, so a withheld credential resolves against the same agent.
  final MonitorHttpClient client;

  final void Function(List<MonitorPushEntry>) onChanged;

  const MonitorPushListArgs({
    required this.pushes,
    required this.push,
    required this.rateCtrl,
    required this.client,
    required this.onChanged,
  });
}

final class MonitorPushListPage extends StatefulWidget {
  final MonitorPushListArgs args;

  const MonitorPushListPage({super.key, required this.args});

  static const route = AppRouteArg<void, MonitorPushListArgs>(
    page: MonitorPushListPage.new,
    path: '/server/monitor_settings/pushes',
  );

  @override
  State<MonitorPushListPage> createState() => _MonitorPushListPageState();
}

final class _MonitorPushListPageState extends State<MonitorPushListPage> {
  late final _pushes = [...widget.args.pushes];

  void _edited(void Function() change) {
    setState(change);
    widget.args.onChanged([..._pushes]);
  }

  @override
  Widget build(BuildContext context) {
    final push = widget.args.push;
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.pushChannels)),
      body: MonitorUi.column(
        children: [
          Input(
            controller: widget.args.rateCtrl,
            label: l10n.pushRate,
            hint: '1/1m',
            icon: Icons.speed,
            suggestion: false,
          ),
          for (final (idx, entry) in _pushes.indexed)
            ListTile(
              leading: MonitorUi.index(idx),
              title: Text(entry.name.isEmpty ? libL10n.empty : entry.name),
              subtitle: Text(entry.pushType, style: UIs.textGrey),
              trailing: IconButton(
                icon: const Icon(Icons.delete, size: 19),
                onPressed: () => _removePush(idx),
              ),
              onTap: () => _editPush(idx),
            ).cardx,
          MonitorUi.addBtn(() => _editPush(null)),
          if (push?.appliesOnRestart ?? true)
            Padding(
              padding: const EdgeInsets.only(left: 17, right: 17, bottom: 7),
              child: MonitorUi.restartNote(),
            ),
        ],
      ),
    );
  }

  /// The one list here that asks before it removes a row.
  ///
  /// Not a general rule about deleting, but about what this row holds: a
  /// channel's credential was never disclosed to this app — `null` in its
  /// config means "set on the agent, not shown" — so once the removal is saved,
  /// neither the agent nor this page nor the screen it was read off has it any
  /// more. A rule and a CORS origin are both entirely visible in the row that
  /// holds them, can be typed back from what is on screen, and go on one tap.
  Future<void> _removePush(int idx) async {
    final entry = _pushes[idx];
    final name = entry.name.isEmpty ? libL10n.empty : entry.name;
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(
        libL10n.askContinue('${libL10n.delete} ${l10n.pushChannels}($name)'),
      ),
      actions: Btn.ok(red: true).toList,
    );
    if (ok != true || !mounted) return;
    _edited(() => _pushes.removeAt(idx));
  }

  Future<void> _editPush(int? idx) async {
    final push = widget.args.push;
    final entry = idx == null
        ? const MonitorPushEntry(name: '', pushType: 'webhook')
        : _pushes[idx];
    final edited = await MonitorPushEditPage.route.go(
      context,
      MonitorPushEditArgs(
        entry: entry,
        pushTypes: push?.pushTypes ?? const [],
        client: widget.args.client,
      ),
    );
    if (edited == null || !mounted) return;
    _edited(() {
      if (idx == null) {
        _pushes.add(edited);
      } else {
        _pushes[idx] = edited;
      }
    });
  }
}

// --- CORS allowed origins ---

final class MonitorCorsArgs {
  final List<String> origins;
  final void Function(List<String>) onChanged;

  const MonitorCorsArgs({required this.origins, required this.onChanged});
}

final class MonitorCorsPage extends StatefulWidget {
  final MonitorCorsArgs args;

  const MonitorCorsPage({super.key, required this.args});

  static const route = AppRouteArg<void, MonitorCorsArgs>(
    page: MonitorCorsPage.new,
    path: '/server/monitor_settings/cors',
  );

  @override
  State<MonitorCorsPage> createState() => _MonitorCorsPageState();
}

final class _MonitorCorsPageState extends State<MonitorCorsPage> {
  late final _origins = [...widget.args.origins];

  void _edited(void Function() change) {
    setState(change);
    widget.args.onChanged([..._origins]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.corsOrigins)),
      body: MonitorUi.column(
        children: [
          // Above the list rather than below the Add button, where it was read
          // after the decision it informs.
          ListTile(
            leading: const Icon(MingCute.question_line),
            title: TipText(libL10n.about, l10n.corsOriginsTip),
          ).cardx,
          for (final (idx, origin) in _origins.indexed)
            ListTile(
              leading: MonitorUi.index(idx),
              title: Text(origin),
              trailing: IconButton(
                icon: const Icon(Icons.delete, size: 19),
                onPressed: () => _edited(() => _origins.removeAt(idx)),
              ),
            ).cardx,
          MonitorUi.addBtn(_addOrigin),
        ],
      ),
    );
  }

  Future<void> _addOrigin() async {
    final ctrl = TextEditingController();
    final ok = await context.showRoundDialog<bool>(
      title: l10n.corsOrigins,
      child: Input(
        controller: ctrl,
        label: 'URL',
        hint: 'https://panel.example.com',
        icon: MingCute.web_line,
        type: TextInputType.url,
        suggestion: false,
      ),
      actions: Btnx.cancelOk,
    );
    final origin = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || origin.isEmpty || !mounted) return;
    if (_origins.contains(origin)) return;
    _edited(() => _origins.add(origin));
  }
}
