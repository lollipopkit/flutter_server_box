// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
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

/// The benchmark tab: pick a machine, run one, and read what every machine has
/// reported so far.
///
/// A tab rather than an entry on each server's own page, which is where this
/// started. A benchmark is not something done *to* a server so much as a
/// measurement compared *between* them — the number is close to meaningless on
/// its own and only means something beside another machine's. Keeping the whole
/// history on one page is that comparison; a per-server page could only ever
/// show one column of it.
class BenchmarkTabPage extends ConsumerStatefulWidget {
  const BenchmarkTabPage({super.key});

  @override
  ConsumerState<BenchmarkTabPage> createState() => _BenchmarkTabPageState();
}

class _BenchmarkTabPageState extends ConsumerState<BenchmarkTabPage> {
  String? _selectedId;

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

    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.benchmark)),
      body: servers.isEmpty ? _buildNoServers() : _buildBody(servers),
    );
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
  Widget _buildNoServers() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 27),
        child: Text(
          l10n.benchmarkNoServers,
          style: UIs.textGrey,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBody(List<Spi> servers) {
    final spi = _selected;
    final byId = _byId;
    final history = BenchmarkStore.instance.all();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      children: [
        _buildPicker(servers),
        UIs.height13,
        if (spi != null) _buildForServer(spi),
        UIs.height13,
        Text('  ${libL10n.log}', style: UIs.textGrey),
        UIs.height7,
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.all(27),
            child: Text(
              l10n.benchmarkNoRuns,
              style: UIs.textGrey,
              textAlign: TextAlign.center,
            ),
          )
        else
          // Every server's, not the selected one's. Switching machines to read
          // a result would make the list jump under the hand that switched.
          for (final run in history)
            BenchmarkHistoryTile(
              run: run,
              // Named here because the list spans servers, which is the whole
              // point of it: a row without one says nothing.
              serverName: byId[run.serverId]?.name,
              onTap: () => BenchmarkResultPage.route.go(context, run),
              onDelete: () => _onDelete(run),
            ),
        UIs.height13,
      ],
    );
  }

  /// Which machine to run on.
  ///
  /// A dropdown rather than a row of chips: this list is as long as the user's
  /// server list, and a row that scrolls sideways hides the entries past the
  /// edge without saying they are there.
  Widget _buildPicker(List<Spi> servers) {
    return CardX(
      child: ListTile(
        leading: const Icon(Icons.dns_outlined),
        title: Text(libL10n.server, style: UIs.text13Grey),
        subtitle: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _selectedId,
            items: [
              for (final spi in servers)
                DropdownMenuItem(
                  value: spi.id,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          spi.name,
                          style: UIs.text15,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // A machine with a run in flight is worth spotting from
                      // the closed dropdown, since choosing another hides it.
                      if (BenchmarkStore.instance.activeFor(spi.id) != null)
                        const Icon(Icons.timelapse, size: 15),
                    ],
                  ),
                ),
            ],
            onChanged: (id) => setState(() => _selectedId = id),
          ),
        ),
      ),
    );
  }

  /// The selected machine's run, or the form to start one.
  Widget _buildForServer(Spi spi) {
    final state = ref.watch(benchmarkProvider(spi));
    ref.listen<String?>(benchmarkProvider(spi).select((s) => s.error), (_, err) {
      if (err == null) return;
      Toast.error(l10n.benchmarkStartFailed, body: err);
      ref.read(benchmarkProvider(spi).notifier).clearError();
    });

    if (state.active case final run?) {
      return BenchmarkRunningCard(
        run: run,
        busy: state.isBusy,
        onCancel: () => _onCancel(spi),
      );
    }
    return BenchmarkConfig(
      key: ValueKey(spi.id),
      initial: state.history.firstOrNull?.options,
      busy: state.isBusy,
      onStart: (options) =>
          ref.read(benchmarkProvider(spi).notifier).start(options),
    );
  }
}

// --- Actions ---

extension _Actions on _BenchmarkTabPageState {
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
    if (mounted) setState(() {});
  }
}
