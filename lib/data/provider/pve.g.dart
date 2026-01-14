// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pve.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PveNotifier)
const pveProvider = PveNotifierFamily._();

final class PveNotifierProvider
    extends $NotifierProvider<PveNotifier, PveState> {
  const PveNotifierProvider._({
    required PveNotifierFamily super.from,
    required Spi super.argument,
  }) : super(
         retry: null,
         name: r'pveProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pveNotifierHash();

  @override
  String toString() {
    return r'pveProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PveNotifier create() => PveNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PveState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PveState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PveNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pveNotifierHash() => r'1e71faadee074b9c07bee731ef4ae6505e791967';

final class PveNotifierFamily extends $Family
    with $ClassFamilyOverride<PveNotifier, PveState, PveState, PveState, Spi> {
  const PveNotifierFamily._()
    : super(
        retry: null,
        name: r'pveProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PveNotifierProvider call(Spi spiParam) =>
      PveNotifierProvider._(argument: spiParam, from: this);

  @override
  String toString() => r'pveProvider';
}

abstract class _$PveNotifier extends $Notifier<PveState> {
  late final _$args = ref.$arg as Spi;
  Spi get spiParam => _$args;

  PveState build(Spi spiParam);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<PveState, PveState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PveState, PveState>,
              PveState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
