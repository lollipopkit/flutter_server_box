// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'benchmark.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives one server's benchmark: install, start, poll, finish.
///
/// **The run is detached and this only watches it.** yabs takes ten to twenty
/// minutes, which is longer than a phone keeps a connection, longer than the OS
/// leaves a backgrounded app running, and longer than anyone stares at a
/// screen. So the far side is asked to start the work in its own session and
/// this polls a directory — which means closing the page, locking the phone or
/// losing the network costs nothing, and reopening the page finds the run still
/// going. It also means the transport is not special: everything here is one
/// short command, so it works over SSH and over a monitor agent's `/exec`
/// without either knowing about the other.

@ProviderFor(BenchmarkNotifier)
final benchmarkProvider = BenchmarkNotifierFamily._();

/// Drives one server's benchmark: install, start, poll, finish.
///
/// **The run is detached and this only watches it.** yabs takes ten to twenty
/// minutes, which is longer than a phone keeps a connection, longer than the OS
/// leaves a backgrounded app running, and longer than anyone stares at a
/// screen. So the far side is asked to start the work in its own session and
/// this polls a directory — which means closing the page, locking the phone or
/// losing the network costs nothing, and reopening the page finds the run still
/// going. It also means the transport is not special: everything here is one
/// short command, so it works over SSH and over a monitor agent's `/exec`
/// without either knowing about the other.
final class BenchmarkNotifierProvider
    extends $NotifierProvider<BenchmarkNotifier, BenchmarkState> {
  /// Drives one server's benchmark: install, start, poll, finish.
  ///
  /// **The run is detached and this only watches it.** yabs takes ten to twenty
  /// minutes, which is longer than a phone keeps a connection, longer than the OS
  /// leaves a backgrounded app running, and longer than anyone stares at a
  /// screen. So the far side is asked to start the work in its own session and
  /// this polls a directory — which means closing the page, locking the phone or
  /// losing the network costs nothing, and reopening the page finds the run still
  /// going. It also means the transport is not special: everything here is one
  /// short command, so it works over SSH and over a monitor agent's `/exec`
  /// without either knowing about the other.
  BenchmarkNotifierProvider._({
    required BenchmarkNotifierFamily super.from,
    required Spi super.argument,
  }) : super(
         retry: null,
         name: r'benchmarkProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$benchmarkNotifierHash();

  @override
  String toString() {
    return r'benchmarkProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BenchmarkNotifier create() => BenchmarkNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BenchmarkState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BenchmarkState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BenchmarkNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$benchmarkNotifierHash() => r'ce7940e9697ff8edf5f3759af6653ec6e13deeba';

/// Drives one server's benchmark: install, start, poll, finish.
///
/// **The run is detached and this only watches it.** yabs takes ten to twenty
/// minutes, which is longer than a phone keeps a connection, longer than the OS
/// leaves a backgrounded app running, and longer than anyone stares at a
/// screen. So the far side is asked to start the work in its own session and
/// this polls a directory — which means closing the page, locking the phone or
/// losing the network costs nothing, and reopening the page finds the run still
/// going. It also means the transport is not special: everything here is one
/// short command, so it works over SSH and over a monitor agent's `/exec`
/// without either knowing about the other.

final class BenchmarkNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          BenchmarkNotifier,
          BenchmarkState,
          BenchmarkState,
          BenchmarkState,
          Spi
        > {
  BenchmarkNotifierFamily._()
    : super(
        retry: null,
        name: r'benchmarkProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Drives one server's benchmark: install, start, poll, finish.
  ///
  /// **The run is detached and this only watches it.** yabs takes ten to twenty
  /// minutes, which is longer than a phone keeps a connection, longer than the OS
  /// leaves a backgrounded app running, and longer than anyone stares at a
  /// screen. So the far side is asked to start the work in its own session and
  /// this polls a directory — which means closing the page, locking the phone or
  /// losing the network costs nothing, and reopening the page finds the run still
  /// going. It also means the transport is not special: everything here is one
  /// short command, so it works over SSH and over a monitor agent's `/exec`
  /// without either knowing about the other.

  BenchmarkNotifierProvider call(Spi spi) =>
      BenchmarkNotifierProvider._(argument: spi, from: this);

  @override
  String toString() => r'benchmarkProvider';
}

/// Drives one server's benchmark: install, start, poll, finish.
///
/// **The run is detached and this only watches it.** yabs takes ten to twenty
/// minutes, which is longer than a phone keeps a connection, longer than the OS
/// leaves a backgrounded app running, and longer than anyone stares at a
/// screen. So the far side is asked to start the work in its own session and
/// this polls a directory — which means closing the page, locking the phone or
/// losing the network costs nothing, and reopening the page finds the run still
/// going. It also means the transport is not special: everything here is one
/// short command, so it works over SSH and over a monitor agent's `/exec`
/// without either knowing about the other.

abstract class _$BenchmarkNotifier extends $Notifier<BenchmarkState> {
  late final _$args = ref.$arg as Spi;
  Spi get spi => _$args;

  BenchmarkState build(Spi spi);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BenchmarkState, BenchmarkState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BenchmarkState, BenchmarkState>,
              BenchmarkState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
