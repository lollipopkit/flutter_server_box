// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pve.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pveNotifierHash() => r'd1d7fbbb4e25c256e3f2ba6756d3d177c8351580';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$PveNotifier extends BuildlessAutoDisposeNotifier<PveState> {
  late final Spi spiParam;

  PveState build(Spi spiParam);
}

/// See also [PveNotifier].
@ProviderFor(PveNotifier)
const pveNotifierProvider = PveNotifierFamily();

/// See also [PveNotifier].
class PveNotifierFamily extends Family<PveState> {
  /// See also [PveNotifier].
  const PveNotifierFamily();

  /// See also [PveNotifier].
  PveNotifierProvider call(Spi spiParam) {
    return PveNotifierProvider(spiParam);
  }

  @override
  PveNotifierProvider getProviderOverride(
    covariant PveNotifierProvider provider,
  ) {
    return call(provider.spiParam);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'pveNotifierProvider';
}

/// See also [PveNotifier].
class PveNotifierProvider
    extends AutoDisposeNotifierProviderImpl<PveNotifier, PveState> {
  /// See also [PveNotifier].
  PveNotifierProvider(Spi spiParam)
    : this._internal(
        () => PveNotifier()..spiParam = spiParam,
        from: pveNotifierProvider,
        name: r'pveNotifierProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$pveNotifierHash,
        dependencies: PveNotifierFamily._dependencies,
        allTransitiveDependencies: PveNotifierFamily._allTransitiveDependencies,
        spiParam: spiParam,
      );

  PveNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.spiParam,
  }) : super.internal();

  final Spi spiParam;

  @override
  PveState runNotifierBuild(covariant PveNotifier notifier) {
    return notifier.build(spiParam);
  }

  @override
  Override overrideWith(PveNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: PveNotifierProvider._internal(
        () => create()..spiParam = spiParam,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        spiParam: spiParam,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<PveNotifier, PveState> createElement() {
    return _PveNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PveNotifierProvider && other.spiParam == spiParam;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, spiParam.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PveNotifierRef on AutoDisposeNotifierProviderRef<PveState> {
  /// The parameter `spiParam` of this provider.
  Spi get spiParam;
}

class _PveNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<PveNotifier, PveState>
    with PveNotifierRef {
  _PveNotifierProviderElement(super.provider);

  @override
  Spi get spiParam => (origin as PveNotifierProvider).spiParam;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
