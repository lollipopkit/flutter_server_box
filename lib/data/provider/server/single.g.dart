// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'single.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$serverNotifierHash() => r'5625b0a4762c28efdbc124809c03b84a51d213b1';

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

abstract class _$ServerNotifier
    extends BuildlessAutoDisposeNotifier<ServerState> {
  late final String serverId;

  ServerState build(String serverId);
}

/// See also [ServerNotifier].
@ProviderFor(ServerNotifier)
const serverNotifierProvider = ServerNotifierFamily();

/// See also [ServerNotifier].
class ServerNotifierFamily extends Family<ServerState> {
  /// See also [ServerNotifier].
  const ServerNotifierFamily();

  /// See also [ServerNotifier].
  ServerNotifierProvider call(String serverId) {
    return ServerNotifierProvider(serverId);
  }

  @override
  ServerNotifierProvider getProviderOverride(
    covariant ServerNotifierProvider provider,
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
  String? get name => r'serverNotifierProvider';
}

/// See also [ServerNotifier].
class ServerNotifierProvider
    extends AutoDisposeNotifierProviderImpl<ServerNotifier, ServerState> {
  /// See also [ServerNotifier].
  ServerNotifierProvider(String serverId)
    : this._internal(
        () => ServerNotifier()..serverId = serverId,
        from: serverNotifierProvider,
        name: r'serverNotifierProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$serverNotifierHash,
        dependencies: ServerNotifierFamily._dependencies,
        allTransitiveDependencies:
            ServerNotifierFamily._allTransitiveDependencies,
        serverId: serverId,
      );

  ServerNotifierProvider._internal(
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
  ServerState runNotifierBuild(covariant ServerNotifier notifier) {
    return notifier.build(serverId);
  }

  @override
  Override overrideWith(ServerNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ServerNotifierProvider._internal(
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
  AutoDisposeNotifierProviderElement<ServerNotifier, ServerState>
  createElement() {
    return _ServerNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ServerNotifierProvider && other.serverId == serverId;
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
mixin ServerNotifierRef on AutoDisposeNotifierProviderRef<ServerState> {
  /// The parameter `serverId` of this provider.
  String get serverId;
}

class _ServerNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<ServerNotifier, ServerState>
    with ServerNotifierRef {
  _ServerNotifierProviderElement(super.provider);

  @override
  String get serverId => (origin as ServerNotifierProvider).serverId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
