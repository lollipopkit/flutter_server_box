// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/server_picker.dart';
import 'package:server_box/data/model/server/benchmark/benchmark_run.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/benchmark.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/benchmark.dart';
import 'package:server_box/view/page/benchmark/config.dart';
import 'package:server_box/view/page/benchmark/history_tile.dart';
import 'package:server_box/view/page/benchmark/result.dart';
import 'package:server_box/view/page/benchmark/running_card.dart';
import 'package:server_box/view/widget/pane_settings.dart';

/// The benchmark tab: pick a machine, run one, and read what every machine has
/// reported so far.
///
/// A tab rather than an entry on each server's own page, which is where this
/// started. A benchmark is not something done *to* a server so much as a
/// measurement compared *between* them — the number is close to meaningless on
/// its own and only means something beside another machine's. Keeping the whole
/// history on one page is that comparison; a per-server page could only ever
/// show one column of it.
///
/// Two columns, like the snippet and server tabs. The history is a list of
/// records, and what is done with one — start a run, watch it, read a result —
/// is the other column. A run takes a quarter of an hour, so reading an old
/// result without losing sight of the one in flight is most of the point.
class BenchmarkTabPage extends ConsumerStatefulWidget {
  const BenchmarkTabPage({super.key});

  @override
  ConsumerState<BenchmarkTabPage> createState() => _BenchmarkTabPageState();
}

class _BenchmarkTabPageState extends ConsumerState<BenchmarkTabPage> {
  /// The machine the right column runs against.
  String? _selectedId;

  /// A past run being read, or null for the selected machine's own column.
  String? _viewingRunId;

  /// Redraws the elapsed clock of a run in flight. The record itself only
  /// changes when a poll comes back, which is up to twenty seconds apart.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _selected != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Every server, in the order the server tab shows them.
  ///
  /// Not filtered by capability, though it could be. Whether a monitor-backed
  /// server can run a command is its agent's `full_access` grant, and that is
  /// unknown until the agent has been asked — so filtering on it would hide
  /// servers that can, on the strength of not having looked. The run reports a
  /// refusal itself, which is both later and honest.
  List<Spi> get _servers {
    final order = ref.watch(serversProvider.select((s) => s.serverOrder));
    final byId = _byId;
    return [
      for (final id in order) ?byId[id],
    ];
  }

  /// The store has no lookup by id — `fetch()` is the whole list, off a cache —
  /// so one map serves the picker, the selection and every history row.
  Map<String, Spi> get _byId => {
    for (final spi in Stores.server.fetch()) spi.id: spi,
  };

  Spi? get _selected {
    final id = _selectedId;
    return id == null ? null : _byId[id];
  }

  @override
  Widget build(BuildContext context) {
    final servers = _servers;
    // A run already going decides the selection, once. Whatever else the user
    // was last looking at, the machine with fifteen minutes of work in flight
    // is the one worth showing.
    _selectedId ??= _runningIdAmong(servers) ?? servers.firstOrNull?.id;

    // Read here and passed down, not read where it is used. `detailBuilder`
    // runs inside the pane's own `Builder`, which is a different element from
    // this one, so `ref.listen` there asserts — it threw on every frame that
    // had a detail to draw, which is every frame. `ref.watch` does not assert,
    // which is worse rather than better: it would quietly subscribe from the
    // wrong element. Both belong here.
    final spi = _selected;
    final state = spi == null ? null : ref.watch(benchmarkProvider(spi));
    if (spi != null) {
      ref.listen<String?>(benchmarkProvider(spi).select((s) => s.error), (
        _,
        err,
      ) {
        if (err == null) return;
        Toast.error(l10n.benchmarkStartFailed, body: err);
        ref.read(benchmarkProvider(spi).notifier).clearError();
      });
    }

    return PaneSettings.listenAll((paneWidth, paneCollapsed) {
      return AdaptivePanes.detail(
        listWidth: paneWidth,
        onListWidthChanged: PaneSettings.saveWidth,
        collapsed: paneCollapsed,
        onCollapsedChanged: PaneSettings.saveCollapsed,
        collapseTooltip: libL10n.fold,
        expandTooltip: libL10n.open,
        // Null while the run column is showing, which is how `NestedNavigator`
        // is told a change is a way *back*: it reads `rootId` becoming null as
        // the detail closing, and animates accordingly. Keying this on the
        // selected machine as well made every return from a result — a
        // non-null id replacing another non-null id — animate as a way in, so
        // the result slid off the wrong edge.
        detailId: _viewingRunId,
        onCloseDetail: () => setState(() => _viewingRunId = null),
        detailBuilder: (_) => _buildDetail(spi, state),
        listBuilder: (_, split) => _buildList(servers, split),
      );
    });
  }

  String? _runningIdAmong(List<Spi> servers) {
    for (final spi in servers) {
      if (BenchmarkStore.instance.activeFor(spi.id) != null) return spi.id;
    }
    return null;
  }
}

// --- Widgets ---

