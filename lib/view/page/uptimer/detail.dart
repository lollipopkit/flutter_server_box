import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/provider/uptimer/client.dart';
import 'package:server_box/data/provider/uptimer/detail.dart';
import 'package:server_box/data/provider/uptimer/uptimer.dart';
import 'package:server_box/view/page/server/card/sizes.dart';
import 'package:server_box/view/page/server/detail/focus_parts.dart';
import 'package:server_box/view/page/server/detail/status_detail_shell.dart';
import 'package:server_box/view/page/server/tab/element_flight.dart';
import 'package:server_box/view/page/uptimer/common.dart';
import 'package:server_box/view/page/uptimer/detail_latency.dart';
import 'package:server_box/view/page/uptimer/detail_sections.dart';
import 'package:server_box/view/page/uptimer/detail_status.dart';
import 'package:server_box/view/page/uptimer/detail_uptime.dart';
import 'package:server_box/view/page/uptimer/edit.dart';

/// Full detail view for an Uptimer monitor.
///
/// Supports both pushed single-pane navigation (`bare: false`) and embedded
/// two-pane hosting in the Status tab (`bare: true`).
final class UptimerDetailPage extends ConsumerWidget {
  final UptimerDetailArgs args;
  final bool bare;
  final FlightAnchorBinding? stripAnchor;
  final bool hideStrip;

  const UptimerDetailPage({
    super.key,
    required this.args,
    this.bare = false,
    this.stripAnchor,
    this.hideStrip = false,
  });

  static const route = AppRouteArg<void, UptimerDetailArgs>(
    page: UptimerDetailPage.new,
    path: '/uptimer/detail',
  );

  int get _monitorId => args.monitor.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(
      uptimerProvider.select((s) => s.monitors[_monitorId]),
    );
    final monitor = stored ?? args.monitor;

    return StatusDetailShell(
      entityKey: _monitorId,
      bare: bare,
      existsInStore: stored != null,
      builder: (ctx, activeRef) {
        final config = activeRef.watch(
          uptimerProvider.select((s) => s.configs[_monitorId]),
        );
        final busy = activeRef.watch(
          uptimerProvider.select((s) => s.busyIds.contains(_monitorId)),
        );
        final incidents = activeRef.watch(
          uptimerProvider.select((s) => s.incidentsFor(_monitorId)),
        );
        final activeMaint = activeRef.watch(
          uptimerProvider.select((s) => s.activeMaintenanceFor(_monitorId)),
        );
        final upcomingMaint = activeRef.watch(
          uptimerProvider.select((s) => s.upcomingMaintenanceFor(_monitorId)),
        );
        final detail = activeRef.watch(uptimerDetailProvider(_monitorId));

        return (
          title: monitor.name,
          subtitle: monitor.displayAddr,
          onRefresh: detail.isLoading
              ? null
              : () => unawaited(
                  activeRef
                      .read(uptimerDetailProvider(_monitorId).notifier)
                      .refresh(),
                ),
          onEdit: () =>
              unawaited(_openEdit(ctx, activeRef, monitor, config)),
          body: _UptimerDetailBody(
            monitor: monitor,
            config: config,
            detail: detail,
            busy: busy,
            bare: bare,
            stripAnchor: stripAnchor,
            hideStrip: hideStrip,
            incidents: incidents,
            activeMaint: activeMaint,
            upcomingMaint: upcomingMaint,
            onRefresh: () => activeRef
                .read(uptimerDetailProvider(_monitorId).notifier)
                .refresh(),
            onRangeSelected: (range) => unawaited(
              activeRef
                  .read(uptimerDetailProvider(_monitorId).notifier)
                  .setRange(range),
            ),
            onTest: () => unawaited(_onTest(ctx, activeRef)),
            onTogglePause: () => unawaited(
              _onTogglePause(
                ctx,
                activeRef,
                monitor.status == UptimerMonitorStatus.paused,
              ),
            ),
            onRotatePushToken: () =>
                unawaited(_onRotatePushToken(ctx, activeRef, monitor)),
            onLoadMoreOutages: () =>
                unawaited(_onLoadMoreOutages(ctx, activeRef)),
          ),
        );
      },
    );
  }

  Future<void> _onLoadMoreOutages(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(uptimerDetailProvider(_monitorId).notifier)
          .loadMoreOutages();
    } catch (e) {
      if (context.mounted) Toast.show(uptimerErrorMessage(e));
    }
  }

  Future<void> _onTest(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(uptimerDetailProvider(_monitorId).notifier).runTest();
    } catch (e) {
      if (context.mounted) Toast.show(uptimerErrorMessage(e));
    }
  }

  Future<void> _onTogglePause(
    BuildContext context,
    WidgetRef ref,
    bool isPaused,
  ) async {
    try {
      final notifier = ref.read(uptimerProvider.notifier);
      if (isPaused) {
        await notifier.resumeMonitor(_monitorId);
      } else {
        await notifier.pauseMonitor(_monitorId);
      }
    } catch (e) {
      if (context.mounted) Toast.show(uptimerErrorMessage(e));
    }
  }

  Future<void> _onRotatePushToken(
    BuildContext context,
    WidgetRef ref,
    UptimerMonitorCard monitor,
  ) async {
    final confirmed = await context.showSheet<bool>(
      title: l10n.uptimerRotatePushUrl,
      child: Text(l10n.uptimerRotatePushUrlConfirm(monitor.name)),
      actions: Btnx.cancelRedOk,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final mutation = await ref
          .read(uptimerProvider.notifier)
          .rotatePushToken(_monitorId);
      if (!context.mounted) return;
      if (mutation.pushToken case final token?) {
        final api = ref.read(uptimerApiProvider);
        await showUptimerPushUrlSheet(
          context,
          name: monitor.name,
          url: api.pushUrl(token),
        );
      }
    } catch (e) {
      if (context.mounted) Toast.show(uptimerErrorMessage(e));
    }
  }

  Future<void> _openEdit(
    BuildContext context,
    WidgetRef ref,
    UptimerMonitorCard monitor,
    UptimerMonitorConfig? config,
  ) async {
    final result = await UptimerEditPage.route.go(
      context,
      args: UptimerEditArgs(config: config, card: monitor),
    );
    if (result == UptimerEditResult.saved &&
        context.mounted &&
        ref.read(uptimerProvider).monitors.containsKey(_monitorId)) {
      unawaited(ref.read(uptimerDetailProvider(_monitorId).notifier).refresh());
    }
  }
}

