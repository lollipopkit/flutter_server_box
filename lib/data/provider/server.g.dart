// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$individualServerNotifierHash() =>
    r'e3d74fb95ca994cd8419b1deab743e8b3e21bee2';

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

abstract class _$IndividualServerNotifier
    extends BuildlessAutoDisposeNotifier<ServerState> {
  late final String serverId;

  ServerState build(String serverId);
}

/// See also [IndividualServerNotifier].
@ProviderFor(IndividualServerNotifier)
const individualServerNotifierProvider = IndividualServerNotifierFamily();

/// See also [IndividualServerNotifier].
class IndividualServerNotifierFamily extends Family<ServerState> {
  /// See also [IndividualServerNotifier].
  const IndividualServerNotifierFamily();

  /// See also [IndividualServerNotifier].
  IndividualServerNotifierProvider call(String serverId) {
    return IndividualServerNotifierProvider(serverId);
  }

  @override
  IndividualServerNotifierProvider getProviderOverride(
    covariant IndividualServerNotifierProvider provider,
  ) {
    return call(provider.serverId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'individualServerNotifierProvider';
}

/// See also [IndividualServerNotifier].
class IndividualServerNotifierProvider
    extends
        AutoDisposeNotifierProviderImpl<IndividualServerNotifier, ServerState> {
  /// See also [IndividualServerNotifier].
  IndividualServerNotifierProvider(String serverId)
    : this._internal(
        () => IndividualServerNotifier()..serverId = serverId,
        from: individualServerNotifierProvider,
        name: r'individualServerNotifierProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$individualServerNotifierHash,
        dependencies: IndividualServerNotifierFamily._dependencies,
        allTransitiveDependencies:
            IndividualServerNotifierFamily._allTransitiveDependencies,
        serverId: serverId,
      );

  IndividualServerNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.serverId,
  }) : super.internal();

  final String serverId;

  @override
  ServerState runNotifierBuild(covariant IndividualServerNotifier notifier) {
    return notifier.build(serverId);
  }

  @override
  Override overrideWith(IndividualServerNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: IndividualServerNotifierProvider._internal(
        () => create()..serverId = serverId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        serverId: serverId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<IndividualServerNotifier, ServerState>
  createElement() {
    return _IndividualServerNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IndividualServerNotifierProvider &&
        other.serverId == serverId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, serverId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin IndividualServerNotifierRef
    on AutoDisposeNotifierProviderRef<ServerState> {
  /// The parameter `serverId` of this provider.
  String get serverId;
}

class _IndividualServerNotifierProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          IndividualServerNotifier,
          ServerState
        >
    with IndividualServerNotifierRef {
  _IndividualServerNotifierProviderElement(super.provider);

  @override
  String get serverId => (origin as IndividualServerNotifierProvider).serverId;
}

String _$serverNotifierHash() => r'8e2bc3aef3c56263f88df3c2bb1ba88b6cf83c8f';

/// See also [ServerNotifier].
@ProviderFor(ServerNotifier)
final serverNotifierProvider =
    NotifierProvider<ServerNotifier, ServersState>.internal(
      ServerNotifier.new,
      name: r'serverNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$serverNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ServerNotifier = Notifier<ServersState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