extension _Widgets on _BenchmarkTabPageState {
  /// The left column: which machine, and everything that has been run.
  Widget _buildList(List<Spi> servers, bool split) {
    final byId = _byId;
    final history = BenchmarkStore.instance.all();

    return Scaffold(
      // No title: the nav rail beside this already names the tab, and the room
      // is better spent on the one thing this column is for besides listing.
      //
      // An explicit leading for the same reason as the run column's: with none,
      // `CustomAppBar` supplies a back button wired to `onCloseDetail`, and
      // this column is not a detail — it is the thing a detail is closed back
      // to.
      appBar: CustomAppBar(
        leading: const SizedBox.shrink(),
        actions: [
          if (servers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: l10n.benchmark,
              onPressed: _pickServer,
            ),
        ],
      ),
      body: servers.isEmpty
          ? _centered(l10n.benchmarkNoServers)
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              children: [
                if (history.isEmpty)
                  _centered(l10n.benchmarkNoRuns)
                else
                  // Every server's, not the selected one's. Switching machines
                  // to read a result would make the list jump under the hand
                  // that switched.
                  for (final run in history)
                    BenchmarkHistoryTile(
                      run: run,
                      // Named here because the list spans servers, which is the
                      // whole point of it: a row without one says nothing.
                      serverName: byId[run.serverId]?.name,
                      selected: split && _viewingRunId == run.id,
                      onTap: () => _openRun(run, split),
                      onDelete: () => _onDelete(run),
                    ),
                UIs.height13,
              ],
            ),
    );
  }

  Widget _centered(String text) {
    return Padding(
      padding: const EdgeInsets.all(27),
      child: Text(text, style: UIs.textGrey, textAlign: TextAlign.center),
    );
  }


  /// The right column: a result being read, or the selected machine's run.
  Widget _buildDetail(Spi? spi, BenchmarkState? state) {
    if (_viewingRunId case final id?) {
      final run = BenchmarkStore.instance.get(id);
      // Deleted from the list beside it. Falls through to the machine's own
      // column rather than rendering a record that is gone.
      if (run != null) return BenchmarkResultPage(args: run);
    }
    if (spi == null || state == null) {
      return const EmptyPane(icon: Icons.speed_outlined);
    }
    return _buildRunPane(spi, state);
  }

  Widget _buildRunPane(Spi spi, BenchmarkState state) {
    return Scaffold(
      // No back button. `CustomAppBar` draws one at the root of a detail pane
      // wired to `onCloseDetail`, which is right for a result read out of the
      // history — but this *is* the root, so the button had nowhere to go and
      // did nothing when pressed. An explicit leading is how the widget is told
      // not to supply its own.
      appBar: CustomAppBar(
        leading: const SizedBox.shrink(),
        title: Text(spi.name),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        children: [
          if (state.active case final run?)
            BenchmarkRunningCard(
              run: run,
              busy: state.isBusy,
              onCancel: () => _onCancel(spi),
            )
          else
            BenchmarkConfig(
              key: ValueKey(spi.id),
              initial: state.history.firstOrNull?.options,
              busy: state.isBusy,
              onStart: (options) =>
                  ref.read(benchmarkProvider(spi).notifier).start(options),
            ),
          UIs.height13,
        ],
      ),
    );
  }
}

// --- Actions ---

extension _Actions on _BenchmarkTabPageState {
  /// Which machine to run on.
  ///
  /// The shared picker, not one of this page's own: with more than a handful of
  /// servers the question needs search, tags and the arrangement the user
  /// already made, and a bespoke dropdown here had none of them.
  Future<void> _pickServer() async {
    final spi = await pickServer(
      context,
      selectedId: _selectedId,
      // A machine with a run in flight is worth spotting here, since choosing
      // another is what hides it.
      trailingOf: (spi) => BenchmarkStore.instance.activeFor(spi.id) != null
          ? const Icon(Icons.timelapse, size: 17)
          : null,
    );
    if (spi == null || !mounted) return;
    setState(() {
      _selectedId = spi.id;
      // Choosing a machine is asking to act on it, so the right column stops
      // showing whatever old result was being read.
      _viewingRunId = null;
    });
  }

  /// Reads a past run: in the right column when there is one, as a page when
  /// the window is too narrow for two.
  void _openRun(BenchmarkRun run, bool split) {
    if (split) {
      setState(() => _viewingRunId = run.id);
      return;
    }
    BenchmarkResultPage.route.go(context, run);
  }

  Future<void> _onCancel(Spi spi) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(l10n.benchmarkCancelConfirm),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true) return;
    await ref.read(benchmarkProvider(spi).notifier).cancel();
  }

  Future<void> _onDelete(BenchmarkRun run) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(l10n.benchmarkDeleteConfirm),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true) return;
    BenchmarkStore.instance.remove(run.id);
    if (!mounted) return;
    setState(() {
      // The right column was showing it. Back to the machine's own column,
      // rather than to a pane rendering a record that no longer exists.
      if (_viewingRunId == run.id) _viewingRunId = null;
    });
  }
}