/// Hosts the responsive 1/2-column layout and preserves [UptimerUptimeCard]'s
/// inspected heartbeat across wide/narrow breakpoint transitions.
final class _UptimerDetailBody extends StatefulWidget {
  final UptimerMonitorCard monitor;
  final UptimerMonitorConfig? config;
  final UptimerDetailState detail;
  final bool busy;
  final bool bare;
  final FlightAnchorBinding? stripAnchor;
  final bool hideStrip;
  final List<UptimerIncident> incidents;
  final List<UptimerMaintenanceWindow> activeMaint;
  final List<UptimerMaintenanceWindow> upcomingMaint;
  final Future<void> Function() onRefresh;
  final ValueChanged<UptimerRange> onRangeSelected;
  final VoidCallback onTest;
  final VoidCallback onTogglePause;
  final VoidCallback onRotatePushToken;
  final VoidCallback onLoadMoreOutages;

  const _UptimerDetailBody({
    required this.monitor,
    required this.config,
    required this.detail,
    required this.busy,
    required this.bare,
    required this.stripAnchor,
    required this.hideStrip,
    required this.incidents,
    required this.activeMaint,
    required this.upcomingMaint,
    required this.onRefresh,
    required this.onRangeSelected,
    required this.onTest,
    required this.onTogglePause,
    required this.onRotatePushToken,
    required this.onLoadMoreOutages,
  });

  @override
  State<_UptimerDetailBody> createState() => _UptimerDetailBodyState();
}

final class _UptimerDetailBodyState extends State<_UptimerDetailBody> {
  final _uptimeKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    void retry() => unawaited(widget.onRefresh());

    final statusCard = UptimerStatusCard(
      monitor: widget.monitor,
      config: widget.config,
      detail: widget.detail,
      busy: widget.busy,
      incidents: widget.incidents,
      activeMaint: widget.activeMaint,
      upcomingMaint: widget.upcomingMaint,
      onTest: widget.onTest,
      onTogglePause: widget.onTogglePause,
      onRotatePushToken: widget.onRotatePushToken,
    );
    final uptimeCard = UptimerUptimeCard(
      key: _uptimeKey,
      monitor: widget.monitor,
      detail: widget.detail,
      bare: widget.bare,
      stripAnchor: widget.stripAnchor,
      hideStrip: widget.hideStrip,
      onRangeSelected: widget.onRangeSelected,
      onRetry: retry,
    );
    final outagesCard = UptimerOutagesCard(
      detail: widget.detail,
      onRetry: retry,
      onLoadMore: widget.onLoadMoreOutages,
    );
    final configSlot = ServerDetailSwap(
      child: widget.config == null
          ? const SizedBox.shrink(key: ValueKey('no_config'))
          : Padding(
              key: const ValueKey('config'),
              padding: const EdgeInsets.only(top: 13),
              child: UptimerConfigCard(cfg: widget.config!),
            ),
    );
    final showLatency = UptimerLatencyCard.shouldShow(
      widget.monitor,
      widget.detail,
    );

    return LayoutBuilder(
      builder: (context, cons) {
        // Mirror `ServerDetailPage`'s two-column layout (`ServerCardSizes`):
        // wide primary charts & history on the left, compact status + config
        // aside column on the right.
        final wide = cons.maxWidth >= ServerCardSizes.columnsWidth;
        final latencyCard = showLatency
            ? UptimerLatencyCard(
                monitor: widget.monitor,
                detail: widget.detail,
                chartHeight: wide ? 196 : 150,
                onRetry: retry,
              )
            : null;

        final Widget content;
        if (wide) {
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    uptimeCard,
                    if (latencyCard != null) ...[UIs.height13, latencyCard],
                    UIs.height13,
                    outagesCard,
                  ],
                ),
              ),
              const SizedBox(width: ServerCardSizes.asideGap),
              SizedBox(
                width: ServerCardSizes.aside,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [statusCard, configSlot],
                ),
              ),
            ],
          );
        } else {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              statusCard,
              UIs.height13,
              uptimeCard,
              if (latencyCard != null) ...[UIs.height13, latencyCard],
              UIs.height13,
              outagesCard,
              configSlot,
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              ServerCardSizes.pageSide,
              13,
              ServerCardSizes.pageSide,
              28 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: wide
                        ? ServerCardSizes.contentMax
                        : ServerCardSizes.readingsMax,
                  ),
                  child: content,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
