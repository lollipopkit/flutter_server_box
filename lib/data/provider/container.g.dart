// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'container.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$containerNotifierHash() => r'db8f8a6b6071b7b33fbf79128dfed408a5b9fdad';

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

abstract class _$ContainerNotifier
    extends BuildlessAutoDisposeNotifier<ContainerState> {
  late final SSHClient? client;
  late final String userName;
  late final String hostId;
  late final BuildContext context;

  ContainerState build(
    SSHClient? client,
    String userName,
    String hostId,
    BuildContext context,
  );
}

/// See also [ContainerNotifier].
@ProviderFor(ContainerNotifier)
const containerNotifierProvider = ContainerNotifierFamily();

/// See also [ContainerNotifier].
class ContainerNotifierFamily extends Family<ContainerState> {
  /// See also [ContainerNotifier].
  const ContainerNotifierFamily();

  /// See also [ContainerNotifier].
  ContainerNotifierProvider call(
    SSHClient? client,
    String userName,
    String hostId,
    BuildContext context,
  ) {
    return ContainerNotifierProvider(client, userName, hostId, context);
  }

  @override
  ContainerNotifierProvider getProviderOverride(
    covariant ContainerNotifierProvider provider,
  ) {
    return call(
      provider.client,
      provider.userName,
      provider.hostId,
      provider.context,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'containerNotifierProvider';
}

/// See also [ContainerNotifier].
class ContainerNotifierProvider
    extends AutoDisposeNotifierProviderImpl<ContainerNotifier, ContainerState> {
  /// See also [ContainerNotifier].
  ContainerNotifierProvider(
    SSHClient? client,
    String userName,
    String hostId,
    BuildContext context,
  ) : this._internal(
        () => ContainerNotifier()
          ..client = client
          ..userName = userName
          ..hostId = hostId
          ..context = context,
        from: containerNotifierProvider,
        name: r'containerNotifierProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$containerNotifierHash,
        dependencies: ContainerNotifierFamily._dependencies,
        allTransitiveDependencies:
            ContainerNotifierFamily._allTransitiveDependencies,
        client: client,
        userName: userName,
        hostId: hostId,
        context: context,
      );

  ContainerNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.client,
    required this.userName,
    required this.hostId,
    required this.context,
  }) : super.internal();

  final SSHClient? client;
  final String userName;
  final String hostId;
  final BuildContext context;

  @override
  ContainerState runNotifierBuild(covariant ContainerNotifier notifier) {
    return notifier.build(client, userName, hostId, context);
  }

  @override
  Override overrideWith(ContainerNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ContainerNotifierProvider._internal(
        () => create()
          ..client = client
          ..userName = userName
          ..hostId = hostId
          ..context = context,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        client: client,
        userName: userName,
        hostId: hostId,
        context: context,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<ContainerNotifier, ContainerState>
  createElement() {
    return _ContainerNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ContainerNotifierProvider &&
        other.client == client &&
        other.userName == userName &&
        other.hostId == hostId &&
        other.context == context;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, client.hashCode);
    hash = _SystemHash.combine(hash, userName.hashCode);
    hash = _SystemHash.combine(hash, hostId.hashCode);
    hash = _SystemHash.combine(hash, context.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ContainerNotifierRef on AutoDisposeNotifierProviderRef<ContainerState> {
  /// The parameter `client` of this provider.
  SSHClient? get client;

  /// The parameter `userName` of this provider.
  String get userName;

  /// The parameter `hostId` of this provider.
  String get hostId;

  /// The parameter `context` of this provider.
  BuildContext get context;
}

class _ContainerNotifierProviderElement
    extends
        AutoDisposeNotifierProviderElement<ContainerNotifier, ContainerState>
    with ContainerNotifierRef {
  _ContainerNotifierProviderElement(super.provider);

  @override
  SSHClient? get client => (origin as ContainerNotifierProvider).client;
  @override
  String get userName => (origin as ContainerNotifierProvider).userName;
  @override
  String get hostId => (origin as ContainerNotifierProvider).hostId;
  @override
  BuildContext get context => (origin as ContainerNotifierProvider).context;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
