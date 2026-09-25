// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'virt.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every server's PVE configuration (`server_pve`), by server id, read again
/// whenever `PveStore.watch` announces a change — the editor saving, a
/// certificate confirmed, a sync or restore landing.
///
/// What the Virtualization providers watch instead of reading the store once:
/// a server that gains a PVE row becomes a PVE host, and one that loses it
/// goes back to being probed for libvirt, without a restart.

@ProviderFor(PveConfigs)
final pveConfigsProvider = PveConfigsProvider._();

/// Every server's PVE configuration (`server_pve`), by server id, read again
/// whenever `PveStore.watch` announces a change — the editor saving, a
/// certificate confirmed, a sync or restore landing.
///
/// What the Virtualization providers watch instead of reading the store once:
/// a server that gains a PVE row becomes a PVE host, and one that loses it
/// goes back to being probed for libvirt, without a restart.
final class PveConfigsProvider
    extends $NotifierProvider<PveConfigs, Map<String, PveConfig>> {
  /// Every server's PVE configuration (`server_pve`), by server id, read again
  /// whenever `PveStore.watch` announces a change — the editor saving, a
  /// certificate confirmed, a sync or restore landing.
  ///
  /// What the Virtualization providers watch instead of reading the store once:
  /// a server that gains a PVE row becomes a PVE host, and one that loses it
  /// goes back to being probed for libvirt, without a restart.
  PveConfigsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pveConfigsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pveConfigsHash();

  @$internal
  @override
  PveConfigs create() => PveConfigs();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, PveConfig> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, PveConfig>>(value),
    );
  }
}

String _$pveConfigsHash() => r'92680e7373a96391eed229eabcdd6a7793a317cc';

/// Every server's PVE configuration (`server_pve`), by server id, read again
/// whenever `PveStore.watch` announces a change — the editor saving, a
/// certificate confirmed, a sync or restore landing.
///
/// What the Virtualization providers watch instead of reading the store once:
/// a server that gains a PVE row becomes a PVE host, and one that loses it
/// goes back to being probed for libvirt, without a restart.

abstract class _$PveConfigs extends $Notifier<Map<String, PveConfig>> {
  Map<String, PveConfig> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<Map<String, PveConfig>, Map<String, PveConfig>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, PveConfig>, Map<String, PveConfig>>,
              Map<String, PveConfig>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Which servers are virtualization hosts.
///
/// PVE: a server with a `server_pve` row — explicit, and followed as it
/// changes ([pveConfigsProvider]). libvirt: `virsh`
/// answers through `ensureExec()`, probed on demand, cached for the session.
/// A server that is both is shown as PVE and not probed. The probe also
/// finds PVE without a row ([VirtProbeStatus.pve]): not a host until its API
/// access is configured, which is what the switcher offers for it.
///
/// **Who is probed without being asked.** A probe is a connection, so the
/// tab's first listing and a pull to refresh probe only the servers the
/// server list is connected to or connecting anyway ([autoProbeable]):
/// `probeAll(onlyConnected: true)`. Everything else is probed only when the
/// user asks — "Check this server" ([probe]) or "Check all" ([refresh]) —
/// which is also what connects a server whose `autoConnect` is off.
///
/// Kept alive: the probe cache is the point, and a probe is a connection to
/// every server.

@ProviderFor(VirtHosts)
final virtHostsProvider = VirtHostsProvider._();

/// Which servers are virtualization hosts.
///
/// PVE: a server with a `server_pve` row — explicit, and followed as it
/// changes ([pveConfigsProvider]). libvirt: `virsh`
/// answers through `ensureExec()`, probed on demand, cached for the session.
/// A server that is both is shown as PVE and not probed. The probe also
/// finds PVE without a row ([VirtProbeStatus.pve]): not a host until its API
/// access is configured, which is what the switcher offers for it.
///
/// **Who is probed without being asked.** A probe is a connection, so the
/// tab's first listing and a pull to refresh probe only the servers the
/// server list is connected to or connecting anyway ([autoProbeable]):
/// `probeAll(onlyConnected: true)`. Everything else is probed only when the
/// user asks — "Check this server" ([probe]) or "Check all" ([refresh]) —
/// which is also what connects a server whose `autoConnect` is off.
///
/// Kept alive: the probe cache is the point, and a probe is a connection to
/// every server.
final class VirtHostsProvider
    extends $NotifierProvider<VirtHosts, VirtHostsState> {
  /// Which servers are virtualization hosts.
  ///
  /// PVE: a server with a `server_pve` row — explicit, and followed as it
  /// changes ([pveConfigsProvider]). libvirt: `virsh`
  /// answers through `ensureExec()`, probed on demand, cached for the session.
  /// A server that is both is shown as PVE and not probed. The probe also
  /// finds PVE without a row ([VirtProbeStatus.pve]): not a host until its API
  /// access is configured, which is what the switcher offers for it.
  ///
  /// **Who is probed without being asked.** A probe is a connection, so the
  /// tab's first listing and a pull to refresh probe only the servers the
  /// server list is connected to or connecting anyway ([autoProbeable]):
  /// `probeAll(onlyConnected: true)`. Everything else is probed only when the
  /// user asks — "Check this server" ([probe]) or "Check all" ([refresh]) —
  /// which is also what connects a server whose `autoConnect` is off.
  ///
  /// Kept alive: the probe cache is the point, and a probe is a connection to
  /// every server.
  VirtHostsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'virtHostsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$virtHostsHash();

  @$internal
  @override
  VirtHosts create() => VirtHosts();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VirtHostsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VirtHostsState>(value),
    );
  }
}

