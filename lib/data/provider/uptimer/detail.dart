import 'dart:async';

import 'package:fl_lib/fl_lib.dart' hide Provider;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/provider/uptimer/client.dart';
import 'package:server_box/data/provider/uptimer/uptimer.dart';

part 'detail.g.dart';

@immutable
final class UptimerDetailState {
  final bool isLoading;
  final Object? error;
  final Object? latencyError;
  final Object? outagesError;
  final UptimerLatencyData? latency;
  final UptimerRange range;
  final Map<UptimerRange, UptimerTotals> uptimeByRange;
  final List<UptimerOutage> outages;
  final int? nextOutageCursor;
  final bool loadingMoreOutages;
  final UptimerTestResult? lastTest;
  final DateTime? lastTestAt;

  const UptimerDetailState({
    this.isLoading = false,
    this.error,
    this.latencyError,
    this.outagesError,
    this.latency,
    this.range = UptimerRange.d30,
    this.uptimeByRange = const {},
    this.outages = const [],
    this.nextOutageCursor,
    this.loadingMoreOutages = false,
    this.lastTest,
    this.lastTestAt,
  });

  UptimerTotals? get currentUptime => uptimeByRange[range];

  UptimerDetailState copyWith({
    bool? isLoading,
    Object? error = _sentinel,
    Object? latencyError = _sentinel,
    Object? outagesError = _sentinel,
    Object? latency = _sentinel,
    UptimerRange? range,
    Map<UptimerRange, UptimerTotals>? uptimeByRange,
    List<UptimerOutage>? outages,
    Object? nextOutageCursor = _sentinel,
    bool? loadingMoreOutages,
    Object? lastTest = _sentinel,
    Object? lastTestAt = _sentinel,
  }) => UptimerDetailState(
    isLoading: isLoading ?? this.isLoading,
    error: identical(error, _sentinel) ? this.error : error,
    latencyError: identical(latencyError, _sentinel)
        ? this.latencyError
        : latencyError,
    outagesError: identical(outagesError, _sentinel)
        ? this.outagesError
        : outagesError,
    latency: identical(latency, _sentinel)
        ? this.latency
        : latency as UptimerLatencyData?,
    range: range ?? this.range,
    uptimeByRange: uptimeByRange ?? this.uptimeByRange,
    outages: outages ?? this.outages,
    nextOutageCursor: identical(nextOutageCursor, _sentinel)
        ? this.nextOutageCursor
        : nextOutageCursor as int?,
    loadingMoreOutages: loadingMoreOutages ?? this.loadingMoreOutages,
    lastTest: identical(lastTest, _sentinel)
        ? this.lastTest
        : lastTest as UptimerTestResult?,
    lastTestAt: identical(lastTestAt, _sentinel)
        ? this.lastTestAt
        : lastTestAt as DateTime?,
  );
}

const _sentinel = Object();

/// On-demand detail data (24h latency series, ranged uptime, outage log, and
/// latest manual test result) for one Uptimer monitor.
@riverpod
class UptimerDetail extends _$UptimerDetail {
  int _loadGen = 0;
  int _rangeGen = 0;
  String? _userId;

  UptimerApi get _api => ref.read(uptimerApiProvider);

  @override
  UptimerDetailState build(int monitorId) {
    final userId = ref.watch(uptimerProvider.select((s) => s.userId));
    _userId = userId;
    _loadGen++;
    _rangeGen++;
    if (userId == null) return const UptimerDetailState();
    Future.microtask(() {
      if (ref.mounted && _userId == userId) unawaited(_loadAll());
    });
    return const UptimerDetailState(isLoading: true);
  }

  Future<(T?, Object?)> _capture<T>(Future<T> Function() run, String label) async {
    try {
      return (await run(), null);
    } catch (e, s) {
      Loggers.app.warning('Uptimer $label failed ($monitorId)', e, s);
      return (null, e);
    }
  }

