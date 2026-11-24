import 'dart:async';
import 'dart:collection';

import 'package:fl_lib/fl_lib.dart' hide Provider;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/lkc.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/provider/uptimer/client.dart';
import 'package:server_box/data/provider/uptimer/selection.dart';
import 'package:server_box/data/provider/uptimer/state.dart';

export 'package:server_box/data/provider/uptimer/state.dart';

part 'uptimer.g.dart';

/// Auth source for Uptimer (override in tests to simulate LKC sign-in/out).
typedef UptimerAuthSource = ({bool enabled, ValueListenable<LkcUser?>? user});

final uptimerAuthSourceProvider = Provider<UptimerAuthSource>(
  (_) => (enabled: Lkc.enabled, user: Lkc.enabled ? Lkc.client.user : null),
);

/// Manages the signed-in LK Cloud user's Uptimer monitors, periodic polling,
/// and CRUD mutations.
@Riverpod(keepAlive: true)
class Uptimer extends _$Uptimer {
  static const _pollInterval = Duration(seconds: 60);
  static const _resumeStaleAfter = Duration(seconds: 30);

  late UptimerAuthSource _auth;
  String? _userId;
  int _authGeneration = 0;
  int _refreshSeq = 0;
  int _configsSeq = 0;
  Timer? _pollTimer;
  AppLifecycleListener? _lifecycle;
  bool _resumed = true;
  DateTime? _lastRefreshAt;
  Future<void>? _inFlightRefresh;
  Future<void>? _inFlightConfigs;

  UptimerApi get _api => ref.read(uptimerApiProvider);

  @override
  UptimerState build() {
    _auth = ref.read(uptimerAuthSourceProvider);
    final userListenable = _auth.enabled ? _auth.user : null;
    final initialUser = userListenable?.value;
    _userId = initialUser?.id;

    if (userListenable != null) {
      userListenable.addListener(_onUserChanged);
      _attachLifecycle();
      if (initialUser != null) {
        _startPolling();
        Future.microtask(() {
          if (ref.mounted && state.signedIn) {
            unawaited(refresh());
          }
        });
      }
    }

    ref.onDispose(() {
      userListenable?.removeListener(_onUserChanged);
      _stopPolling();
      _lifecycle?.dispose();
      _lifecycle = null;
    });

    return UptimerState(userId: initialUser?.id);
  }

  void _attachLifecycle() {
    if (_lifecycle != null) return;
    try {
      _lifecycle = AppLifecycleListener(
        onResume: _onAppResume,
        onPause: _onAppPause,
        onHide: _onAppPause,
      );
    } catch (_) {
      // Non-widget test environments may lack a full SchedulerBinding.
    }
  }

  void _onAppPause() {
    _resumed = false;
    _stopPolling();
  }

  void _onAppResume() {
    _resumed = true;
    if (!ref.mounted || !state.signedIn) return;
    _startPolling();
    final last = _lastRefreshAt;
    if (last == null || DateTime.now().difference(last) >= _resumeStaleAfter) {
      unawaited(refresh());
    }
  }

  void _onUserChanged() {
    if (!ref.mounted) return;
    final nextUser = _auth.enabled ? _auth.user?.value : null;
    final nextId = nextUser?.id;
    if (nextId == _userId) return;

    _userId = nextId;
    _authGeneration++;
    _refreshSeq++;
    _configsSeq++;
    _inFlightRefresh = null;
    _inFlightConfigs = null;
    _lastRefreshAt = null;
    _stopPolling();

    if (nextId == null) {
      state = const UptimerState();
      if (ref.read(uptimerSelectionProvider) != null) {
        ref.read(uptimerSelectionProvider.notifier).select(null);
      }
      return;
    }

    state = UptimerState(userId: nextId);
    if (_resumed) _startPolling();
    unawaited(refresh(force: true));
  }

  void _startPolling() {
    _stopPolling();
    if (!_resumed) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!ref.mounted || !state.signedIn || !_resumed) return;
      unawaited(refresh());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Refreshes `/api/v1/me/page`. Deduplicates overlapping calls unless [force].
  Future<void> refresh({bool force = false}) {
    if (!_auth.enabled || !state.signedIn) return Future.value();
    if (!force && _inFlightRefresh != null) return _inFlightRefresh!;
    final gen = _authGeneration;
    final seq = ++_refreshSeq;
    final task = _doRefresh(gen, seq);
    _inFlightRefresh = task;
    task.whenComplete(() {
      if (identical(_inFlightRefresh, task)) _inFlightRefresh = null;
    });
    return task;
  }

