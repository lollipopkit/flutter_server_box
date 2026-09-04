// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'services.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ServicesNotifier)
final servicesProvider = ServicesNotifierFamily._();

final class ServicesNotifierProvider
    extends $NotifierProvider<ServicesNotifier, ServicesState> {
  ServicesNotifierProvider._({
    required ServicesNotifierFamily super.from,
    required Spi super.argument,
  }) : super(
         retry: null,
         name: r'servicesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$servicesNotifierHash();

  @override
  String toString() {
    return r'servicesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ServicesNotifier create() => ServicesNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServicesState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServicesState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ServicesNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$servicesNotifierHash() => r'00568bb84686a482c7feef7b816ed92690edf257';

final class ServicesNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ServicesNotifier,
          ServicesState,
          ServicesState,
          ServicesState,
          Spi
        > {
  ServicesNotifierFamily._()
    : super(
        retry: null,
        name: r'servicesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ServicesNotifierProvider call(Spi spi) =>
      ServicesNotifierProvider._(argument: spi, from: this);

  @override
  String toString() => r'servicesProvider';
}

abstract class _$ServicesNotifier extends $Notifier<ServicesState> {
  late final _$args = ref.$arg as Spi;
  Spi get spi => _$args;

  ServicesState build(Spi spi);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ServicesState, ServicesState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ServicesState, ServicesState>,
              ServicesState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
