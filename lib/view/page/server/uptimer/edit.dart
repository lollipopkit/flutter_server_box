import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/provider/uptimer/client.dart';
import 'package:server_box/data/provider/uptimer/uptimer.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/uptimer/common.dart';
import 'package:server_box/view/widget/group_title.dart';

/// Create / edit page for an Uptimer monitor, following [ServerEditPage]'s
/// single-column `GroupTitle` + `CardX` + `ExpandableTile` layout and AppBar
/// `Save` action.
final class UptimerEditPage extends ConsumerStatefulWidget {
  final UptimerEditArgs? args;

  const UptimerEditPage({super.key, this.args});

  static const route = AppRoute<UptimerEditResult?, UptimerEditArgs>(
    page: UptimerEditPage.new,
    path: '/uptimer/edit',
  );

  /// Validates a TCP monitor target (`host:port` or `[ipv6]:port`, port 1..65535).
  static bool isValidTcpTarget(String target) {
    final trimmed = target.trim();
    if (trimmed.isEmpty || RegExp(r'\s').hasMatch(trimmed)) return false;
    final String host;
    final String portStr;
    if (trimmed.startsWith('[')) {
      final close = trimmed.indexOf(']:');
      if (close <= 1 || close + 2 >= trimmed.length) return false;
      host = trimmed.substring(1, close);
      portStr = trimmed.substring(close + 2);
      if (host.contains('[') || host.contains(']')) return false;
      try {
        Uri.parseIPv6Address(host);
      } on FormatException {
        return false;
      }
    } else {
      if (trimmed.contains('[') || trimmed.contains(']')) return false;
      final first = trimmed.indexOf(':');
      final last = trimmed.lastIndexOf(':');
      if (first <= 0 || first != last || last + 1 >= trimmed.length) {
        return false;
      }
      host = trimmed.substring(0, first);
      portStr = trimmed.substring(first + 1);
    }
    if (host.isEmpty) return false;
    if (!RegExp(r'^\d+$').hasMatch(portStr)) return false;
    final port = int.tryParse(portStr);
    return port != null && port >= 1 && port <= 65535;
  }

  @override
  ConsumerState<UptimerEditPage> createState() => _UptimerEditPageState();
}

final class _UptimerEditPageState extends ConsumerState<UptimerEditPage> {
  static const _httpMethods = ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE'];
  static const _intervalPresets = [60, 180, 300, 900, 3600];
  static const _maxGraceSec = 86400;
  static const _maxGroupLen = 64;
  static const _circularLoading = SizedLoading(
    16,
    padding: 1,
    builder: SizedLoading.circularBuilder,
  );

  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _displayUrlCtrl = TextEditingController();
  final _intervalCtrl = TextEditingController(text: '60');
  final _timeoutCtrl = TextEditingController(text: '10000');
  final _graceCtrl = TextEditingController(text: '60');
  final _expectedStatusCtrl = TextEditingController();
  final _forbiddenStatusCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _keywordCtrl = TextEditingController();
  final _forbiddenKeywordCtrl = TextEditingController();

  UptimerMonitorType _type = UptimerMonitorType.http;
  String _groupName = '';
  bool _customInterval = false;
  bool _intervalTouched = false;
  String _httpMethod = 'GET';
  bool _followRedirects = true;
  Map<String, String> _headers = {};
  String _keywordMode = 'contains';
  String _forbiddenKeywordMode = 'contains';
  bool _showOnStatusPage = false;
  bool _isActive = true;
  bool _initialIsActive = true;
  bool _initialWasPaused = false;
  bool _expandHttpReq = false;
  bool _expandHttpRule = false;
  bool _saving = false;
  bool _loadingConfig = false;
  bool _hydratedConfig = false;
  Object? _loadError;

  int? get _editingId => widget.args?.config?.id ?? widget.args?.card?.id;
  bool get _isEditing => _editingId != null;
  bool get _canSubmit =>
      !_saving && !_loadingConfig && (!_isEditing || _hydratedConfig);

  static Map<String, String> _sanitizeHeaders(Map<String, String> raw) => {
    for (final entry in raw.entries)
      if (entry.key.trim().isNotEmpty) entry.key.trim(): entry.value.trim(),
  };

