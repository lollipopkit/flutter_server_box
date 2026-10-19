// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_overview.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One server's `monitor` agent for the Monitor tab: its firing rules and
/// notifications, polled while something shows them, and the audit log and
/// what is open on it, read when asked. On the server's shared client
/// ([MonitorClientLease]).

@ProviderFor(MonitorOverviewNotifier)
final monitorOverviewProvider = MonitorOverviewNotifierFamily._();

/// One server's `monitor` agent for the Monitor tab: its firing rules and
/// notifications, polled while something shows them, and the audit log and
/// what is open on it, read when asked. On the server's shared client
/// ([MonitorClientLease]).
final class MonitorOverviewNotifierProvider
    extends $NotifierProvider<MonitorOverviewNotifier, MonitorOverviewState> {
  /// One server's `monitor` agent for the Monitor tab: its firing rules and
  /// notifications, polled while something shows them, and the audit log and
  /// what is open on it, read when asked. On the server's shared client
  /// ([MonitorClientLease]).
  MonitorOverviewNotifierProvider._({
    required MonitorOverviewNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'monitorOverviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$monitorOverviewNotifierHash();

  @override
  String toString() {
    return r'monitorOverviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MonitorOverviewNotifier create() => MonitorOverviewNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MonitorOverviewState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MonitorOverviewState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MonitorOverviewNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$monitorOverviewNotifierHash() =>
    r'5981074df87f24fc3898baea9a129c1cc3260297';

/// One server's `monitor` agent for the Monitor tab: its firing rules and
/// notifications, polled while something shows them, and the audit log and
/// what is open on it, read when asked. On the server's shared client
/// ([MonitorClientLease]).

final class MonitorOverviewNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          MonitorOverviewNotifier,
          MonitorOverviewState,
          MonitorOverviewState,
          MonitorOverviewState,
          String
        > {
  MonitorOverviewNotifierFamily._()
    : super(
        retry: null,
        name: r'monitorOverviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One server's `monitor` agent for the Monitor tab: its firing rules and
  /// notifications, polled while something shows them, and the audit log and
  /// what is open on it, read when asked. On the server's shared client
  /// ([MonitorClientLease]).

  MonitorOverviewNotifierProvider call(String serverId) =>
      MonitorOverviewNotifierProvider._(argument: serverId, from: this);

  @override
  String toString() => r'monitorOverviewProvider';
}

/// One server's `monitor` agent for the Monitor tab: its firing rules and
/// notifications, polled while something shows them, and the audit log and
/// what is open on it, read when asked. On the server's shared client
/// ([MonitorClientLease]).

abstract class _$MonitorOverviewNotifier
    extends $Notifier<MonitorOverviewState> {
  late final _$args = ref.$arg as String;
  String get serverId => _$args;

  MonitorOverviewState build(String serverId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MonitorOverviewState, MonitorOverviewState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MonitorOverviewState, MonitorOverviewState>,
              MonitorOverviewState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
