// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'systemd.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SystemdNotifier)
const systemdProvider = SystemdNotifierFamily._();

final class SystemdNotifierProvider
    extends $NotifierProvider<SystemdNotifier, SystemdState> {
  const SystemdNotifierProvider._({
    required SystemdNotifierFamily super.from,
    required Spi super.argument,
  }) : super(
         retry: null,
         name: r'systemdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$systemdNotifierHash();

  @override
  String toString() {
    return r'systemdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SystemdNotifier create() => SystemdNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SystemdState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SystemdState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SystemdNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$systemdNotifierHash() => r'd8b36c60dff036e98196ad4d084e4b2ae3a65e32';

final class SystemdNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          SystemdNotifier,
          SystemdState,
          SystemdState,
          SystemdState,
          Spi
        > {
  const SystemdNotifierFamily._()
    : super(
        retry: null,
        name: r'systemdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SystemdNotifierProvider call(Spi spi) =>
      SystemdNotifierProvider._(argument: spi, from: this);

  @override
  String toString() => r'systemdProvider';
}

abstract class _$SystemdNotifier extends $Notifier<SystemdState> {
  late final _$args = ref.$arg as Spi;
  Spi get spi => _$args;

  SystemdState build(Spi spi);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<SystemdState, SystemdState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SystemdState, SystemdState>,
              SystemdState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