  @override
  void initState() {
    super.initState();
    final state = ref.read(uptimerProvider);
    final minInterval = state.quota?.minIntervalSec ?? 60;
    final card = widget.args?.card;
    final cfg =
        widget.args?.config ?? (card != null ? state.configs[card.id] : null);
    if (cfg != null) {
      _applyConfig(cfg, minInterval: minInterval);
      _hydratedConfig = true;
    } else if (card != null) {
      _nameCtrl.text = card.name;
      _type = card.type;
      _displayUrlCtrl.text = card.displayUrl ?? '';
      _groupName = card.groupName ?? '';
      _showOnStatusPage = card.isPublic;
      _isActive = card.status != UptimerMonitorStatus.paused;
      _initialIsActive = _isActive;
      _initialWasPaused = card.status == UptimerMonitorStatus.paused;
      // Start in loading state synchronously so frame 0 never flashes an
      // unhydrated form before `_loadInitial` runs.
      _loadingConfig = true;
    } else if (minInterval > 60) {
      _intervalCtrl.text = '$minInterval';
      _customInterval = !_intervalPresets.contains(minInterval);
    }
    Future.microtask(_loadInitial);
  }

  Future<void> _loadInitial() async {
    if (!mounted) return;
    final notifier = ref.read(uptimerProvider.notifier);
    if (_editingId case final id? when !_hydratedConfig) {
      if (!_loadingConfig || _loadError != null) {
        setState(() {
          _loadingConfig = true;
          _loadError = null;
        });
      }
      try {
        final cfg = await notifier.ensureConfig(id, rethrowOnError: true);
        if (!mounted) return;
        if (cfg != null) {
          final minInterval =
              ref.read(uptimerProvider).quota?.minIntervalSec ?? 60;
          _applyConfig(cfg, minInterval: minInterval);
          setState(() {
            _hydratedConfig = true;
            _loadingConfig = false;
            _loadError = null;
          });
        } else {
          setState(() {
            _loadingConfig = false;
            _loadError = StateError('Monitor #$id not found');
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _loadingConfig = false;
          _loadError = e;
        });
      }
    } else {
      unawaited(notifier.loadConfigs());
    }
  }

  void _applyConfig(UptimerMonitorConfig cfg, {required int minInterval}) {
    _nameCtrl.text = cfg.name;
    _type = cfg.type;
    _targetCtrl.text = cfg.target;
    _displayUrlCtrl.text = cfg.displayUrl ?? '';
    _groupName = cfg.groupName ?? '';
    _intervalCtrl.text = '${cfg.intervalSec}';
    _customInterval =
        cfg.intervalSec < minInterval ||
        !_intervalPresets.contains(cfg.intervalSec);
    _timeoutCtrl.text = '${cfg.timeoutMs}';
    _graceCtrl.text = '${cfg.graceSec ?? 60}';
    _httpMethod = cfg.httpMethod ?? 'GET';
    _followRedirects = cfg.followRedirects;
    _headers = cfg.httpHeaders == null
        ? {}
        : _sanitizeHeaders(cfg.httpHeaders!);
    _bodyCtrl.text = cfg.httpBody ?? '';
    _expectedStatusCtrl.text = UptimerStatusRule.formatList(cfg.expectedStatus);
    _forbiddenStatusCtrl.text = UptimerStatusRule.formatList(
      cfg.forbiddenStatus,
    );
    _keywordCtrl.text = cfg.responseKeyword ?? '';
    _keywordMode = cfg.responseKeywordMode ?? 'contains';
    _forbiddenKeywordCtrl.text = cfg.responseForbiddenKeyword ?? '';
    _forbiddenKeywordMode = cfg.responseForbiddenKeywordMode ?? 'contains';
    _showOnStatusPage = cfg.showOnStatusPage;
    _reconcileActiveBaseline(cfg);
    _isActive = _initialIsActive && !_initialWasPaused;
    _expandHttpReq =
        (cfg.httpMethod != null && cfg.httpMethod != 'GET') ||
        !cfg.followRedirects ||
        _headers.isNotEmpty ||
        (cfg.httpBody != null && cfg.httpBody!.isNotEmpty);
    _expandHttpRule =
        cfg.expectedStatus != null ||
        cfg.forbiddenStatus != null ||
        cfg.responseKeyword != null ||
        cfg.responseForbiddenKeyword != null;
  }

  void _reconcileActiveBaseline(UptimerMonitorConfig persisted) {
    _initialIsActive = persisted.isActive;
    _initialWasPaused = persisted.status == UptimerMonitorStatus.paused;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _displayUrlCtrl.dispose();
    _intervalCtrl.dispose();
    _timeoutCtrl.dispose();
    _graceCtrl.dispose();
    _expectedStatusCtrl.dispose();
    _forbiddenStatusCtrl.dispose();
    _bodyCtrl.dispose();
    _keywordCtrl.dispose();
    _forbiddenKeywordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(
      uptimerProvider.select((s) => s.quota?.minIntervalSec),
      (_, nextMin) {
        if (nextMin == null || _isEditing || _intervalTouched) return;
        final current = int.tryParse(_intervalCtrl.text.trim()) ?? 0;
        if (current < nextMin) {
          setState(() {
            _intervalCtrl.text = '$nextMin';
            _customInterval = !_intervalPresets.contains(nextMin);
          });
        }
      },
    );
    final quota = ref.watch(uptimerProvider.select((s) => s.quota));
    final minInterval = quota?.minIntervalSec ?? 60;
    final existingGroups = ref.watch(
      uptimerProvider.select((s) => s.sortedGroupNames),
    );

    return Scaffold(
      appBar: CustomAppBar(
        title: Text(
          _isEditing
              ? '${libL10n.edit} ${l10n.uptimer}'
              : '${libL10n.add} ${l10n.uptimer}',
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: libL10n.delete,
              onPressed: (_saving || _loadingConfig) ? null : _onDelete,
              icon: const Icon(Icons.delete),
            ),
          _buildSaveBtn(minInterval),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: _buildBody(context, minInterval, existingGroups),
      ),
    );
  }

  /// Mirrors `ServerEditPage._buildSaveBtn`: a compact filled button in the
  /// AppBar instead of a FAB floating over the last row of the form.
  Widget _buildSaveBtn(int minInterval) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: FilledButton(
        onPressed: _canSubmit ? () => _onSave(minInterval) : null,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 17),
          visualDensity: VisualDensity.compact,
        ),
        child: _saving ? _circularLoading : Text(libL10n.save),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    int minInterval,
    List<String> existingGroups,
  ) {
    if (_loadingConfig || (_isEditing && !_hydratedConfig && _loadError == null)) {
      return const Center(
        child: SizedLoading(
          28,
          padding: 2,
          builder: SizedLoading.circularBuilder,
        ),
      );
    }
    if (_isEditing && !_hydratedConfig && _loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 32, color: StatePalette.failed),
                UIs.height13,
                Text(
                  uptimerErrorMessage(_loadError!),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: StatePalette.failed),
                ),
                UIs.height13,
                FilledButton.tonal(
                  onPressed: () => unawaited(_loadInitial()),
                  child: Text(libL10n.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(13, 7, 13, 34),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Identity rows (matching ServerEditPage top: Name + TagTile)
              Input(
                autoFocus: !_isEditing,
                controller: _nameCtrl,
                label: libL10n.name,
                hint: 'API / Blog / Backup',
                icon: BoxIcons.bx_rename,
                autoCorrect: false,
                suggestion: false,
              ),
              _buildGroupRow(existingGroups),
              _buildTargetGroup(),
              _buildScheduleGroup(minInterval),
              _buildBehaviourGroup(),
              if (_type == UptimerMonitorType.http) _buildOptionalGroup(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupRow(List<String> existingGroups) {
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(l10n.uptimerGroup),
      subtitle: Text(
        _groupName.isEmpty ? libL10n.none : _groupName,
        style: UIs.textGrey,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => unawaited(_pickGroup(existingGroups)),
    ).cardx;
  }

  Future<void> _pickGroup(List<String> existingGroups) async {
    final customCtrl = TextEditingController(text: _groupName);
    final result = await context.showSheet<String>(
      title: l10n.uptimerGroup,
      childBuilder: (ctx) => DisposeWith(
        notifiers: [customCtrl],
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _groupName.isEmpty
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(libL10n.none),
                onTap: () => ctx.popSheet(''),
              ),
              for (final g in existingGroups)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _groupName == g
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(g),
                  onTap: () => ctx.popSheet(g),
                ),
              const SizedBox(height: 8),
              Input(
                controller: customCtrl,
                label: libL10n.custom,
                hint: 'BASE / SERVICE',
                icon: Icons.folder_outlined,
                autoCorrect: false,
                onSubmitted: (v) => ctx.popSheet(v.trim()),
              ),
            ],
          ),
        ),
      ),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => ctx.popSheet(),
          child: Text(libL10n.cancel),
        ),
        TextButton(
          onPressed: () => ctx.popSheet(customCtrl.text.trim()),
          child: Text(libL10n.ok),
        ),
      ],
    );
    if (result != null && mounted) {
      setState(() => _groupName = result);
    }
  }

  Widget _buildTargetGroup() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupTitle(
          l10n.uptimerTarget,
          right: _isEditing ? _type.shortLabel : null,
        ),
        if (!_isEditing)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SegmentedTabs<UptimerMonitorType>(
              expand: true,
              segments: [
                for (final t in UptimerMonitorType.values)
                  SegmentedTab(
                    value: t,
                    icon: uptimerTypeIcon(t),
                    label: t.shortLabel,
                  ),
              ],
              selected: _type,
              onSelected: (t) => setState(() => _type = t),
            ),
          ),
        if (_type != UptimerMonitorType.heartbeat)
          Input(
            controller: _targetCtrl,
            label: l10n.uptimerTarget,
            hint: _type == UptimerMonitorType.http
                ? 'https://example.com/health'
                : 'example.com:443',
            icon: Icons.link,
            autoCorrect: false,
            suggestion: false,
            type: TextInputType.url,
          )
        else
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(l10n.uptimerPushUrl),
            subtitle: Text(
              _isEditing ? l10n.uptimerRotatePushUrl : l10n.uptimerPushUrlOnce,
              style: UIs.textGrey,
            ),
            trailing: _isEditing
                ? (_saving
                      ? _circularLoading
                      : const Icon(Icons.keyboard_arrow_right))
                : null,
            onTap: _isEditing && !_saving ? _onRotatePushUrl : null,
          ).cardx,
      ],
    );
  }

  Future<void> _onRotatePushUrl() async {
    final id = _editingId;
    if (id == null || _saving || _loadingConfig) return;
    final name = _nameCtrl.text.trim();
    final confirmed = await context.showSheet<bool>(
      title: l10n.uptimerRotatePushUrl,
      child: Text(l10n.uptimerRotatePushUrlConfirm(name)),
      actions: Btnx.cancelRedOk,
    );
    if (confirmed != true || !mounted || _saving) return;

    setState(() => _saving = true);
    try {
      final mutation = await ref
          .read(uptimerProvider.notifier)
          .rotatePushToken(id);
      if (!mounted) return;
      setState(() => _saving = false);
      if (mutation.pushToken case final token?) {
        final api = ref.read(uptimerApiProvider);
        await showUptimerPushUrlSheet(
          context,
          name: name,
          url: api.pushUrl(token),
        );
      }
    } catch (e) {
      if (mounted) Toast.show(uptimerErrorMessage(e));
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  String _scheduleSummary() {
    final iv = int.tryParse(_intervalCtrl.text.trim());
    final ivStr = iv != null && iv > 0 ? formatDurationSec(iv) : '—';
    if (_type == UptimerMonitorType.heartbeat) {
      final g = int.tryParse(_graceCtrl.text.trim());
      final gStr = g != null && g >= 0 ? formatDurationSec(g) : '—';
      return '$ivStr · $gStr';
    }
    final ms = int.tryParse(_timeoutCtrl.text.trim());
    final tStr = ms != null && ms > 0 ? formatLatencyMs(ms) : '—';
    return '$ivStr · $tStr';
  }

  Widget _buildScheduleGroup(int minInterval) {
    final presets = [
      for (final p in _intervalPresets)
        if (p >= minInterval) p,
    ];
    final currentInterval = int.tryParse(_intervalCtrl.text.trim());
    final isPreset =
        !_customInterval &&
        currentInterval != null &&
        presets.contains(currentInterval);
    final intervalLabel = isPreset
        ? formatDurationSec(currentInterval)
        : (currentInterval != null && currentInterval > 0
              ? formatDurationSec(currentInterval)
              : libL10n.custom);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupTitle(l10n.uptimerSchedule, right: _scheduleSummary()),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: Text(l10n.uptimerInterval),
          trailing: ContextMenuButton(
            actions: () => [
              for (final preset in presets)
                ContextMenuAction(
                  text: formatDurationSec(preset),
                  checked: isPreset && currentInterval == preset,
                  onTap: () => setState(() {
                    _customInterval = false;
                    _intervalTouched = true;
                    _intervalCtrl.text = '$preset';
                  }),
                ),
              ContextMenuAction(
                text: '${libL10n.custom}…',
                checked: !isPreset,
                onTap: () => setState(() {
                  _customInterval = true;
                  _intervalTouched = true;
                }),
              ),
            ],
            child: ContextMenuButton.value(Text(intervalLabel)),
          ),
        ).cardx,
        if (_customInterval || !isPreset)
          Input(
            controller: _intervalCtrl,
            label: '${l10n.uptimerInterval} (${l10n.second})',
            hint: l10n.uptimerMinIntervalHint(minInterval),
            icon: Icons.schedule,
            type: TextInputType.number,
            suggestion: false,
            onChanged: (_) => setState(() {
              // Keep custom input open while typing prefixes of presets (e.g.
              // typing "3000" passes through "300").
              _customInterval = true;
              _intervalTouched = true;
            }),
          ),
        if (_type == UptimerMonitorType.heartbeat)
          Input(
            controller: _graceCtrl,
            label: '${l10n.uptimerGracePeriod} (${l10n.second})',
            hint: '60',
            icon: Icons.hourglass_bottom,
            type: TextInputType.number,
            suggestion: false,
            onChanged: (_) => setState(() {}),
          )
        else
          Input(
            controller: _timeoutCtrl,
            label: '${l10n.uptimerTimeout} (ms)',
            hint: '10000',
            icon: Icons.av_timer,
            type: TextInputType.number,
            suggestion: false,
            onChanged: (_) => setState(() {}),
          ),
      ],
    );
  }

  Widget _buildBehaviourGroup() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupTitle(l10n.behaviour),
        ListTile(
          leading: const Icon(Icons.public),
          title: Text(l10n.uptimerPublic),
          trailing: SwitchX(
            value: _showOnStatusPage,
            onChanged: (v) => setState(() => _showOnStatusPage = v),
          ),
          onTap: () => setState(() => _showOnStatusPage = !_showOnStatusPage),
        ).cardx,
        if (_isEditing)
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: Text(l10n.uptimerActive),
            trailing: SwitchX(
              value: _isActive,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _isActive = v),
            ),
            onTap: _saving
                ? null
                : () => setState(() => _isActive = !_isActive),
          ).cardx,
        Input(
          controller: _displayUrlCtrl,
          label: l10n.uptimerDisplayUrl,
          hint: 'https://status.example.com',
          icon: Icons.open_in_new,
          autoCorrect: false,
          suggestion: false,
          type: TextInputType.url,
        ),
      ],
    );
  }

  String _httpRequestSummary() {
    final parts = <String>[_httpMethod];
    if (_followRedirects) parts.add(l10n.uptimerFollowRedirects);
    if (_headers.isNotEmpty) parts.add('${_headers.length}');
    return parts.join(' · ');
  }

  String _httpValidationSummary() {
    final parts = <String>[];
    final exp = _expectedStatusCtrl.text.trim();
    final forb = _forbiddenStatusCtrl.text.trim();
    final kw = _keywordCtrl.text.trim();
    final fkw = _forbiddenKeywordCtrl.text.trim();
    if (exp.isNotEmpty) parts.add(exp);
    if (forb.isNotEmpty) parts.add('!$forb');
    if (kw.isNotEmpty || fkw.isNotEmpty) parts.add(l10n.uptimerKeyword);
    return parts.isEmpty ? libL10n.empty : parts.join(' · ');
  }

  Widget _buildOptionalGroup() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupTitle(l10n.optional),
        ExpandableTile(
          key: ValueKey('http_req_$_hydratedConfig'),
          initiallyExpanded: _expandHttpReq,
          onExpansionChanged: (v) => _expandHttpReq = v,
          leading: const Icon(Icons.tune),
          title: Text(l10n.uptimerHttpRequest),
          summary: Text(_httpRequestSummary()),
          children: [
            ListTile(
              leading: const Icon(Icons.http),
              title: Text(l10n.uptimerMethod),
              trailing: ContextMenuButton(
                actions: () => [
                  for (final m in _httpMethods)
                    ContextMenuAction(
                      text: m,
                      checked: _httpMethod == m,
                      onTap: () => setState(() => _httpMethod = m),
                    ),
                ],
                child: ContextMenuButton.value(Text(_httpMethod)),
              ),
            ).cardx,
            ListTile(
              leading: const Icon(Icons.redo),
              title: Text(l10n.uptimerFollowRedirects),
              trailing: SwitchX(
                value: _followRedirects,
                onChanged: (v) => setState(() => _followRedirects = v),
              ),
              onTap: () =>
                  setState(() => _followRedirects = !_followRedirects),
            ).cardx,
            ListTile(
              leading: const Icon(Icons.code),
              title: Text(l10n.uptimerHeaders),
              subtitle: Text(
                _headers.isEmpty
                    ? libL10n.empty
                    : '${_headers.length} ${libL10n.configured}',
                style: UIs.textGrey,
              ),
              trailing: const Icon(Icons.keyboard_arrow_right),
              onTap: () async {
                final res = await KvEditor.route.go(
                  context,
                  KvEditorArgs(data: Map<String, String>.from(_headers)),
                );
                if (res == null || !mounted) return;
                setState(() => _headers = _sanitizeHeaders(res));
              },
            ).cardx,
            if (_httpMethod != 'GET' && _httpMethod != 'HEAD')
              Input(
                controller: _bodyCtrl,
                label: l10n.uptimerBody,
                icon: Icons.data_object,
                maxLines: 3,
                autoCorrect: false,
                suggestion: false,
              ),
          ],
        ),
        ExpandableTile(
          key: ValueKey('http_rule_$_hydratedConfig'),
          initiallyExpanded: _expandHttpRule,
          onExpansionChanged: (v) => _expandHttpRule = v,
          leading: const Icon(Icons.fact_check_outlined),
          title: Text(l10n.uptimerResponseValidation),
          summary: Text(_httpValidationSummary()),
          children: [
            Input(
              controller: _expectedStatusCtrl,
              label: l10n.uptimerExpectedStatus,
              hint: '200, 201-204',
              icon: Icons.check_circle_outline,
              autoCorrect: false,
              suggestion: false,
              onChanged: (_) => setState(() {}),
            ),
            Input(
              controller: _forbiddenStatusCtrl,
              label: l10n.uptimerForbiddenStatus,
              hint: '500-599',
              icon: Icons.block_outlined,
              autoCorrect: false,
              suggestion: false,
              onChanged: (_) => setState(() {}),
            ),
            Input(
              controller: _keywordCtrl,
              label: l10n.uptimerKeyword,
              icon: Icons.search,
              autoCorrect: false,
              suggestion: false,
              onChanged: (_) => setState(() {}),
              suffix: _buildMatchModeButton(
                value: _keywordMode,
                onChanged: (v) => setState(() => _keywordMode = v),
              ),
            ),
            Input(
              controller: _forbiddenKeywordCtrl,
              label: l10n.uptimerForbiddenKeyword,
              icon: Icons.do_not_disturb_on_outlined,
              autoCorrect: false,
              suggestion: false,
              onChanged: (_) => setState(() {}),
              suffix: _buildMatchModeButton(
                value: _forbiddenKeywordMode,
                onChanged: (v) => setState(() => _forbiddenKeywordMode = v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMatchModeButton({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final label = value == 'regex'
        ? l10n.uptimerMatchRegex
        : l10n.uptimerMatchContains;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 112),
      child: ContextMenuButton(
        actions: () => [
          ContextMenuAction(
            text: l10n.uptimerMatchContains,
            checked: value != 'regex',
            onTap: () => onChanged('contains'),
          ),
          ContextMenuAction(
            text: l10n.uptimerMatchRegex,
            checked: value == 'regex',
            onTap: () => onChanged('regex'),
          ),
        ],
        child: ContextMenuButton.value(
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  String? _validateTarget(String target) {
    if (_type == UptimerMonitorType.heartbeat) return null;
    if (target.isEmpty) return '${l10n.uptimerTarget}: ${libL10n.empty}';
    if (_type == UptimerMonitorType.http) {
      final uri = Uri.tryParse(target);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        return '${l10n.uptimerTarget}: http(s)://...';
      }
      return null;
    }
    if (!UptimerEditPage.isValidTcpTarget(target)) {
      return '${l10n.uptimerTarget}: host:port / [ipv6]:port';
    }
    return null;
  }

  Future<void> _onSave(int minInterval) async {
    if (!_canSubmit) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Toast.show('${libL10n.name}: ${libL10n.empty}');
      return;
    }
    final target = _targetCtrl.text.trim();
    if (_validateTarget(target) case final err?) {
      Toast.show(err);
      return;
    }
    final groupName = _groupName.trim();
    if (groupName.length > _maxGroupLen) {
      Toast.show('${l10n.uptimerGroup} <= $_maxGroupLen');
      return;
    }
    final displayUrl = _displayUrlCtrl.text.trim();
    if (displayUrl.isNotEmpty) {
      final uri = Uri.tryParse(displayUrl);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        Toast.show('${l10n.uptimerDisplayUrl}: http(s)://...');
        return;
      }
    }
    final intervalSec = int.tryParse(_intervalCtrl.text.trim());
    if (intervalSec == null || intervalSec < minInterval) {
      Toast.show(
        '${l10n.uptimerInterval}: ${l10n.uptimerMinIntervalHint(minInterval)}',
      );
      return;
    }
    int? timeoutMs;
    int? graceSec;
    if (_type == UptimerMonitorType.heartbeat) {
      final g = _graceCtrl.text.trim();
      graceSec = g.isEmpty ? 60 : int.tryParse(g);
      if (graceSec == null || graceSec < 0 || graceSec > _maxGraceSec) {
        Toast.show('${l10n.uptimerGracePeriod}: 0..$_maxGraceSec');
        return;
      }
    } else {
      timeoutMs = int.tryParse(_timeoutCtrl.text.trim());
      if (timeoutMs == null || timeoutMs < 1000) {
        Toast.show('${l10n.uptimerTimeout} >= 1000 ms');
        return;
      }
    }

    final submittedActive = _isActive;
    List<UptimerStatusRule>? expectedStatus;
    List<UptimerStatusRule>? forbiddenStatus;
    Map<String, String>? headers;
    // Preserve outer whitespace in keyword patterns; trim only for emptiness.
    final keyword = _keywordCtrl.text;
    final hasKeyword = keyword.trim().isNotEmpty;
    final forbiddenKeyword = _forbiddenKeywordCtrl.text;
    final hasForbiddenKeyword = forbiddenKeyword.trim().isNotEmpty;
    if (_type == UptimerMonitorType.http) {
      try {
        expectedStatus = UptimerStatusRule.parseInput(_expectedStatusCtrl.text);
        forbiddenStatus = UptimerStatusRule.parseInput(
          _forbiddenStatusCtrl.text,
        );
        final cleanHeaders = _sanitizeHeaders(_headers);
        headers = cleanHeaders.isEmpty ? null : cleanHeaders;
        if (hasKeyword && _keywordMode == 'regex') {
          RegExp(keyword);
        }
        if (hasForbiddenKeyword && _forbiddenKeywordMode == 'regex') {
          RegExp(forbiddenKeyword);
        }
      } on FormatException catch (e) {
        Toast.show(e.message);
        return;
      }
    }

    final payload = <String, dynamic>{
      'name': name,
      if (!_isEditing) 'type': _type.wire,
      if (_type != UptimerMonitorType.heartbeat) 'target': target,
      'display_url': displayUrl.isEmpty ? null : displayUrl,
      'interval_sec': intervalSec,
      if (_type == UptimerMonitorType.heartbeat)
        'grace_sec': graceSec
      else
        'timeout_ms': timeoutMs,
      'group_name': groupName.isEmpty ? null : groupName,
      'show_on_status_page': _showOnStatusPage,
      if (_isEditing &&
          submittedActive != _initialIsActive &&
          (submittedActive || _initialWasPaused))
        'is_active': submittedActive,
      if (_type == UptimerMonitorType.http) ...{
        'http_method': _httpMethod,
        'follow_redirects': _followRedirects,
        if (_isEditing || expectedStatus != null)
          'expected_status_json': expectedStatus
              ?.map((r) => r.toJson())
              .toList(),
        if (_isEditing || forbiddenStatus != null)
          'forbidden_status_json': forbiddenStatus
              ?.map((r) => r.toJson())
              .toList(),
        if (_isEditing || headers != null) 'http_headers_json': headers,
        if (_httpMethod != 'GET' && _httpMethod != 'HEAD')
          'http_body': _bodyCtrl.text.isEmpty ? null : _bodyCtrl.text
        else if (_isEditing)
          'http_body': null,
        if (_isEditing || hasKeyword) ...{
          'response_keyword': hasKeyword ? keyword : null,
          'response_keyword_mode': hasKeyword ? _keywordMode : null,
        },
        if (_isEditing || hasForbiddenKeyword) ...{
          'response_forbidden_keyword': hasForbiddenKeyword
              ? forbiddenKeyword
              : null,
          'response_forbidden_keyword_mode': hasForbiddenKeyword
              ? _forbiddenKeywordMode
              : null,
        },
      },
    };
    if (!_isEditing) {
      payload.removeWhere((_, v) => v == null);
    }

    setState(() => _saving = true);
    try {
      final notifier = ref.read(uptimerProvider.notifier);
      if (_editingId case final id?) {
        final updated = await notifier.updateMonitor(id, payload);
        _reconcileActiveBaseline(updated);
        if (submittedActive && _initialWasPaused) {
          _reconcileActiveBaseline(await notifier.resumeMonitor(id));
        } else if (!submittedActive && !_initialWasPaused) {
          _reconcileActiveBaseline(await notifier.pauseMonitor(id));
        }
        if (mounted) Navigator.of(context).pop(UptimerEditResult.saved);
      } else {
        final mutation = await notifier.createMonitor(payload);
        if (!mounted) return;
        setState(() => _saving = false);
        if (mutation.pushToken case final token?) {
          final api = ref.read(uptimerApiProvider);
          await showUptimerPushUrlSheet(
            context,
            name: mutation.monitor.name,
            url: api.pushUrl(token),
          );
        }
        if (mounted) Navigator.of(context).pop(UptimerEditResult.saved);
      }
    } catch (e) {
      if (!mounted) return;
      if (_editingId case final id?) {
        final latest = ref.read(uptimerProvider).configs[id];
        if (latest != null) _reconcileActiveBaseline(latest);
      }
      Toast.show(uptimerErrorMessage(e));
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  Future<void> _onDelete() async {
    final id = _editingId;
    if (id == null || _saving || _loadingConfig) return;
    final name = _nameCtrl.text.trim();
    final confirmed = await context.showSheet<bool>(
      title: libL10n.attention,
      child: Text(libL10n.askContinue('${libL10n.delete} $name')),
      actions: Btnx.cancelRedOk,
    );
    if (confirmed != true || !mounted || _saving) return;

    setState(() => _saving = true);
    try {
      await ref.read(uptimerProvider.notifier).deleteMonitor(id);
      if (mounted) Navigator.of(context).pop(UptimerEditResult.deleted);
    } catch (e) {
      if (mounted) Toast.show(uptimerErrorMessage(e));
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }
}
