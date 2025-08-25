// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'systemd.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$systemdNotifierHash() => r'60f49a690ff01b5703376aeff90101dee9fe10db';

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

abstract class _$SystemdNotifier
    extends BuildlessAutoDisposeNotifier<SystemdState> {
  late final Spi spi;

  SystemdState build(Spi spi);
}

/// See also [SystemdNotifier].
@ProviderFor(SystemdNotifier)
const systemdNotifierProvider = SystemdNotifierFamily();

/// See also [SystemdNotifier].
class SystemdNotifierFamily extends Family<SystemdState> {
  /// See also [SystemdNotifier].
  const SystemdNotifierFamily();

  /// See also [SystemdNotifier].
  SystemdNotifierProvider call(Spi spi) {
    return SystemdNotifierProvider(spi);
  }

  @override
  SystemdNotifierProvider getProviderOverride(
    covariant SystemdNotifierProvider provider,
  ) {
    return call(provider.spi);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'systemdNotifierProvider';
}

/// See also [SystemdNotifier].
class SystemdNotifierProvider
    extends AutoDisposeNotifierProviderImpl<SystemdNotifier, SystemdState> {
  /// See also [SystemdNotifier].
  SystemdNotifierProvider(Spi spi)
    : this._internal(
        () => SystemdNotifier()..spi = spi,
        from: systemdNotifierProvider,
        name: r'systemdNotifierProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$systemdNotifierHash,
        dependencies: SystemdNotifierFamily._dependencies,
        allTransitiveDependencies:
            SystemdNotifierFamily._allTransitiveDependencies,
        spi: spi,
      );

  SystemdNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.spi,
  }) : super.internal();

  final Spi spi;

  @override
  SystemdState runNotifierBuild(covariant SystemdNotifier notifier) {
    return notifier.build(spi);
  }

  @override
  Override overrideWith(SystemdNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: SystemdNotifierProvider._internal(
        () => create()..spi = spi,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        spi: spi,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<SystemdNotifier, SystemdState>
  createElement() {
    return _SystemdNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SystemdNotifierProvider && other.spi == spi;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, spi.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SystemdNotifierRef on AutoDisposeNotifierProviderRef<SystemdState> {
  /// The parameter `spi` of this provider.
  Spi get spi;
}

class _SystemdNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<SystemdNotifier, SystemdState>
    with SystemdNotifierRef {
  _SystemdNotifierProviderElement(super.provider);

  @override
  Spi get spi => (origin as SystemdNotifierProvider).spi;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
