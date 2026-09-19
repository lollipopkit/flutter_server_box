import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/privileged_exec.dart';
import 'package:server_box/core/utils/refresh_interval.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/proc.dart';
import 'package:server_box/data/model/server/proc_kill.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';

/// Below this the table gives way to one stacked row per process: the fixed
/// columns would leave the command nothing to be read in.
const _kWideWidth = 700.0;
const _kRssWidth = 840.0;
const _kIoWidth = 1100.0;

const _kPad = 13.0;
const _kGap = 13.0;
const _kColPid = 76.0;
const _kColUser = 100.0;
const _kColCpu = 92.0;
const _kColMem = 80.0;
const _kColRss = 96.0;
const _kColIo = 88.0;
const _kColAction = 34.0;

/// The CPU series colour, so a bar here and the line on the detail page read
/// as the same quantity. See [ChartPalette].
Color get _kCpuColor => ChartPalette.cpu;

const _processCommandTimeout = Duration(seconds: 30);

class ProcessPage extends ConsumerStatefulWidget {
  final SpiRequiredArgs args;

  const ProcessPage({super.key, required this.args});

  @override
  ConsumerState<ProcessPage> createState() => _ProcessPageState();

  static const route = AppRouteArg(page: ProcessPage.new, path: '/process');
}

class _ProcessPageState extends ConsumerState<ProcessPage>
    with WidgetsBindingObserver {
  Timer? _timer;
  Completer<void>? _refreshCompleter;
  final _searchCtrl = TextEditingController();

  PsResult _result = const PsResult(procs: []);
  PsResult? _lastValidResult;
  String? _loadErrorMessage;
  bool _hasLoaded = false;
  bool _isRefreshing = false;
  _ProcessCapabilities _capabilities = _ProcessCapabilities.empty;

  // Issue #64: CPU sorting keeps high-churn lists visibly fresh and surfaces
  // the processes that normally need attention first.
  ProcSortMode _procSortMode = ProcSortMode.cpu;
  bool _sortAscending = ProcSortMode.cpu.defaultAscending;

  String _query = '';

  /// Off by default. On an idle Linux machine kernel threads are most of the
  /// list, and none of them is anything a user started or can usefully stop.
  bool _showKernelThreads = false;

  /// The one row showing its command line and actions. Held as the process,
  /// not the PID, so a PID reused between refreshes does not open on whatever
  /// took the number.
  Proc? _expanded;

  late final _provider = serverProvider(widget.args.spi.id);

  @override
  void dispose() {
    _timer?.cancel();
    _searchCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _timer?.cancel();
    final duration = serverStatusRefreshInterval();
    if (duration != null) {
      _timer = Timer.periodic(duration, (_) => _refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _startRefreshTimer();
        _refresh();
        break;
      case AppLifecycleState.paused:
        _timer?.cancel();
        _timer = null;
        break;
      default:
        break;
    }
  }

  Future<void> _refresh({bool userTriggered = false}) async {
    if (!mounted) return;
    if (_isRefreshing) {
      await _refreshCompleter?.future;
      return;
    }
    final refreshCompleter = Completer<void>();
    _refreshCompleter = refreshCompleter;
    _isRefreshing = true;
    if (_hasLoaded) setState(() {});
    try {
      final serverState = ref.read(_provider);
      final systemType = serverState.status.system;
      if (!_canRunProcessCmd(serverState)) {
        _result = const PsResult(procs: []);
        _loadErrorMessage = libL10n.disconnected;
        _hasLoaded = true;
        if (userTriggered && mounted) {
          Toast.show(libL10n.disconnected);
        }
        return;
      }
      final exec = await ref.read(_provider.notifier).ensureScriptExec();
      final result = (await exec
              .run(
                ShellFunc.process.exec(
                  serverState.spi.id,
                  systemType: systemType,
                  customDir: serverState.spi.custom?.scriptDir,
                ),
              )
              .timeout(_processCommandTimeout))
          .combined;
      if (!mounted) return;
      if (result.trim().isEmpty) {
        _result = const PsResult(procs: []);
        _loadErrorMessage = libL10n.empty;
        _hasLoaded = true;
        if (userTriggered) Toast.show(libL10n.empty);
        return;
      }

      final requestedSort = _procSortMode;
      var parsed = PsResult.parse(
        result,
        sort: requestedSort,
        ascending: _sortAscending,
        previous: _lastValidResult,
      );
      if (parsed.issue != null) {
        _result = PsResult(procs: const [], issue: parsed.issue);
        _loadErrorMessage = null;
        _hasLoaded = true;
        return;
      }
      final sortChanged = _updateCapabilities(parsed);
      if (sortChanged) {
        parsed = parsed.sortedBy(_procSortMode, ascending: _sortAscending);
      }
      _result = parsed;
      _lastValidResult = parsed;
      _loadErrorMessage = null;
      _hasLoaded = true;
    } on TimeoutException catch (e, s) {
      Loggers.app.warning('Process page command timed out', e, s);
      if (mounted && (userTriggered || !_hasLoaded)) {
        Toast.error(libL10n.error);
      }
      _result = const PsResult(procs: []);
      _loadErrorMessage = libL10n.error;
      _hasLoaded = true;
    } catch (e, s) {
      Loggers.app.warning('Process page refresh failed', e, s);
      if (mounted && (userTriggered || !_hasLoaded)) {
        Toast.error(libL10n.error);
      }
      _result = const PsResult(procs: []);
      _loadErrorMessage = libL10n.error;
      _hasLoaded = true;
    } finally {
      _isRefreshing = false;
      if (mounted) setState(() {});
      if (!refreshCompleter.isCompleted) refreshCompleter.complete();
      if (identical(_refreshCompleter, refreshCompleter)) {
        _refreshCompleter = null;
      }
    }
  }

  bool _updateCapabilities(PsResult result) {
    _capabilities = _ProcessCapabilities.from(result.procs);
    if (!_capabilities.supportsSort(_procSortMode)) {
      _procSortMode = _capabilities.preferredSort;
      _sortAscending = _procSortMode.defaultAscending;
      return true;
    }
    return false;
  }

  void _selectSort(ProcSortMode mode) {
    if (!_capabilities.supportsSort(mode)) return;
    setState(() {
      if (_procSortMode == mode) {
        _sortAscending = !_sortAscending;
      } else {
        _procSortMode = mode;
        _sortAscending = mode.defaultAscending;
      }
      _result = _result.sortedBy(mode, ascending: _sortAscending);
    });
  }

  void _rebuild(VoidCallback update) {
    if (mounted) setState(update);
  }

  @override
  Widget build(BuildContext context) {
    final system = ref.watch(_provider.select((s) => s.status.system));
    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(up: libL10n.process, down: widget.args.spi.name),
        actions: _buildActions(),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _ProcessLayout.fromWidth(
            constraints.maxWidth,
            _capabilities,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              layout.wide ? _buildWideToolbar() : _buildNarrowToolbar(),
              Divider(height: 1, color: Hairline.color(context)),
              Expanded(child: _buildContent(layout, system)),
            ],
          );
        },
      ),
    );
  }

  String _parseFailureMessage(PsParseFailure failure) => switch (failure) {
    PsParseFailure.unsupportedOutput =>
      context.l10n.processParseUnsupportedOutput,
    PsParseFailure.invalidRows => context.l10n.processParseInvalidRows,
    PsParseFailure.invalidWindowsJson =>
      context.l10n.processParseInvalidWindowsJson,
    PsParseFailure.invalidWindowsRows =>
      context.l10n.processParseInvalidWindowsRows,
  };
}