  Future<void> _doRefresh(int gen, int seq) async {
    state = state.copyWith(isLoading: true);
    try {
      final page = await _api.fetchPage();
      if (!ref.mounted || gen != _authGeneration || seq != _refreshSeq) return;
      final map = LinkedHashMap<int, UptimerMonitorCard>.fromEntries(
        page.monitors.map((m) => MapEntry(m.id, m)),
      );
      final unmod = UnmodifiableMapView(map);
      _lastRefreshAt = DateTime.now();
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        error: null,
        page: page,
        monitors: unmod,
        sortedGroupNames: UptimerState.computeSortedGroups(unmod),
      );
      final selectedId = ref.read(uptimerSelectionProvider);
      if (selectedId != null && !map.containsKey(selectedId)) {
        ref.read(uptimerSelectionProvider.notifier).select(null);
      }
    } catch (e, s) {
      if (!ref.mounted || gen != _authGeneration || seq != _refreshSeq) return;
      Loggers.app.warning('Uptimer refresh failed', e, s);
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// Loads editable monitor configurations and account quota.
  ///
  /// When [rethrowOnError] is true, failures from `listMonitors` are propagated
  /// so callers such as the editor can refuse to overwrite unknown config.
  Future<void> loadConfigs({bool force = false, bool rethrowOnError = false}) {
    if (!_auth.enabled || !state.signedIn) return Future.value();
    if (!force && state.configs.isNotEmpty && state.quota != null) {
      return Future.value();
    }
    if (!force && !rethrowOnError && _inFlightConfigs != null) {
      return _inFlightConfigs!;
    }
    final gen = _authGeneration;
    final seq = ++_configsSeq;
    final task = _doLoadConfigs(gen, seq, rethrowOnError: rethrowOnError);
    if (!rethrowOnError) {
      _inFlightConfigs = task;
      task.whenComplete(() {
        if (identical(_inFlightConfigs, task)) _inFlightConfigs = null;
      });
    }
    return task;
  }

  Future<void> _doLoadConfigs(
    int gen,
    int seq, {
    required bool rethrowOnError,
  }) async {
    try {
      final listFuture = _api.listMonitors();
      final quotaFuture = _api.fetchAccount().then<UptimerAccountQuota?>(
        (q) => q,
        onError: (Object e, StackTrace s) {
          Loggers.app.warning('Uptimer account quota fetch failed', e, s);
          return null;
        },
      );
      final list = await listFuture;
      final quota = await quotaFuture;
      if (!ref.mounted || gen != _authGeneration || seq != _configsSeq) return;
      final map = LinkedHashMap<int, UptimerMonitorConfig>.fromEntries(
        list.map((m) => MapEntry(m.id, m)),
      );
      state = state.copyWith(
        configs: UnmodifiableMapView(map),
        quota: quota ?? state.quota,
      );
    } catch (e, s) {
      if (!ref.mounted || gen != _authGeneration || seq != _configsSeq) return;
      Loggers.app.warning('Uptimer listMonitors failed', e, s);
      if (rethrowOnError) rethrow;
    }
  }

  Future<UptimerMonitorConfig?> ensureConfig(
    int id, {
    bool rethrowOnError = false,
  }) async {
    final cached = state.configs[id];
    if (cached != null) return cached;
    await loadConfigs(force: true, rethrowOnError: rethrowOnError);
    if (!ref.mounted) return null;
    return state.configs[id];
  }

  void _setBusy(int id, bool busy) {
    final next = Set<int>.from(state.busyIds);
    if (busy) {
      next.add(id);
    } else {
      next.remove(id);
    }
    state = state.copyWith(busyIds: Set.unmodifiable(next));
  }

  Future<UptimerMonitorMutation> createMonitor(
    Map<String, dynamic> body,
  ) async {
    final gen = _authGeneration;
    final mutation = await _api.createMonitor(body);
    if (ref.mounted && gen == _authGeneration) {
      final nextConfigs = LinkedHashMap<int, UptimerMonitorConfig>.of(
        state.configs,
      )..[mutation.monitor.id] = mutation.monitor;
      state = state.copyWith(configs: UnmodifiableMapView(nextConfigs));
      await refresh(force: true);
    }
    return mutation;
  }

  Future<UptimerMonitorConfig> updateMonitor(
    int id,
    Map<String, dynamic> body,
  ) async {
    final gen = _authGeneration;
    _setBusy(id, true);
    try {
      final updated = await _api.updateMonitor(id, body);
      if (ref.mounted && gen == _authGeneration) {
        final nextConfigs = LinkedHashMap<int, UptimerMonitorConfig>.of(
          state.configs,
        )..[id] = updated;
        state = state.copyWith(configs: UnmodifiableMapView(nextConfigs));
        await refresh(force: true);
      }
      return updated;
    } finally {
      if (ref.mounted && gen == _authGeneration) _setBusy(id, false);
    }
  }

  Future<void> deleteMonitor(int id, {bool refreshAfter = true}) async {
    final gen = _authGeneration;
    _setBusy(id, true);
    try {
      await _api.deleteMonitor(id);
      if (!ref.mounted || gen != _authGeneration) return;
      final nextMonitors = LinkedHashMap<int, UptimerMonitorCard>.of(
        state.monitors,
      )..remove(id);
      final unmodMonitors = UnmodifiableMapView(nextMonitors);
      final nextConfigs = LinkedHashMap<int, UptimerMonitorConfig>.of(
        state.configs,
      )..remove(id);
      state = state.copyWith(
        monitors: unmodMonitors,
        configs: UnmodifiableMapView(nextConfigs),
        sortedGroupNames: UptimerState.computeSortedGroups(unmodMonitors),
      );
      if (ref.read(uptimerSelectionProvider) == id) {
        ref.read(uptimerSelectionProvider.notifier).select(null);
      }
      if (refreshAfter) unawaited(refresh(force: true));
    } finally {
      if (ref.mounted && gen == _authGeneration) _setBusy(id, false);
    }
  }

  Future<UptimerTestResult> testMonitor(int id) async {
    final gen = _authGeneration;
    _setBusy(id, true);
    try {
      return await _api.testMonitor(id);
    } finally {
      if (ref.mounted && gen == _authGeneration) _setBusy(id, false);
    }
  }

  Future<UptimerMonitorConfig> pauseMonitor(int id) async {
    final gen = _authGeneration;
    _setBusy(id, true);
    try {
      final updated = await _api.pauseMonitor(id);
      if (ref.mounted && gen == _authGeneration) {
        final nextConfigs = LinkedHashMap<int, UptimerMonitorConfig>.of(
          state.configs,
        )..[id] = updated;
        state = state.copyWith(configs: UnmodifiableMapView(nextConfigs));
        await refresh(force: true);
      }
      return updated;
    } finally {
      if (ref.mounted && gen == _authGeneration) _setBusy(id, false);
    }
  }

  Future<UptimerMonitorConfig> resumeMonitor(int id) async {
    final gen = _authGeneration;
    _setBusy(id, true);
    try {
      var updated = await _api.resumeMonitor(id);
      if (ref.mounted && gen == _authGeneration) {
        final nextConfigs = LinkedHashMap<int, UptimerMonitorConfig>.of(
          state.configs,
        )..[id] = updated;
        state = state.copyWith(configs: UnmodifiableMapView(nextConfigs));
      }
      // `/resume` only resets `monitor_state.status`; if the monitor was
      // deactivated via `is_active: false`, re-enable it so it actually runs.
      if (!updated.isActive) {
        updated = await _api.updateMonitor(id, {'is_active': true});
        if (ref.mounted && gen == _authGeneration) {
          final nextConfigs = LinkedHashMap<int, UptimerMonitorConfig>.of(
            state.configs,
          )..[id] = updated;
          state = state.copyWith(configs: UnmodifiableMapView(nextConfigs));
        }
      }
      if (ref.mounted && gen == _authGeneration) {
        await refresh(force: true);
      }
      return updated;
    } finally {
      if (ref.mounted && gen == _authGeneration) _setBusy(id, false);
    }
  }

  Future<UptimerMonitorMutation> rotatePushToken(int id) async {
    final gen = _authGeneration;
    _setBusy(id, true);
    try {
      final mutation = await _api.rotatePushToken(id);
      if (ref.mounted && gen == _authGeneration) {
        final nextConfigs = LinkedHashMap<int, UptimerMonitorConfig>.of(
          state.configs,
        )..[id] = mutation.monitor;
        state = state.copyWith(configs: UnmodifiableMapView(nextConfigs));
      }
      return mutation;
    } finally {
      if (ref.mounted && gen == _authGeneration) _setBusy(id, false);
    }
  }

  Future<void> assignGroup(List<int> monitorIds, String? groupName) async {
    if (monitorIds.isEmpty) return;
    final gen = _authGeneration;
    await _api.assignGroup(monitorIds, groupName);
    if (ref.mounted && gen == _authGeneration) {
      await Future.wait([refresh(force: true), loadConfigs(force: true)]);
    }
  }
}
