import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/provider/uptimer/client.dart';
import 'package:server_box/data/provider/uptimer/uptimer.dart';
import 'package:server_box/view/page/uptimer/common.dart';
import 'package:server_box/view/page/uptimer/detail_sections.dart';
import 'package:server_box/view/page/uptimer/edit_http_section.dart';
import 'package:server_box/view/page/uptimer/edit_sections.dart';
import 'package:server_box/view/page/uptimer/edit_validator.dart';

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
  static bool isValidTcpTarget(String target) =>
      isValidUptimerTcpTarget(target);

  @override
  ConsumerState<UptimerEditPage> createState() => _UptimerEditPageState();
}

final class _UptimerEditPageState extends ConsumerState<UptimerEditPage> {
  final _ctrls = UptimerEditControllers();

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
      _ctrls.name.text = card.name;
      _type = card.type;
      _ctrls.displayUrl.text = card.displayUrl ?? '';
      _groupName = card.groupName ?? '';
      _showOnStatusPage = card.isPublic;
      _isActive = card.status != UptimerMonitorStatus.paused;
      _initialIsActive = _isActive;
      _initialWasPaused = card.status == UptimerMonitorStatus.paused;
      // Start in loading state synchronously so frame 0 never flashes an
      // unhydrated form before `_loadInitial` runs.
      _loadingConfig = true;
    } else if (minInterval > 60) {
      _ctrls.interval.text = '$minInterval';
      _customInterval = !kUptimerIntervalPresets.contains(minInterval);
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
    _ctrls.applyConfig(cfg);
    _type = cfg.type;
    _groupName = cfg.groupName ?? '';
    _customInterval =
        cfg.intervalSec < minInterval ||
        !kUptimerIntervalPresets.contains(cfg.intervalSec);
    _httpMethod = cfg.httpMethod ?? 'GET';
    _followRedirects = cfg.followRedirects;
    _headers = cfg.httpHeaders == null
        ? {}
        : sanitizeUptimerHeaders(cfg.httpHeaders!);
    _keywordMode = cfg.responseKeywordMode ?? 'contains';
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
    _ctrls.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(uptimerProvider.select((s) => s.quota?.minIntervalSec), (
      _,
      nextMin,
    ) {
      if (nextMin == null || _isEditing || _intervalTouched) return;
      final current = int.tryParse(_ctrls.interval.text.trim()) ?? 0;
      if (current < nextMin) {
        setState(() {
          _ctrls.interval.text = '$nextMin';
          _customInterval = !kUptimerIntervalPresets.contains(nextMin);
        });
      }
    });
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
        child: _saving ? kUptimerCircularLoading : Text(libL10n.save),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    int minInterval,
    List<String> existingGroups,
  ) {
    if (_loadingConfig ||
        (_isEditing && !_hydratedConfig && _loadError == null)) {
      return const Center(
        child: SizedLoading(
          28,
          padding: 2,
          builder: SizedLoading.circularBuilder,
        ),
      );
    }
    if (_isEditing && !_hydratedConfig && _loadError != null) {
      return UptimerEditLoadError(
        error: _loadError!,
        onRetry: () => unawaited(_loadInitial()),
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
                controller: _ctrls.name,
                label: libL10n.name,
                hint: 'API / Blog / Backup',
                icon: BoxIcons.bx_rename,
                autoCorrect: false,
                suggestion: false,
              ),
              ListTile(
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
              ).cardx,
              UptimerTargetSection(
                isEditing: _isEditing,
                saving: _saving,
                type: _type,
                targetCtrl: _ctrls.target,
                onTypeChanged: (t) => setState(() => _type = t),
                onRotatePushUrl: _onRotatePushUrl,
              ),
              UptimerScheduleSection(
                type: _type,
                minInterval: minInterval,
                customInterval: _customInterval,
                intervalCtrl: _ctrls.interval,
                graceCtrl: _ctrls.grace,
                timeoutCtrl: _ctrls.timeout,
                onPresetSelected: (preset) => setState(() {
                  _customInterval = false;
                  _intervalTouched = true;
                  _ctrls.interval.text = '$preset';
                }),
                onCustomSelected: () => setState(() {
                  _customInterval = true;
                  _intervalTouched = true;
                }),
                onCustomIntervalChanged: () => setState(() {
                  // Keep custom input open while typing prefixes of presets
                  // (e.g. typing "3000" passes through "300").
                  _customInterval = true;
                  _intervalTouched = true;
                }),
                onFieldChanged: () => setState(() {}),
              ),
              UptimerBehaviourSection(
                isEditing: _isEditing,
                saving: _saving,
                showOnStatusPage: _showOnStatusPage,
                onShowOnStatusPageChanged: (v) =>
                    setState(() => _showOnStatusPage = v),
                isActive: _isActive,
                onActiveChanged: (v) => setState(() => _isActive = v),
                displayUrlCtrl: _ctrls.displayUrl,
              ),
              if (_type == UptimerMonitorType.http)
                UptimerHttpOptionalSection(
                  hydratedConfig: _hydratedConfig,
                  expandHttpReq: _expandHttpReq,
                  expandHttpRule: _expandHttpRule,
                  onExpandHttpReqChanged: (v) => _expandHttpReq = v,
                  onExpandHttpRuleChanged: (v) => _expandHttpRule = v,
                  httpMethod: _httpMethod,
                  onHttpMethodChanged: (m) => setState(() => _httpMethod = m),
                  followRedirects: _followRedirects,
                  onFollowRedirectsChanged: (v) =>
                      setState(() => _followRedirects = v),
                  headers: _headers,
                  onEditHeaders: () => unawaited(_editHeaders()),
                  bodyCtrl: _ctrls.body,
                  expectedStatusCtrl: _ctrls.expectedStatus,
                  forbiddenStatusCtrl: _ctrls.forbiddenStatus,
                  keywordCtrl: _ctrls.keyword,
                  keywordMode: _keywordMode,
                  onKeywordModeChanged: (v) => setState(() => _keywordMode = v),
                  forbiddenKeywordCtrl: _ctrls.forbiddenKeyword,
                  forbiddenKeywordMode: _forbiddenKeywordMode,
                  onForbiddenKeywordModeChanged: (v) =>
                      setState(() => _forbiddenKeywordMode = v),
                  onValidationChanged: () => setState(() {}),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickGroup(List<String> existingGroups) async {
    final result = await showUptimerGroupPicker(
      context,
      current: _groupName,
      existingGroups: existingGroups,
    );
    if (result != null && mounted) {
      setState(() => _groupName = result);
    }
  }

  Future<void> _editHeaders() async {
    final res = await KvEditor.route.go(
      context,
      KvEditorArgs(data: Map<String, String>.from(_headers)),
    );
    if (res == null || !mounted) return;
    setState(() => _headers = sanitizeUptimerHeaders(res));
  }

  Future<void> _showPushUrl(String name, String? token) async {
    if (token == null) return;
    final api = ref.read(uptimerApiProvider);
    await showUptimerPushUrlSheet(context, name: name, url: api.pushUrl(token));
  }

  Future<void> _onRotatePushUrl() async {
    final id = _editingId;
    if (id == null || _saving || _loadingConfig) return;
    final name = _ctrls.name.text.trim();
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
      await _showPushUrl(name, mutation.pushToken);
    } catch (e) {
      if (mounted) Toast.show(uptimerErrorMessage(e));
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  Future<void> _onSave(int minInterval) async {
    if (!_canSubmit) return;
    final submittedActive = _isActive;
    final result = validateAndBuildUptimerPayload(
      isEditing: _isEditing,
      type: _type,
      ctrls: _ctrls,
      rawGroupName: _groupName,
      minInterval: minInterval,
      showOnStatusPage: _showOnStatusPage,
      submittedActive: submittedActive,
      initialIsActive: _initialIsActive,
      initialWasPaused: _initialWasPaused,
      httpMethod: _httpMethod,
      followRedirects: _followRedirects,
      rawHeaders: _headers,
      keywordMode: _keywordMode,
      forbiddenKeywordMode: _forbiddenKeywordMode,
    );
    if (result.error case final err?) {
      Toast.show(err);
      return;
    }
    final payload = result.payload!;

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
        await _showPushUrl(mutation.monitor.name, mutation.pushToken);
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
    final name = _ctrls.name.text.trim();
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