String _$virtHostsHash() => r'de85bd282292f1a8e6e45780750b4d2b70e753bf';

/// Which servers are virtualization hosts.
///
/// PVE: a server with a `server_pve` row — explicit, and followed as it
/// changes ([pveConfigsProvider]). libvirt: `virsh`
/// answers through `ensureExec()`, probed on demand, cached for the session.
/// A server that is both is shown as PVE and not probed. The probe also
/// finds PVE without a row ([VirtProbeStatus.pve]): not a host until its API
/// access is configured, which is what the switcher offers for it.
///
/// **Who is probed without being asked.** A probe is a connection, so the
/// tab's first listing and a pull to refresh probe only the servers the
/// server list is connected to or connecting anyway ([autoProbeable]):
/// `probeAll(onlyConnected: true)`. Everything else is probed only when the
/// user asks — "Check this server" ([probe]) or "Check all" ([refresh]) —
/// which is also what connects a server whose `autoConnect` is off.
///
/// Kept alive: the probe cache is the point, and a probe is a connection to
/// every server.

abstract class _$VirtHosts extends $Notifier<VirtHostsState> {
  VirtHostsState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<VirtHostsState, VirtHostsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VirtHostsState, VirtHostsState>,
              VirtHostsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// One virtualization host: its backend, periodic refresh, actions in flight
/// and the answers the user gives (TOTP, certificate, sudo password).
///
/// Refreshes every `serverStatusRefreshInterval()`, the status page's
/// setting, while something listens; auto-disposed with the page, which ends
/// the backend's session. An automatic refresh does nothing while the last
/// error needs the user ([VirtErr.needsInput]): repeating it would ask the
/// server the same refused question every few seconds.
///
/// **What the UI does with [VirtHostState.error]:**
/// - `needTfa` → ask for the code, [submitTfa].
/// - `certUnconfirmed` / `certChanged` → show [VirtErr.cert] (and
///   [VirtErr.previousFingerprint]), [confirmCert] with its fingerprint if the
///   user accepts.
/// - `sudoPasswordRequired` / `sudoPasswordRejected` → ask for the sudo
///   password, [provideSudoPassword].
/// - anything else → show it; [refresh] retries.

@ProviderFor(VirtHostNotifier)
final virtHostProvider = VirtHostNotifierFamily._();

/// One virtualization host: its backend, periodic refresh, actions in flight
/// and the answers the user gives (TOTP, certificate, sudo password).
///
/// Refreshes every `serverStatusRefreshInterval()`, the status page's
/// setting, while something listens; auto-disposed with the page, which ends
/// the backend's session. An automatic refresh does nothing while the last
/// error needs the user ([VirtErr.needsInput]): repeating it would ask the
/// server the same refused question every few seconds.
///
/// **What the UI does with [VirtHostState.error]:**
/// - `needTfa` → ask for the code, [submitTfa].
/// - `certUnconfirmed` / `certChanged` → show [VirtErr.cert] (and
///   [VirtErr.previousFingerprint]), [confirmCert] with its fingerprint if the
///   user accepts.
/// - `sudoPasswordRequired` / `sudoPasswordRejected` → ask for the sudo
///   password, [provideSudoPassword].
/// - anything else → show it; [refresh] retries.
final class VirtHostNotifierProvider
    extends $NotifierProvider<VirtHostNotifier, VirtHostState> {
  /// One virtualization host: its backend, periodic refresh, actions in flight
  /// and the answers the user gives (TOTP, certificate, sudo password).
  ///
  /// Refreshes every `serverStatusRefreshInterval()`, the status page's
  /// setting, while something listens; auto-disposed with the page, which ends
  /// the backend's session. An automatic refresh does nothing while the last
  /// error needs the user ([VirtErr.needsInput]): repeating it would ask the
  /// server the same refused question every few seconds.
  ///
  /// **What the UI does with [VirtHostState.error]:**
  /// - `needTfa` → ask for the code, [submitTfa].
  /// - `certUnconfirmed` / `certChanged` → show [VirtErr.cert] (and
  ///   [VirtErr.previousFingerprint]), [confirmCert] with its fingerprint if the
  ///   user accepts.
  /// - `sudoPasswordRequired` / `sudoPasswordRejected` → ask for the sudo
  ///   password, [provideSudoPassword].
  /// - anything else → show it; [refresh] retries.
  VirtHostNotifierProvider._({
    required VirtHostNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'virtHostProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$virtHostNotifierHash();

  @override
  String toString() {
    return r'virtHostProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  VirtHostNotifier create() => VirtHostNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VirtHostState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VirtHostState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is VirtHostNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$virtHostNotifierHash() => r'014b972f1aa246f6327f84c750a5553328a24355';

/// One virtualization host: its backend, periodic refresh, actions in flight
/// and the answers the user gives (TOTP, certificate, sudo password).
///
/// Refreshes every `serverStatusRefreshInterval()`, the status page's
/// setting, while something listens; auto-disposed with the page, which ends
/// the backend's session. An automatic refresh does nothing while the last
/// error needs the user ([VirtErr.needsInput]): repeating it would ask the
/// server the same refused question every few seconds.
///
/// **What the UI does with [VirtHostState.error]:**
/// - `needTfa` → ask for the code, [submitTfa].
/// - `certUnconfirmed` / `certChanged` → show [VirtErr.cert] (and
///   [VirtErr.previousFingerprint]), [confirmCert] with its fingerprint if the
///   user accepts.
/// - `sudoPasswordRequired` / `sudoPasswordRejected` → ask for the sudo
///   password, [provideSudoPassword].
/// - anything else → show it; [refresh] retries.

final class VirtHostNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          VirtHostNotifier,
          VirtHostState,
          VirtHostState,
          VirtHostState,
          String
        > {
  VirtHostNotifierFamily._()
    : super(
        retry: null,
        name: r'virtHostProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One virtualization host: its backend, periodic refresh, actions in flight
  /// and the answers the user gives (TOTP, certificate, sudo password).
  ///
  /// Refreshes every `serverStatusRefreshInterval()`, the status page's
  /// setting, while something listens; auto-disposed with the page, which ends
  /// the backend's session. An automatic refresh does nothing while the last
  /// error needs the user ([VirtErr.needsInput]): repeating it would ask the
  /// server the same refused question every few seconds.
  ///
  /// **What the UI does with [VirtHostState.error]:**
  /// - `needTfa` → ask for the code, [submitTfa].
  /// - `certUnconfirmed` / `certChanged` → show [VirtErr.cert] (and
  ///   [VirtErr.previousFingerprint]), [confirmCert] with its fingerprint if the
  ///   user accepts.
  /// - `sudoPasswordRequired` / `sudoPasswordRejected` → ask for the sudo
  ///   password, [provideSudoPassword].
  /// - anything else → show it; [refresh] retries.

  VirtHostNotifierProvider call(String serverId) =>
      VirtHostNotifierProvider._(argument: serverId, from: this);

  @override
  String toString() => r'virtHostProvider';
}

/// One virtualization host: its backend, periodic refresh, actions in flight
/// and the answers the user gives (TOTP, certificate, sudo password).
///
/// Refreshes every `serverStatusRefreshInterval()`, the status page's
/// setting, while something listens; auto-disposed with the page, which ends
/// the backend's session. An automatic refresh does nothing while the last
/// error needs the user ([VirtErr.needsInput]): repeating it would ask the
/// server the same refused question every few seconds.
///
/// **What the UI does with [VirtHostState.error]:**
/// - `needTfa` → ask for the code, [submitTfa].
/// - `certUnconfirmed` / `certChanged` → show [VirtErr.cert] (and
///   [VirtErr.previousFingerprint]), [confirmCert] with its fingerprint if the
///   user accepts.
/// - `sudoPasswordRequired` / `sudoPasswordRejected` → ask for the sudo
///   password, [provideSudoPassword].
/// - anything else → show it; [refresh] retries.

abstract class _$VirtHostNotifier extends $Notifier<VirtHostState> {
  late final _$args = ref.$arg as String;
  String get serverId => _$args;

  VirtHostState build(String serverId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<VirtHostState, VirtHostState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VirtHostState, VirtHostState>,
              VirtHostState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// The snapshots of one guest. Invalidated by the view after each operation.

@ProviderFor(virtSnapshots)
final virtSnapshotsProvider = VirtSnapshotsFamily._();

/// The snapshots of one guest. Invalidated by the view after each operation.

final class VirtSnapshotsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VirtGuestSnapshot>>,
          List<VirtGuestSnapshot>,
          FutureOr<List<VirtGuestSnapshot>>
        >
    with
        $FutureModifier<List<VirtGuestSnapshot>>,
        $FutureProvider<List<VirtGuestSnapshot>> {
  /// The snapshots of one guest. Invalidated by the view after each operation.
  VirtSnapshotsProvider._({
    required VirtSnapshotsFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: _noRetry,
         name: r'virtSnapshotsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$virtSnapshotsHash();

  @override
  String toString() {
    return r'virtSnapshotsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<VirtGuestSnapshot>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VirtGuestSnapshot>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return virtSnapshots(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is VirtSnapshotsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$virtSnapshotsHash() => r'83a2db4c1d51eeb17908fe3be6cbdcfdd740c0e3';

/// The snapshots of one guest. Invalidated by the view after each operation.

final class VirtSnapshotsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<VirtGuestSnapshot>>,
          (String, String)
        > {
  VirtSnapshotsFamily._()
    : super(
        retry: _noRetry,
        name: r'virtSnapshotsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The snapshots of one guest. Invalidated by the view after each operation.

  VirtSnapshotsProvider call(String serverId, String guestId) =>
      VirtSnapshotsProvider._(argument: (serverId, guestId), from: this);

  @override
  String toString() => r'virtSnapshotsProvider';
}

/// The hardware of one guest. Invalidated by the view after each change and
/// by [VirtHostNotifier.power]. Kept once read: the guest view shows the
/// pending banner from it, and reading it again for every guest opened would
/// be a round trip to the host each time.

@ProviderFor(virtHardware)
final virtHardwareProvider = VirtHardwareFamily._();

/// The hardware of one guest. Invalidated by the view after each change and
/// by [VirtHostNotifier.power]. Kept once read: the guest view shows the
/// pending banner from it, and reading it again for every guest opened would
/// be a round trip to the host each time.

final class VirtHardwareProvider
    extends
        $FunctionalProvider<
          AsyncValue<VirtHardware>,
          VirtHardware,
          FutureOr<VirtHardware>
        >
    with $FutureModifier<VirtHardware>, $FutureProvider<VirtHardware> {
  /// The hardware of one guest. Invalidated by the view after each change and
  /// by [VirtHostNotifier.power]. Kept once read: the guest view shows the
  /// pending banner from it, and reading it again for every guest opened would
  /// be a round trip to the host each time.
  VirtHardwareProvider._({
    required VirtHardwareFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: _noRetry,
         name: r'virtHardwareProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$virtHardwareHash();

  @override
  String toString() {
    return r'virtHardwareProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<VirtHardware> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<VirtHardware> create(Ref ref) {
    final argument = this.argument as (String, String);
    return virtHardware(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is VirtHardwareProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$virtHardwareHash() => r'dccc8de29434dde75b4ee6987a273d5303e939b8';

/// The hardware of one guest. Invalidated by the view after each change and
/// by [VirtHostNotifier.power]. Kept once read: the guest view shows the
/// pending banner from it, and reading it again for every guest opened would
/// be a round trip to the host each time.

final class VirtHardwareFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<VirtHardware>, (String, String)> {
  VirtHardwareFamily._()
    : super(
        retry: _noRetry,
        name: r'virtHardwareProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The hardware of one guest. Invalidated by the view after each change and
  /// by [VirtHostNotifier.power]. Kept once read: the guest view shows the
  /// pending banner from it, and reading it again for every guest opened would
  /// be a round trip to the host each time.

  VirtHardwareProvider call(String serverId, String guestId) =>
      VirtHardwareProvider._(argument: (serverId, guestId), from: this);

  @override
  String toString() => r'virtHardwareProvider';
}

/// The host's storage pools.

@ProviderFor(virtStoragePools)
final virtStoragePoolsProvider = VirtStoragePoolsFamily._();

/// The host's storage pools.

final class VirtStoragePoolsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VirtStoragePool>>,
          List<VirtStoragePool>,
          FutureOr<List<VirtStoragePool>>
        >
    with
        $FutureModifier<List<VirtStoragePool>>,
        $FutureProvider<List<VirtStoragePool>> {
  /// The host's storage pools.
  VirtStoragePoolsProvider._({
    required VirtStoragePoolsFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'virtStoragePoolsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$virtStoragePoolsHash();

  @override
  String toString() {
    return r'virtStoragePoolsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<VirtStoragePool>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VirtStoragePool>> create(Ref ref) {
    final argument = this.argument as String;
    return virtStoragePools(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VirtStoragePoolsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$virtStoragePoolsHash() => r'fd7699ce3557d08ce0ec5314f8b38f3401ae06b1';

/// The host's storage pools.

final class VirtStoragePoolsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<VirtStoragePool>>, String> {
  VirtStoragePoolsFamily._()
    : super(
        retry: _noRetry,
        name: r'virtStoragePoolsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The host's storage pools.

  VirtStoragePoolsProvider call(String serverId) =>
      VirtStoragePoolsProvider._(argument: serverId, from: this);

  @override
  String toString() => r'virtStoragePoolsProvider';
}

/// What is in the pool [poolId] of [virtStoragePoolsProvider].

@ProviderFor(virtVolumes)
final virtVolumesProvider = VirtVolumesFamily._();

/// What is in the pool [poolId] of [virtStoragePoolsProvider].

final class VirtVolumesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VirtVolume>>,
          List<VirtVolume>,
          FutureOr<List<VirtVolume>>
        >
    with $FutureModifier<List<VirtVolume>>, $FutureProvider<List<VirtVolume>> {
  /// What is in the pool [poolId] of [virtStoragePoolsProvider].
  VirtVolumesProvider._({
    required VirtVolumesFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: _noRetry,
         name: r'virtVolumesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$virtVolumesHash();

  @override
  String toString() {
    return r'virtVolumesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<VirtVolume>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VirtVolume>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return virtVolumes(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is VirtVolumesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$virtVolumesHash() => r'fabeb3ec209a357ac8af1220d71c5760e5e2985f';

/// What is in the pool [poolId] of [virtStoragePoolsProvider].

final class VirtVolumesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<VirtVolume>>,
          (String, String)
        > {
  VirtVolumesFamily._()
    : super(
        retry: _noRetry,
        name: r'virtVolumesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// What is in the pool [poolId] of [virtStoragePoolsProvider].

  VirtVolumesProvider call(String serverId, String poolId) =>
      VirtVolumesProvider._(argument: (serverId, poolId), from: this);

  @override
  String toString() => r'virtVolumesProvider';
}

/// The host's networks, with the guests on each.

@ProviderFor(virtNetworks)
final virtNetworksProvider = VirtNetworksFamily._();

/// The host's networks, with the guests on each.

final class VirtNetworksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VirtNetwork>>,
          List<VirtNetwork>,
          FutureOr<List<VirtNetwork>>
        >
    with
        $FutureModifier<List<VirtNetwork>>,
        $FutureProvider<List<VirtNetwork>> {
  /// The host's networks, with the guests on each.
  VirtNetworksProvider._({
    required VirtNetworksFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'virtNetworksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$virtNetworksHash();

  @override
  String toString() {
    return r'virtNetworksProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<VirtNetwork>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VirtNetwork>> create(Ref ref) {
    final argument = this.argument as String;
    return virtNetworks(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VirtNetworksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$virtNetworksHash() => r'e667f3a4cdc50391318e31681aaf235fc7f0c97d';

/// The host's networks, with the guests on each.

final class VirtNetworksFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<VirtNetwork>>, String> {
  VirtNetworksFamily._()
    : super(
        retry: _noRetry,
        name: r'virtNetworksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The host's networks, with the guests on each.

  VirtNetworksProvider call(String serverId) =>
      VirtNetworksProvider._(argument: serverId, from: this);

  @override
  String toString() => r'virtNetworksProvider';
}
