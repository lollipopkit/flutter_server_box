// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'detail.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// On-demand detail data (24h latency series, ranged uptime, outage log, and
/// latest manual test result) for one Uptimer monitor.

@ProviderFor(UptimerDetail)
final uptimerDetailProvider = UptimerDetailFamily._();

/// On-demand detail data (24h latency series, ranged uptime, outage log, and
/// latest manual test result) for one Uptimer monitor.
final class UptimerDetailProvider
    extends $NotifierProvider<UptimerDetail, UptimerDetailState> {
  /// On-demand detail data (24h latency series, ranged uptime, outage log, and
  /// latest manual test result) for one Uptimer monitor.
  UptimerDetailProvider._({
    required UptimerDetailFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'uptimerDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$uptimerDetailHash();

  @override
  String toString() {
    return r'uptimerDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  UptimerDetail create() => UptimerDetail();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UptimerDetailState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UptimerDetailState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is UptimerDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$uptimerDetailHash() => r'83019cf295cce1277420775f8f8d72623499f0c6';

/// On-demand detail data (24h latency series, ranged uptime, outage log, and
/// latest manual test result) for one Uptimer monitor.

final class UptimerDetailFamily extends $Family
    with
        $ClassFamilyOverride<
          UptimerDetail,
          UptimerDetailState,
          UptimerDetailState,
          UptimerDetailState,
          int
        > {
  UptimerDetailFamily._()
    : super(
        retry: null,
        name: r'uptimerDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// On-demand detail data (24h latency series, ranged uptime, outage log, and
  /// latest manual test result) for one Uptimer monitor.

  UptimerDetailProvider call(int monitorId) =>
      UptimerDetailProvider._(argument: monitorId, from: this);

  @override
  String toString() => r'uptimerDetailProvider';
}

/// On-demand detail data (24h latency series, ranged uptime, outage log, and
/// latest manual test result) for one Uptimer monitor.

abstract class _$UptimerDetail extends $Notifier<UptimerDetailState> {
  late final _$args = ref.$arg as int;
  int get monitorId => _$args;

  UptimerDetailState build(int monitorId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UptimerDetailState, UptimerDetailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UptimerDetailState, UptimerDetailState>,
              UptimerDetailState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