// --- Widget builders ---

extension _ProcessPageWidgets on _ProcessPageState {
  List<Widget> _buildActions() {
    final parseIssue = _result.issue;
    return [
      if (parseIssue != null)
        Btn.icon(
          text: _parseFailureMessage(parseIssue.failure),
          icon: const Icon(Icons.error_outline, size: 18),
          onTap: () => context.showRoundDialog(
            title: libL10n.error,
            child: Text(_parseFailureMessage(parseIssue.failure)),
            actions: [
              TextButton(
                onPressed: () => Pfs.copy(parseIssue.diagnostics),
                child: Text(libL10n.copy),
              ),
            ],
          ),
        ),
      if (_isRefreshing)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 11),
          child: SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
      else
        Btn.icon(
          text: libL10n.refresh,
          icon: const Icon(Icons.refresh, size: 18),
          onTap: () => _refresh(userTriggered: true),
        ),
    ];
  }

  /// Search, the machine's load, how many processes, and the kernel-thread
  /// switch, on one line. Each keeps its own width: shrunk to share the line
  /// they wrapped inside themselves and the bar grew a second row.
  Widget _buildWideToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kPad, vertical: 9),
      child: Row(
        children: [
          SizedBox(width: 260, child: _buildSearchPill()),
          const SizedBox(width: 17),
          if (_loadText() case final load?) ...[
            Flexible(child: load),
            const SizedBox(width: 13),
          ],
          Text(_countText(), maxLines: 1, style: _metaStyle),
          const Spacer(),
          ?_buildKernelSwitch(labelFirst: true),
        ],
      ),
    );
  }

  Widget _buildNarrowToolbar() {
    final load = _loadText();
    final kernelSwitch = _buildKernelSwitch(labelFirst: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(_kPad, 7, _kPad, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchPill(),
          const SizedBox(height: 9),
          Row(
            children: [
              if (load != null) Expanded(child: load) else const Spacer(),
              Text(_countText(), maxLines: 1, style: _metaStyle),
            ],
          ),
          if (_result.procs.isNotEmpty) ...[
            const SizedBox(height: 9),
            _buildSortChips(),
          ],
          if (kernelSwitch != null) ...[
            const SizedBox(height: 5),
            kernelSwitch,
          ],
        ],
      ),
    );
  }

  Widget _buildSearchPill() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.only(left: 11, right: 4),
      child: Row(
        children: [
          Icon(Icons.search, size: 17, color: UIs.textGrey.color),
          const SizedBox(width: 7),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (value) => _rebuild(() => _query = value),
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration.collapsed(
                hintText: context.l10n.processSearchHint,
                hintStyle: TextStyle(fontSize: 13, color: UIs.textGrey.color),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            Btn.icon(
              text: libL10n.clear,
              icon: const Icon(Icons.close, size: 16),
              onTap: () => _rebuild(() {
                _searchCtrl.clear();
                _query = '';
              }),
            ),
        ],
      ),
    );
  }

  /// `load 1.42 · 0.98 · 0.71`, the minute figure in bold: the other two say
  /// whether it is rising.
  Widget? _loadText() {
    final load = _result.load;
    if (load == null) return null;
    String fmt(double value) => value.toStringAsFixed(2);
    return Text.rich(
      TextSpan(
        style: _metaStyle,
        children: [
          const TextSpan(text: 'load '),
          TextSpan(
            text: fmt(load.one),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          TextSpan(text: ' · ${fmt(load.five)} · ${fmt(load.fifteen)}'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _countText() {
    final shown = _result.procs.length - (_showKernelThreads ? 0 : _kernelCount);
    return context.l10n.processCount(shown);
  }

  /// Null where there is nothing to hide: every machine that is not Linux, and
  /// a Linux container, whose PID namespace has no kernel threads in it.
  Widget? _buildKernelSwitch({required bool labelFirst}) {
    final count = _kernelCount;
    if (count == 0) return null;
    final label = Text(
      context.l10n.processShowKernelThreads(count),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _metaStyle,
    );
    final toggle = SwitchX(
      value: _showKernelThreads,
      onChanged: (value) => _rebuild(() => _showKernelThreads = value),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: () => _rebuild(() => _showKernelThreads = !_showKernelThreads),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: labelFirst
            ? [label, const SizedBox(width: 7), toggle]
            : [toggle, const SizedBox(width: 7), Flexible(child: label)],
      ),
    );
  }

  /// The four orders worth one tap; the rest are behind the menu at the end,
  /// which also stays put when a chip is not offered.
  Widget _buildSortChips() {
    const primary = [
      ProcSortMode.cpu,
      ProcSortMode.mem,
      ProcSortMode.rss,
      ProcSortMode.pid,
    ];
    final chips = primary.where(_capabilities.supportsSort).toList();
    final more = ProcSortMode.values
        .where((mode) => !primary.contains(mode))
        .where(_capabilities.supportsSort)
        .toList();
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final mode in chips) ...[
                  _SortChip(
                    label: _sortLabel(mode),
                    active: _procSortMode == mode,
                    ascending: _sortAscending,
                    onTap: () => _selectSort(mode),
                  ),
                  const SizedBox(width: 7),
                ],
                if (more.contains(_procSortMode))
                  _SortChip(
                    label: _sortLabel(_procSortMode),
                    active: true,
                    ascending: _sortAscending,
                    onTap: () => _selectSort(_procSortMode),
                  ),
              ],
            ),
          ),
        ),
        if (more.isNotEmpty)
          PopupMenuButton<ProcSortMode>(
            tooltip: libL10n.sort,
            icon: const Icon(Icons.filter_list, size: 18),
            onSelected: _selectSort,
            itemBuilder: (_) => [
              for (final mode in more)
                PopupMenuItem(value: mode, child: Text(_sortLabel(mode))),
            ],
          ),
      ],
    );
  }

  Widget _buildContent(_ProcessLayout layout, SystemType system) {
    if (!_hasLoaded && _result.procs.isEmpty) return UIs.centerLoading;
    final procs = _visibleProcs();
    if (procs.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _refresh(userTriggered: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: CenterGreyTitle(
                _result.procs.isEmpty
                    ? (_loadErrorMessage ?? libL10n.empty)
                    : libL10n.empty,
              ).paddingSymmetric(horizontal: _kPad),
            ),
          ],
        ),
      );
    }

    final list = RefreshIndicator(
      onRefresh: () => _refresh(userTriggered: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        itemCount: procs.length,
        itemBuilder: (_, index) {
          final proc = procs[index];
          return layout.wide
              ? _buildWideRow(proc, layout, system)
              : _buildNarrowRow(proc, system);
        },
      ),
    );
    if (!layout.wide) return list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(layout),
        Expanded(child: list),
      ],
    );
  }

  Widget _buildHeader(_ProcessLayout layout) {
    final scheme = Theme.of(context).colorScheme;
    Widget cell(String label, ProcSortMode mode, {bool end = false}) =>
        _SortHeader(
          label: label,
          active: _procSortMode == mode,
          ascending: _sortAscending,
          alignEnd: end,
          onTap: _capabilities.supportsSort(mode)
              ? () => _selectSort(mode)
              : null,
        );
    return ColoredBox(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _kPad, vertical: 3),
        child: _tableLine(
          layout,
          pid: cell('PID', ProcSortMode.pid),
          name: cell(libL10n.name, ProcSortMode.name),
          user: cell(libL10n.user, ProcSortMode.user),
          cpu: cell('CPU', ProcSortMode.cpu, end: true),
          mem: cell('MEM', ProcSortMode.mem, end: true),
          rss: cell('RSS', ProcSortMode.rss, end: true),
          read: cell('R/s', ProcSortMode.read, end: true),
          write: cell('W/s', ProcSortMode.write, end: true),
          action: const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _tableLine(
    _ProcessLayout layout, {
    required Widget pid,
    required Widget name,
    required Widget user,
    required Widget cpu,
    required Widget mem,
    required Widget rss,
    required Widget read,
    required Widget write,
    required Widget action,
  }) {
    Widget fixed(double width, Widget child) => Padding(
      padding: const EdgeInsets.only(left: _kGap),
      child: SizedBox(width: width, child: child),
    );
    return Row(
      children: [
        SizedBox(width: _kColPid, child: pid),
        const SizedBox(width: _kGap),
        Expanded(child: name),
        if (layout.showUser) fixed(_kColUser, user),
        if (layout.showCpu) fixed(_kColCpu, cpu),
        if (layout.showMem) fixed(_kColMem, mem),
        if (layout.showRss) fixed(_kColRss, rss),
        if (layout.showRead) fixed(_kColIo, read),
        if (layout.showWrite) fixed(_kColIo, write),
        fixed(_kColAction, action),
      ],
    );
  }

  Widget _buildWideRow(Proc proc, _ProcessLayout layout, SystemType system) {
    final scheme = Theme.of(context).colorScheme;
    final expanded = _isExpanded(proc);
    final canStop = ProcKill.supports(proc, system);
    final dim = TextStyle(color: scheme.onSurfaceVariant);
    Widget end(String text, {TextStyle? style}) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: const TextStyle(
        fontSize: 13,
        fontFeatures: [FontFeature.tabularFigures()],
      ).merge(style),
    );

    final line = Hover(
      builder: (hovered) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: _kPad, vertical: 7),
        child: _tableLine(
          layout,
          pid: Text('${proc.pid}', style: _monoStyle(13)),
          name: Text(
            proc.command.isEmpty ? '—' : proc.command,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _monoStyle(13).copyWith(
              color: proc.isKernelThread ? scheme.onSurfaceVariant : null,
            ),
          ),
          user: Text(
            proc.user ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
          cpu: _CpuCell(percent: proc.cpu),
          mem: end(_formatPercent(proc.mem), style: _isIdle(proc.mem) ? dim : null),
          rss: end(_formatRss(proc)),
          read: end(_formatNullableSpeed(proc.readSpeed)),
          write: end(_formatNullableSpeed(proc.writeSpeed)),
          action: expanded
              ? Icon(Icons.expand_less, size: 18, color: UIs.textGrey.color)
              : hovered && canStop
              ? Btn.icon(
                  text: '${libL10n.stop} (SIGTERM)',
                  icon: Icon(
                    Icons.stop_circle_outlined,
                    size: 18,
                    color: scheme.error,
                  ),
                  onTap: () => _confirmKill(proc, system, _defaultSignal(system)),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: expanded ? scheme.surfaceContainerLow : null,
        border: Border(bottom: BorderSide(color: Hairline.color(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(onTap: () => _toggleExpanded(proc), child: line),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kPad + _kColPid + _kGap,
                2,
                _kPad,
                13,
              ),
              child: _buildDetail(proc, system, wide: true),
            ),
        ],
      ),
    );
  }

  /// Name and CPU on the first line, where the eye runs down the page; PID,
  /// user, memory and RSS under them. Behind both, a bar as wide as the CPU
  /// share, which is what makes a busy row findable before any number is read.
  Widget _buildNarrowRow(Proc proc, SystemType system) {
    final scheme = Theme.of(context).colorScheme;
    final expanded = _isExpanded(proc);
    final share = ((proc.cpu ?? 0) / 100).clamp(0.0, 1.0);
    final barColor = _kCpuColor.withValues(alpha: 0.2);
    final secondary = [
      if (proc.mem != null) _formatPercent(proc.mem),
      if (proc.rssKb != null) _formatRss(proc),
    ].join(' · ');

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kPad, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  proc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _monoStyle(14).copyWith(
                    fontWeight: FontWeight.w500,
                    color: proc.isKernelThread
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                proc.cpu == null ? '' : _formatPercent(proc.cpu),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  ['${proc.pid}', ?proc.user].join('   '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UIs.text12Grey.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(
                secondary,
                style: UIs.text12Grey.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: expanded ? scheme.surfaceContainerLow : null,
        border: Border(bottom: BorderSide(color: Hairline.color(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _toggleExpanded(proc),
            child: expanded || share <= 0
                ? row
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [barColor, barColor, Colors.transparent],
                        stops: [0, share, share],
                      ),
                    ),
                    child: row,
                  ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(_kPad, 0, _kPad, 13),
              child: _buildDetail(proc, system, wide: false),
            ),
        ],
      ),
    );
  }

  /// The whole command line, what the row had no room for, and the actions.
  ///
  /// Stopping is offered here and on a hovered row, not on every row: a red
  /// button on each of a hundred lines was the loudest thing on the page and
  /// one slip from stopping the wrong process.
  Widget _buildDetail(Proc proc, SystemType system, {required bool wide}) {
    final scheme = Theme.of(context).colorScheme;
    final meta = <(String, String)>[
      if (proc.ppid case final ppid?) ('PPID', '$ppid'),
      if (proc.elapsedSeconds case final seconds?)
        (
          context.l10n.processStarted,
          DateTime.now().subtract(Duration(seconds: seconds)).simple(),
        ),
      if (proc.threads case final threads?) (context.l10n.processThreads, '$threads'),
      if (proc.nice case final nice?) ('nice', '$nice'),
      if (proc.stat case final stat? when stat.isNotEmpty)
        (context.l10n.status, _stateLabel(stat)),
      if (proc.time case final time? when time.isNotEmpty) ('TIME', time),
      if (proc.vsz != null) ('VSZ', _formatVsz(proc)),
      if (proc.tty case final tty? when tty != '?' && tty != '??')
        ('TTY', tty),
      if (!wide && proc.readSpeed != null)
        ('R/s', _formatNullableSpeed(proc.readSpeed)),
      if (!wide && proc.writeSpeed != null)
        ('W/s', _formatNullableSpeed(proc.writeSpeed)),
    ];
    final signals = ProcKill.supports(proc, system)
        ? ProcKill.signalsFor(system)
        : const <ProcSignal>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(7),
          ),
          child: SelectableText(
            proc.command.isEmpty ? '—' : proc.command,
            style: _monoStyle(12).copyWith(
              color: scheme.onSurface,
              height: 1.5,
            ),
          ),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 9),
          Wrap(
            spacing: 17,
            runSpacing: 4,
            children: [
              for (final (label, value) in meta)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$label '),
                      TextSpan(
                        text: value,
                        style: TextStyle(color: scheme.onSurface),
                      ),
                    ],
                  ),
                  style: UIs.text12Grey.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 9),
        Wrap(
          spacing: 9,
          runSpacing: 7,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => Pfs.copy(proc.command),
              icon: const Icon(Icons.content_copy, size: 15),
              label: Text(libL10n.copy),
            ),
            for (final signal in signals)
              _buildStopButton(proc, system, signal, wide: wide),
          ],
        ),
      ],
    );
  }

  Widget _buildStopButton(
    Proc proc,
    SystemType system,
    ProcSignal signal, {
    required bool wide,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final label = _signalLabel(signal, system, withName: wide);
    final polite = signal == ProcSignal.term || system == SystemType.windows;
    final onPressed = _isRefreshing
        ? null
        : () => _confirmKill(proc, system, signal);
    if (!polite) {
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
        child: Text(label),
      );
    }
    if (wide) {
      return TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(foregroundColor: scheme.error),
        icon: const Icon(Icons.stop_circle_outlined, size: 17),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.error,
        side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
      ),
      icon: const Icon(Icons.stop_circle_outlined, size: 17),
      label: Text(label),
    );
  }

  TextStyle _monoStyle(double size) => TextStyle(
    fontFamily: 'monospace',
    fontSize: size,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  TextStyle get _metaStyle => TextStyle(
    fontSize: 12,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

// --- Utils ---

extension _ProcessPageUtils on _ProcessPageState {
  int get _kernelCount => _result.procs.where((p) => p.isKernelThread).length;

  List<Proc> _visibleProcs() {
    final needle = _query.trim().toLowerCase();
    return _result.procs
        .where((proc) => _showKernelThreads || !proc.isKernelThread)
        .where(
          (proc) =>
              needle.isEmpty ||
              '${proc.pid}' == needle ||
              proc.command.toLowerCase().contains(needle) ||
              (proc.user?.toLowerCase().contains(needle) ?? false),
        )
        .toList(growable: false);
  }

  bool _isExpanded(Proc proc) {
    final expanded = _expanded;
    return expanded != null && _isSameProcess(expanded, proc);
  }

  void _toggleExpanded(Proc proc) {
    _rebuild(() => _expanded = _isExpanded(proc) ? null : proc);
  }

  String _sortLabel(ProcSortMode mode) => switch (mode) {
    ProcSortMode.cpu => 'CPU',
    ProcSortMode.mem => 'MEM',
    ProcSortMode.rss => 'RSS',
    ProcSortMode.read => 'R/s',
    ProcSortMode.write => 'W/s',
    ProcSortMode.pid => 'PID',
    ProcSortMode.user => libL10n.user,
    ProcSortMode.name => libL10n.name,
  };

  ProcSignal _defaultSignal(SystemType system) =>
      ProcKill.signalsFor(system).first;

  /// `Stop (SIGTERM)` and `Force kill (SIGKILL)` where there is room, without
  /// the signal where there is not. On Windows the one stop there is is a
  /// forced one, and it is called that.
  String _signalLabel(
    ProcSignal signal,
    SystemType system, {
    required bool withName,
  }) {
    final force = signal == ProcSignal.kill;
    final label = force ? context.l10n.processForceKill : libL10n.stop;
    if (!withName || system == SystemType.windows) return label;
    return '$label (${force ? 'SIGKILL' : 'SIGTERM'})';
  }

  /// `S (sleeping)`: the letter is what `ps` and `top` print, the word is what
  /// the letter means. ps(1)'s own terms, left untranslated like the letter.
  String _stateLabel(String stat) {
    final word = switch (stat[0]) {
      'R' => 'running',
      'S' => 'sleeping',
      'D' => 'disk sleep',
      'I' => 'idle',
      'T' => 'stopped',
      't' => 'tracing stop',
      'Z' => 'zombie',
      'X' => 'dead',
      'W' => 'paging',
      _ => null,
    };
    return word == null ? stat : '$stat ($word)';
  }

  bool _isIdle(double? percent) => percent == null || percent < 1;

  String _formatPercent(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(1)}%';

  String _formatRss(Proc proc) {
    final rssKb = proc.rssKb;
    if (rssKb == null) return '—';
    return (rssKb * 1024).bytes2Str;
  }

  /// Busybox prints a large VSZ with a unit suffix (`12m`), which is not a
  /// number of KiB and is shown as it came.
  String _formatVsz(Proc proc) {
    final raw = proc.vsz!;
    final kib = int.tryParse(raw);
    return kib == null ? raw : (kib * 1024).bytes2Str;
  }

  String _formatNullableSpeed(double? bytes) =>
      bytes == null ? '—' : '${bytes.bytes2Str}/s';

  /// Whether the server has answered at all. Not whether a connection is
  /// already open: `ensureExec` opens one when there is none, which is what a
  /// server reached over its monitor agent always needs.
  bool _canRunProcessCmd(ServerState serverState) {
    final conn = serverState.conn;
    return conn == ServerConn.connected || conn == ServerConn.finished;
  }

  bool _isSameProcess(Proc expected, Proc current) {
    if (expected.pid != current.pid) return false;
    if (expected.startId != null || current.startId != null) {
      return expected.startId != null && expected.startId == current.startId;
    }
    if (expected.start != null || current.start != null) {
      return expected.start != null && expected.start == current.start;
    }
    return expected.command == current.command;
  }
}

// --- Actions ---

extension _ProcessPageActions on _ProcessPageState {
  Future<void> _confirmKill(
    Proc proc,
    SystemType system,
    ProcSignal signal,
  ) async {
    final action = _signalLabel(signal, system, withName: true);
    final confirmed = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(libL10n.askContinue('$action ${proc.name} (${proc.pid})')),
      actions: Btnx.cancelRedOk,
    );
    if (confirmed != true || !mounted) return;

    final command = ProcKill.command(proc, system, signal);
    if (command == null) {
      Toast.show(libL10n.notAvailable);
      return;
    }
    // POSIX shell syntax, so it is fed to one rather than to whatever the
    // account's login shell happens to be. Windows builds a PowerShell
    // command instead, which has to run as the command.
    final entry = system == SystemType.windows ? null : 'sh';

    var (outcome, _) = await context.showLoadingDialog(
      fn: () => _runKill((exec) => exec.run(command, entry: entry)),
    );
    if (!mounted || outcome == null) return;

    // Someone else's process. Asked again as root, the way a user would with
    // `sudo kill`, rather than reported as a failure they can do nothing about.
    if (outcome == ProcKillOutcome.denied && system != SystemType.windows) {
      outcome = await _killWithSudo(command);
      if (!mounted || outcome == null) return;
    }

    switch (outcome) {
      case ProcKillOutcome.succeeded:
        _rebuild(() => _expanded = null);
        await _refresh(userTriggered: true);
      case ProcKillOutcome.targetChanged:
        Toast.show(context.l10n.processKillTargetChanged);
        await _refresh(userTriggered: true);
      case ProcKillOutcome.denied:
        Toast.error(libL10n.permissionDenied);
      case ProcKillOutcome.failed:
        Toast.error(libL10n.fail);
    }
  }

  /// Null when the user declined the password prompt.
  Future<ProcKillOutcome?> _killWithSudo(String command) async {
    final isRoot = widget.args.spi.isRoot;
    var (result, _) = await context.showLoadingDialog(
      fn: () => _runExec(
        (exec) => PrivilegedExec.run(exec, command, isRoot: isRoot),
      ),
    );
    if (!mounted || result == null) return null;
    if (result.exitCode == kSudoPasswordRejected) {
      final password = await context.showPwdDialog(
        title: libL10n.sudoPassword,
        label: widget.args.spi.ssh?.user ?? '',
        id: '${widget.args.spi.id}_sudo_process',
      );
      if (!mounted || password == null || password.isEmpty) return null;
      (result, _) = await context.showLoadingDialog(
        fn: () => _runExec(
          (exec) => PrivilegedExec.run(
            exec,
            command,
            isRoot: false,
            password: password,
          ),
        ),
      );
      if (!mounted || result == null) return null;
      if (result.exitCode == kSudoPasswordRejected) {
        Toast.error(libL10n.permissionDenied);
        return null;
      }
    }
    return ProcKill.outcome(result.stdout);
  }

  Future<ProcKillOutcome> _runKill(
    Future<ExecResult> Function(ServerExec exec) run,
  ) async {
    final result = await _runExec(run);
    return ProcKill.outcome(result.stdout);
  }

  Future<ExecResult> _runExec(
    Future<ExecResult> Function(ServerExec exec) run,
  ) async {
    final exec = await ref.read(_provider.notifier).ensureExec();
    return run(exec).timeout(_processCommandTimeout);
  }
}

class _ProcessCapabilities {
  const _ProcessCapabilities({
    required this.hasUser,
    required this.hasCpu,
    required this.hasMem,
    required this.hasRss,
    required this.hasRead,
    required this.hasWrite,
    required this.hasReadSpeed,
    required this.hasWriteSpeed,
  });

  static const empty = _ProcessCapabilities(
    hasUser: false,
    hasCpu: false,
    hasMem: false,
    hasRss: false,
    hasRead: false,
    hasWrite: false,
    hasReadSpeed: false,
    hasWriteSpeed: false,
  );

  factory _ProcessCapabilities.from(List<Proc> procs) {
    var hasUser = false;
    var hasCpu = false;
    var hasMem = false;
    var hasRss = false;
    var hasRead = false;
    var hasWrite = false;
    var hasReadSpeed = false;
    var hasWriteSpeed = false;
    for (final proc in procs) {
      hasUser |= proc.user?.isNotEmpty == true;
      hasCpu |= proc.cpu != null;
      hasMem |= proc.mem != null;
      hasRss |= proc.rssKb != null;
      hasRead |= proc.readBytes != null;
      hasWrite |= proc.writeBytes != null;
      hasReadSpeed |= proc.readSpeed != null;
      hasWriteSpeed |= proc.writeSpeed != null;
    }
    return _ProcessCapabilities(
      hasUser: hasUser,
      hasCpu: hasCpu,
      hasMem: hasMem,
      hasRss: hasRss,
      hasRead: hasRead,
      hasWrite: hasWrite,
      hasReadSpeed: hasReadSpeed,
      hasWriteSpeed: hasWriteSpeed,
    );
  }

  final bool hasUser;
  final bool hasCpu;
  final bool hasMem;
  final bool hasRss;
  final bool hasRead;
  final bool hasWrite;
  final bool hasReadSpeed;
  final bool hasWriteSpeed;

  bool supportsSort(ProcSortMode mode) => switch (mode) {
    ProcSortMode.cpu => hasCpu,
    ProcSortMode.mem => hasMem,
    ProcSortMode.rss => hasRss,
    ProcSortMode.read => hasReadSpeed,
    ProcSortMode.write => hasWriteSpeed,
    ProcSortMode.user => hasUser,
    ProcSortMode.pid || ProcSortMode.name => true,
  };

  ProcSortMode get preferredSort {
    if (hasCpu) return ProcSortMode.cpu;
    if (hasMem) return ProcSortMode.mem;
    if (hasRss) return ProcSortMode.rss;
    if (hasReadSpeed) return ProcSortMode.read;
    if (hasWriteSpeed) return ProcSortMode.write;
    return ProcSortMode.pid;
  }
}

class _ProcessLayout {
  const _ProcessLayout({
    required this.wide,
    required this.showUser,
    required this.showCpu,
    required this.showMem,
    required this.showRss,
    required this.showRead,
    required this.showWrite,
  });

  factory _ProcessLayout.fromWidth(
    double width,
    _ProcessCapabilities capabilities,
  ) {
    final wide = width >= _kWideWidth;
    return _ProcessLayout(
      wide: wide,
      showUser: wide && capabilities.hasUser,
      showCpu: wide && capabilities.hasCpu,
      showMem: wide && capabilities.hasMem,
      showRss:
          wide &&
          capabilities.hasRss &&
          (width >= _kRssWidth ||
              (!capabilities.hasUser && !capabilities.hasMem)),
      showRead: wide && width >= _kIoWidth && capabilities.hasRead,
      showWrite: wide && width >= _kIoWidth && capabilities.hasWrite,
    );
  }

  final bool wide;
  final bool showUser;
  final bool showCpu;
  final bool showMem;
  final bool showRss;
  final bool showRead;
  final bool showWrite;
}

/// A percentage over a bar as wide as it, right-aligned under its header, in
/// the CPU chart's colour. Below 1% the number is grey: most of a process list
/// is idle, and the few that are not should be the ones that read as text.
class _CpuCell extends StatelessWidget {
  const _CpuCell({required this.percent});

  final double? percent;

  @override
  Widget build(BuildContext context) {
    final value = percent;
    final scheme = Theme.of(context).colorScheme;
    if (value == null) {
      return Text('—', textAlign: TextAlign.end, style: UIs.textGrey);
    }
    final idle = value < 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${value.toStringAsFixed(1)}%',
          maxLines: 1,
          style: TextStyle(
            fontSize: 13,
            fontWeight: idle ? null : FontWeight.w500,
            color: idle ? scheme.onSurfaceVariant : null,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0.0, 1.0),
            minHeight: 3,
            backgroundColor: scheme.surfaceContainerHighest,
            color: _kCpuColor,
          ),
        ),
      ],
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: active ? scheme.primaryContainer : Colors.transparent,
      shape: StadiumBorder(
        side: active
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          child: Text(
            active ? '$label ${ascending ? '↑' : '↓'}' : label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w500 : null,
              color: active ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _SortHeader extends StatelessWidget {
  const _SortHeader({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
    this.alignEnd = false,
  });

  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback? onTap;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    final semanticsLabel = active
        ? '$label, ${ascending ? libL10n.ascending : libL10n.descending}'
        : label;
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      selected: active,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: alignEnd
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.66,
                    color: color,
                  ),
                ),
              ),
              if (active) ...[
                const SizedBox(width: 2),
                Icon(
                  ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 13,
                  color: color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
