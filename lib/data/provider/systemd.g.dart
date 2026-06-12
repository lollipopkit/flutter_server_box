// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'systemd.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SystemdNotifier)
final systemdProvider = SystemdNotifierFamily._();

final class SystemdNotifierProvider
    extends $NotifierProvider<SystemdNotifier, SystemdState> {
  SystemdNotifierProvider._({
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

String _$systemdNotifierHash() => r'59470f15580fd1e0366e4981e013643fa8f60c11';

final class SystemdNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          SystemdNotifier,
          SystemdState,
          SystemdState,
          SystemdState,
          Spi
        > {
  SystemdNotifierFamily._()
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
    final ref = this.ref as $Ref<SystemdState, SystemdState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SystemdState, SystemdState>,
              SystemdState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
