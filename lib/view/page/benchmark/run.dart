import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/provider/benchmark.dart';
import 'package:server_box/view/page/benchmark/config.dart';
import 'package:server_box/view/page/benchmark/running_card.dart';

/// One machine's benchmark: the form to start one, or the run in flight.
///
/// Its own widget rather than something the tab draws inline, because it is
/// shown in two places: beside the history when there is room for two columns,
/// and *as* the single column when there is not. It has no route — nothing
/// pushes it — so the machine it shows changes by rebuilding rather than by
/// stacking a page per machine.
class BenchmarkRunPage extends ConsumerStatefulWidget {
  const BenchmarkRunPage({
    super.key,
    required this.args,
    this.inPane = false,
    this.leading,
    this.actions,
  });

  final SpiRequiredArgs args;

  /// Put in the bar by whoever is showing this.
  ///
  /// With one column this page *is* the tab, so it carries the tab's controls:
  /// the way to the history, and the way to another machine. Beside a history
  /// column it carries neither, because both are already on screen.
  final Widget? leading;
  final List<Widget>? actions;

  /// Whether this is the root of a detail pane rather than a pushed page.
  ///
  /// `CustomAppBar` offers a back button at a pane's root, wired to closing the
  /// detail. Right for something opened *into* the pane; wrong here, where this
  /// is what a detail is closed back *to* — the button would have nowhere to go.
  final bool inPane;


  @override
  ConsumerState<BenchmarkRunPage> createState() => _BenchmarkRunPageState();
}

class _BenchmarkRunPageState extends ConsumerState<BenchmarkRunPage> {
  late final _spi = widget.args.spi;

  /// Redraws the elapsed clock. The record itself only changes when a poll
  /// comes back, which is up to twenty seconds apart.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(benchmarkProvider(_spi)).active != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(benchmarkProvider(_spi));
    ref.listen<String?>(benchmarkProvider(_spi).select((s) => s.error), (
      _,
      err,
    ) {
      if (err == null) return;
      Toast.error(l10n.benchmarkStartFailed, body: err);
      ref.read(benchmarkProvider(_spi).notifier).clearError();
    });

    return Scaffold(
      appBar: CustomAppBar(
        leading: widget.leading ?? (widget.inPane ? const SizedBox.shrink() : null),
        title: Text(_spi.name),
        actions: widget.actions,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        children: [
          if (state.active case final run?)
            BenchmarkRunningCard(
              run: run,
              busy: state.isBusy,
              onCancel: _onCancel,
            )
          else
            BenchmarkConfig(
              initial: state.history.firstOrNull?.options,
              busy: state.isBusy,
              onStart: (options) =>
                  ref.read(benchmarkProvider(_spi).notifier).start(options),
            ),
          UIs.height13,
        ],
      ),
    );
  }

  Future<void> _onCancel() async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(l10n.benchmarkCancelConfirm),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true) return;
    await ref.read(benchmarkProvider(_spi).notifier).cancel();
  }
}