  Future<void> _loadAll({bool refreshRoot = false}) async {
    if (_userId == null) return;
    final gen = ++_loadGen;
    final rangeGen = ++_rangeGen;
    final range = state.range;
    state = state.copyWith(
      isLoading: true,
      error: null,
      latencyError: null,
      outagesError: null,
    );

    final latencyF = _capture(() => _api.fetchLatency(monitorId), 'latency');
    final uptimeF = _capture(
      () => _api.fetchUptime(monitorId, range),
      'uptime',
    );
    final outagesF = _capture(
      () => _api.fetchOutages(monitorId, range: range),
      'outages',
    );
    final configF = ref.read(uptimerProvider.notifier).ensureConfig(monitorId);
    final rootF = refreshRoot
        ? ref.read(uptimerProvider.notifier).refresh(force: true)
        : Future<void>.value();

    final (latency, latencyErr) = await latencyF;
    final (uptime, uptimeErr) = await uptimeF;
    final (outages, outagesErr) = await outagesF;
    await Future.wait([configF, rootF]);

    if (!ref.mounted || gen != _loadGen) return;

    final nextUptime = uptime == null
        ? state.uptimeByRange
        : Map<UptimerRange, UptimerTotals>.unmodifiable({
            ...state.uptimeByRange,
            range: uptime,
          });
    final sameRange = rangeGen == _rangeGen;
    state = state.copyWith(
      isLoading: sameRange ? false : state.isLoading,
      error: sameRange ? (uptimeErr ?? outagesErr ?? latencyErr) : state.error,
      latencyError: latencyErr,
      outagesError: sameRange ? outagesErr : state.outagesError,
      latency: latency ?? state.latency,
      uptimeByRange: nextUptime,
      outages: sameRange && outages != null ? outages.outages : state.outages,
      nextOutageCursor: sameRange && outages != null
          ? outages.nextCursor
          : state.nextOutageCursor,
    );
  }

  Future<void> refresh() => _loadAll(refreshRoot: true);

  Future<void> setRange(UptimerRange range) async {
    if (_userId == null || state.range == range) return;
    final rangeGen = ++_rangeGen;
    state = state.copyWith(
      range: range,
      isLoading: true,
      error: null,
      outagesError: null,
      outages: const [],
      nextOutageCursor: null,
      loadingMoreOutages: false,
    );

    final uptimeF = _capture(
      () => _api.fetchUptime(monitorId, range),
      'uptime',
    );
    final outagesF = _capture(
      () => _api.fetchOutages(monitorId, range: range),
      'outages',
    );
    final (uptime, uptimeErr) = await uptimeF;
    final (outages, outagesErr) = await outagesF;
    if (!ref.mounted || rangeGen != _rangeGen) return;

    final nextUptime = uptime == null
        ? state.uptimeByRange
        : Map<UptimerRange, UptimerTotals>.unmodifiable({
            ...state.uptimeByRange,
            range: uptime,
          });
    state = state.copyWith(
      isLoading: false,
      error: uptimeErr ?? outagesErr,
      outagesError: outagesErr,
      uptimeByRange: nextUptime,
      outages: outages?.outages ?? const [],
      nextOutageCursor: outages?.nextCursor,
    );
  }

  Future<void> loadMoreOutages() async {
    final cursor = state.nextOutageCursor;
    if (_userId == null || cursor == null || state.loadingMoreOutages) return;
    final rangeGen = _rangeGen;
    final range = state.range;
    state = state.copyWith(loadingMoreOutages: true);
    try {
      final page = await _api.fetchOutages(
        monitorId,
        range: range,
        cursor: cursor,
      );
      if (!ref.mounted || rangeGen != _rangeGen) return;
      state = state.copyWith(
        loadingMoreOutages: false,
        outages: List.unmodifiable([...state.outages, ...page.outages]),
        nextOutageCursor: page.nextCursor,
      );
    } catch (e, s) {
      if (!ref.mounted || rangeGen != _rangeGen) return;
      Loggers.app.warning('Uptimer outages pagination failed ($monitorId)', e, s);
      state = state.copyWith(loadingMoreOutages: false);
      rethrow;
    }
  }

  Future<UptimerTestResult> runTest() async {
    final res = await ref.read(uptimerProvider.notifier).testMonitor(monitorId);
    if (ref.mounted) {
      state = state.copyWith(lastTest: res, lastTestAt: DateTime.now());
    }
    return res;
  }
}
