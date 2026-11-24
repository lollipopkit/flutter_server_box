import 'package:flutter/foundation.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';

/// Immutable snapshot managed by `uptimerProvider`.
@immutable
final class UptimerState {
  /// Signed-in LK Cloud user id, or null when disabled / signed out.
  final String? userId;
  final bool isLoading;
  final bool hasLoaded;
  final Object? error;
  final UptimerPageData? page;
  final Map<int, UptimerMonitorCard> monitors;
  final Map<int, UptimerMonitorConfig> configs;
  final UptimerAccountQuota? quota;
  final Set<int> busyIds;
  final List<String> sortedGroupNames;

  const UptimerState({
    this.userId,
    this.isLoading = false,
    this.hasLoaded = false,
    this.error,
    this.page,
    this.monitors = const {},
    this.configs = const {},
    this.quota,
    this.busyIds = const {},
    this.sortedGroupNames = const [],
  });

  bool get signedIn => userId != null;

  List<UptimerMonitorCard> get monitorList =>
      monitors.values.toList(growable: false);

  Set<String> get tags => sortedGroupNames.toSet();

  List<UptimerIncident> incidentsFor(int monitorId) =>
      page?.incidentsFor(monitorId) ?? const [];

  List<UptimerMaintenanceWindow> activeMaintenanceFor(int monitorId) =>
      page?.activeMaintenanceFor(monitorId) ?? const [];

  List<UptimerMaintenanceWindow> upcomingMaintenanceFor(int monitorId) =>
      page?.upcomingMaintenanceFor(monitorId) ?? const [];

  bool hasAlert(int monitorId) {
    final m = monitors[monitorId];
    if (m?.status == UptimerMonitorStatus.down) return true;
    return incidentsFor(monitorId).isNotEmpty;
  }

  /// Whether `UptimerCard` renders an alert/maintenance banner for [monitorId].
  bool hasBanner(int monitorId) =>
      incidentsFor(monitorId).isNotEmpty ||
      activeMaintenanceFor(monitorId).isNotEmpty;

  static List<String> computeSortedGroups(
    Map<int, UptimerMonitorCard> monitors,
  ) {
    if (monitors.isEmpty) return const [];
    final set = <String>{
      for (final m in monitors.values)
        if (m.groupName case final g? when g.isNotEmpty) g,
    };
    if (set.isEmpty) return const [];
    final list = set.toList()..sort();
    return List.unmodifiable(list);
  }

  UptimerState copyWith({
    Object? userId = _sentinel,
    bool? isLoading,
    bool? hasLoaded,
    Object? error = _sentinel,
    Object? page = _sentinel,
    Map<int, UptimerMonitorCard>? monitors,
    Map<int, UptimerMonitorConfig>? configs,
    Object? quota = _sentinel,
    Set<int>? busyIds,
    List<String>? sortedGroupNames,
  }) => UptimerState(
    userId: identical(userId, _sentinel) ? this.userId : userId as String?,
    isLoading: isLoading ?? this.isLoading,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    error: identical(error, _sentinel) ? this.error : error,
    page: identical(page, _sentinel) ? this.page : page as UptimerPageData?,
    monitors: monitors ?? this.monitors,
    configs: configs ?? this.configs,
    quota: identical(quota, _sentinel)
        ? this.quota
        : quota as UptimerAccountQuota?,
    busyIds: busyIds ?? this.busyIds,
    sortedGroupNames: sortedGroupNames ?? this.sortedGroupNames,
  );
}

const _sentinel = Object();
