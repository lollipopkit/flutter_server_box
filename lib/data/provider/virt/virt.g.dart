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

String _$virtHostNotifierHash() => r'dee24ea0b747838e7d6e341affe459020f7c9e73';

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

/// A count the host's notifier moves on after it changed what one of the
/// providers below read — [storage], [network], or one guest's hardware
/// (`hw:<guest id>`) — which they watch and so read again.
///
/// The notifier cannot invalidate them itself: they watch it (for its
/// backend), and Riverpod refuses a provider invalidating one that depends
/// on it as a cycle (`CircularDependencyError`, in debug builds).

@ProviderFor(VirtRevision)
final virtRevisionProvider = VirtRevisionFamily._();

/// A count the host's notifier moves on after it changed what one of the
/// providers below read — [storage], [network], or one guest's hardware
/// (`hw:<guest id>`) — which they watch and so read again.
///
/// The notifier cannot invalidate them itself: they watch it (for its
/// backend), and Riverpod refuses a provider invalidating one that depends
/// on it as a cycle (`CircularDependencyError`, in debug builds).
final class VirtRevisionProvider extends $NotifierProvider<VirtRevision, int> {
  /// A count the host's notifier moves on after it changed what one of the
  /// providers below read — [storage], [network], or one guest's hardware
  /// (`hw:<guest id>`) — which they watch and so read again.
  ///
  /// The notifier cannot invalidate them itself: they watch it (for its
  /// backend), and Riverpod refuses a provider invalidating one that depends
  /// on it as a cycle (`CircularDependencyError`, in debug builds).
  VirtRevisionProvider._({
    required VirtRevisionFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'virtRevisionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$virtRevisionHash();

  @override
  String toString() {
    return r'virtRevisionProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  VirtRevision create() => VirtRevision();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is VirtRevisionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$virtRevisionHash() => r'8f90a5988ff932a9c1aeb2165ccb9255bf6c50d0';

/// A count the host's notifier moves on after it changed what one of the
/// providers below read — [storage], [network], or one guest's hardware
/// (`hw:<guest id>`) — which they watch and so read again.
///
/// The notifier cannot invalidate them itself: they watch it (for its
/// backend), and Riverpod refuses a provider invalidating one that depends
/// on it as a cycle (`CircularDependencyError`, in debug builds).

final class VirtRevisionFamily extends $Family
    with $ClassFamilyOverride<VirtRevision, int, int, int, (String, String)> {
  VirtRevisionFamily._()
    : super(
        retry: null,
        name: r'virtRevisionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A count the host's notifier moves on after it changed what one of the
  /// providers below read — [storage], [network], or one guest's hardware
  /// (`hw:<guest id>`) — which they watch and so read again.
  ///
  /// The notifier cannot invalidate them itself: they watch it (for its
  /// backend), and Riverpod refuses a provider invalidating one that depends
  /// on it as a cycle (`CircularDependencyError`, in debug builds).

  VirtRevisionProvider call(String serverId, String what) =>
      VirtRevisionProvider._(argument: (serverId, what), from: this);

  @override
  String toString() => r'virtRevisionProvider';
}

/// A count the host's notifier moves on after it changed what one of the
/// providers below read — [storage], [network], or one guest's hardware
/// (`hw:<guest id>`) — which they watch and so read again.
///
/// The notifier cannot invalidate them itself: they watch it (for its
/// backend), and Riverpod refuses a provider invalidating one that depends
/// on it as a cycle (`CircularDependencyError`, in debug builds).

abstract class _$VirtRevision extends $Notifier<int> {
  late final _$args = ref.$arg as (String, String);
  String get serverId => _$args.$1;
  String get what => _$args.$2;

  int build(String serverId, String what);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}

/// The host's scheduled backup jobs (PVE `/cluster/backup`), for the
/// datacenter's Backup view. Read again through [VirtRevision.backupJobs]
/// after each change.

@ProviderFor(virtBackupJobs)
final virtBackupJobsProvider = VirtBackupJobsFamily._();

/// The host's scheduled backup jobs (PVE `/cluster/backup`), for the
/// datacenter's Backup view. Read again through [VirtRevision.backupJobs]
/// after each change.

final class VirtBackupJobsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VirtBackupJob>>,
          List<VirtBackupJob>,
          FutureOr<List<VirtBackupJob>>
        >
    with
        $FutureModifier<List<VirtBackupJob>>,
        $FutureProvider<List<VirtBackupJob>> {
  /// The host's scheduled backup jobs (PVE `/cluster/backup`), for the
  /// datacenter's Backup view. Read again through [VirtRevision.backupJobs]
  /// after each change.
  VirtBackupJobsProvider._({
    required VirtBackupJobsFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'virtBackupJobsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$virtBackupJobsHash();

  @override
  String toString() {
    return r'virtBackupJobsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<VirtBackupJob>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VirtBackupJob>> create(Ref ref) {
    final argument = this.argument as String;
    return virtBackupJobs(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VirtBackupJobsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$virtBackupJobsHash() => r'1e5340847da6415c14f17d5287daa528fc997e73';

/// The host's scheduled backup jobs (PVE `/cluster/backup`), for the
/// datacenter's Backup view. Read again through [VirtRevision.backupJobs]
/// after each change.

final class VirtBackupJobsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<VirtBackupJob>>, String> {
  VirtBackupJobsFamily._()
    : super(
        retry: _noRetry,
        name: r'virtBackupJobsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The host's scheduled backup jobs (PVE `/cluster/backup`), for the
  /// datacenter's Backup view. Read again through [VirtRevision.backupJobs]
  /// after each change.

  VirtBackupJobsProvider call(String serverId) =>
      VirtBackupJobsProvider._(argument: serverId, from: this);

  @override
  String toString() => r'virtBackupJobsProvider';
}

/// Every storage the host has that holds backups, across its online nodes:
/// where a scheduled job's backups go, and where a restore can put the disks.
/// Each pool carries its node (`VirtStoragePool.node`).

@ProviderFor(virtBackupStorages)
final virtBackupStoragesProvider = VirtBackupStoragesFamily._();

/// Every storage the host has that holds backups, across its online nodes:
/// where a scheduled job's backups go, and where a restore can put the disks.
/// Each pool carries its node (`VirtStoragePool.node`).

final class VirtBackupStoragesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VirtStoragePool>>,
          List<VirtStoragePool>,
          FutureOr<List<VirtStoragePool>>
        >
    with
        $FutureModifier<List<VirtStoragePool>>,
        $FutureProvider<List<VirtStoragePool>> {
  /// Every storage the host has that holds backups, across its online nodes:
  /// where a scheduled job's backups go, and where a restore can put the disks.
  /// Each pool carries its node (`VirtStoragePool.node`).
  VirtBackupStoragesProvider._({
    required VirtBackupStoragesFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'virtBackupStoragesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$virtBackupStoragesHash();

  @override
  String toString() {
    return r'virtBackupStoragesProvider'
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
    return virtBackupStorages(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VirtBackupStoragesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$virtBackupStoragesHash() =>
    r'4b2c66097871e35a62fff23648256d5cb9bc50fc';

/// Every storage the host has that holds backups, across its online nodes:
/// where a scheduled job's backups go, and where a restore can put the disks.
/// Each pool carries its node (`VirtStoragePool.node`).

final class VirtBackupStoragesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<VirtStoragePool>>, String> {
  VirtBackupStoragesFamily._()
    : super(
        retry: _noRetry,
        name: r'virtBackupStoragesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Every storage the host has that holds backups, across its online nodes:
  /// where a scheduled job's backups go, and where a restore can put the disks.
  /// Each pool carries its node (`VirtStoragePool.node`).

  VirtBackupStoragesProvider call(String serverId) =>
      VirtBackupStoragesProvider._(argument: serverId, from: this);

  @override
  String toString() => r'virtBackupStoragesProvider';
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

/// The disk chain of one guest: its own provider rather than part of the
/// snapshot listing, which is one round trip of its own. Invalidated by the
/// view after a snapshot operation, as the listing is.

@ProviderFor(virtSnapChain)
final virtSnapChainProvider = VirtSnapChainFamily._();

/// The disk chain of one guest: its own provider rather than part of the
/// snapshot listing, which is one round trip of its own. Invalidated by the
/// view after a snapshot operation, as the listing is.

final class VirtSnapChainProvider
    extends
        $FunctionalProvider<
          AsyncValue<VirtSnapChain>,
          VirtSnapChain,
          FutureOr<VirtSnapChain>
        >
    with $FutureModifier<VirtSnapChain>, $FutureProvider<VirtSnapChain> {
  /// The disk chain of one guest: its own provider rather than part of the
  /// snapshot listing, which is one round trip of its own. Invalidated by the
  /// view after a snapshot operation, as the listing is.
  VirtSnapChainProvider._({
    required VirtSnapChainFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: _noRetry,
         name: r'virtSnapChainProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$virtSnapChainHash();

  @override
  String toString() {
    return r'virtSnapChainProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<VirtSnapChain> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<VirtSnapChain> create(Ref ref) {
    final argument = this.argument as (String, String);
    return virtSnapChain(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is VirtSnapChainProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$virtSnapChainHash() => r'c86e7fbddb198ae32ff72e6c45a028db60c1be91';

/// The disk chain of one guest: its own provider rather than part of the
/// snapshot listing, which is one round trip of its own. Invalidated by the
/// view after a snapshot operation, as the listing is.

final class VirtSnapChainFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<VirtSnapChain>, (String, String)> {
  VirtSnapChainFamily._()
    : super(
        retry: _noRetry,
        name: r'virtSnapChainProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The disk chain of one guest: its own provider rather than part of the
  /// snapshot listing, which is one round trip of its own. Invalidated by the
  /// view after a snapshot operation, as the listing is.

  VirtSnapChainProvider call(String serverId, String guestId) =>
      VirtSnapChainProvider._(argument: (serverId, guestId), from: this);

  @override
  String toString() => r'virtSnapChainProvider';
}

/// Whether a snapshot of one guest can be taken, and why not: read before the
/// form offers one, so a storage that does not support snapshots is said
/// before the task is started. Null where the host does not answer.

@ProviderFor(virtSnapshotRefusal)
final virtSnapshotRefusalProvider = VirtSnapshotRefusalFamily._();

/// Whether a snapshot of one guest can be taken, and why not: read before the
/// form offers one, so a storage that does not support snapshots is said
/// before the task is started. Null where the host does not answer.

final class VirtSnapshotRefusalProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// Whether a snapshot of one guest can be taken, and why not: read before the
  /// form offers one, so a storage that does not support snapshots is said
  /// before the task is started. Null where the host does not answer.
  VirtSnapshotRefusalProvider._({
    required VirtSnapshotRefusalFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: _noRetry,
         name: r'virtSnapshotRefusalProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$virtSnapshotRefusalHash();

  @override
  String toString() {
    return r'virtSnapshotRefusalProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as (String, String);
    return virtSnapshotRefusal(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is VirtSnapshotRefusalProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$virtSnapshotRefusalHash() =>
    r'82052fcb1d7ca16cda17f05f0ff14f18ff5148e7';

/// Whether a snapshot of one guest can be taken, and why not: read before the
/// form offers one, so a storage that does not support snapshots is said
/// before the task is started. Null where the host does not answer.

final class VirtSnapshotRefusalFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, (String, String)> {
  VirtSnapshotRefusalFamily._()
    : super(
        retry: _noRetry,
        name: r'virtSnapshotRefusalProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether a snapshot of one guest can be taken, and why not: read before the
  /// form offers one, so a storage that does not support snapshots is said
  /// before the task is started. Null where the host does not answer.

  VirtSnapshotRefusalProvider call(String serverId, String guestId) =>
      VirtSnapshotRefusalProvider._(argument: (serverId, guestId), from: this);

  @override
  String toString() => r'virtSnapshotRefusalProvider';
}

/// The hardware of one guest. Invalidated by the view after each change, by
/// [VirtHostNotifier.power] and by snapshot operations.
///
/// Disposed with its last listener, as the host is: kept alive, it would keep
/// the host it watches alive with it — its refresh timer and its session —
/// long after the Virtualization pages had gone. The guest view watches it
/// while it is open (its pending banner included), so it is read once per
/// visit to a guest.

@ProviderFor(virtHardware)
final virtHardwareProvider = VirtHardwareFamily._();

/// The hardware of one guest. Invalidated by the view after each change, by
/// [VirtHostNotifier.power] and by snapshot operations.
///
/// Disposed with its last listener, as the host is: kept alive, it would keep
/// the host it watches alive with it — its refresh timer and its session —
/// long after the Virtualization pages had gone. The guest view watches it
/// while it is open (its pending banner included), so it is read once per
/// visit to a guest.

final class VirtHardwareProvider
    extends
        $FunctionalProvider<
          AsyncValue<VirtHardware>,
          VirtHardware,
          FutureOr<VirtHardware>
        >
    with $FutureModifier<VirtHardware>, $FutureProvider<VirtHardware> {
  /// The hardware of one guest. Invalidated by the view after each change, by
  /// [VirtHostNotifier.power] and by snapshot operations.
  ///
  /// Disposed with its last listener, as the host is: kept alive, it would keep
  /// the host it watches alive with it — its refresh timer and its session —
  /// long after the Virtualization pages had gone. The guest view watches it
  /// while it is open (its pending banner included), so it is read once per
  /// visit to a guest.
  VirtHardwareProvider._({
    required VirtHardwareFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: _noRetry,
         name: r'virtHardwareProvider',
         isAutoDispose: true,
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

String _$virtHardwareHash() => r'b948966c9fce4ce24351eeab6ed29b7f24c0ae52';

/// The hardware of one guest. Invalidated by the view after each change, by
/// [VirtHostNotifier.power] and by snapshot operations.
///
/// Disposed with its last listener, as the host is: kept alive, it would keep
/// the host it watches alive with it — its refresh timer and its session —
/// long after the Virtualization pages had gone. The guest view watches it
/// while it is open (its pending banner included), so it is read once per
/// visit to a guest.

final class VirtHardwareFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<VirtHardware>, (String, String)> {
  VirtHardwareFamily._()
    : super(
        retry: _noRetry,
        name: r'virtHardwareProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The hardware of one guest. Invalidated by the view after each change, by
  /// [VirtHostNotifier.power] and by snapshot operations.
  ///
  /// Disposed with its last listener, as the host is: kept alive, it would keep
  /// the host it watches alive with it — its refresh timer and its session —
  /// long after the Virtualization pages had gone. The guest view watches it
  /// while it is open (its pending banner included), so it is read once per
  /// visit to a guest.

  VirtHardwareProvider call(String serverId, String guestId) =>
      VirtHardwareProvider._(argument: (serverId, guestId), from: this);

  @override
  String toString() => r'virtHardwareProvider';
}

/// The cloud-init settings of one guest with a cloud-init drive. Read again
/// after each change through [VirtHostNotifier.setCloudInit], and by the view
/// after a conflict.

@ProviderFor(virtCloudInit)
final virtCloudInitProvider = VirtCloudInitFamily._();

/// The cloud-init settings of one guest with a cloud-init drive. Read again
/// after each change through [VirtHostNotifier.setCloudInit], and by the view
/// after a conflict.

final class VirtCloudInitProvider
    extends
        $FunctionalProvider<
          AsyncValue<VirtCloudInitState>,
          VirtCloudInitState,
          FutureOr<VirtCloudInitState>
        >
    with
        $FutureModifier<VirtCloudInitState>,
        $FutureProvider<VirtCloudInitState> {
  /// The cloud-init settings of one guest with a cloud-init drive. Read again
  /// after each change through [VirtHostNotifier.setCloudInit], and by the view
  /// after a conflict.
  VirtCloudInitProvider._({
    required VirtCloudInitFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: _noRetry,
         name: r'virtCloudInitProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$virtCloudInitHash();

  @override
  String toString() {
    return r'virtCloudInitProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<VirtCloudInitState> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<VirtCloudInitState> create(Ref ref) {
    final argument = this.argument as (String, String);
    return virtCloudInit(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is VirtCloudInitProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$virtCloudInitHash() => r'f852dc4e146b72b52045bae5b964f55aed87958c';

/// The cloud-init settings of one guest with a cloud-init drive. Read again
/// after each change through [VirtHostNotifier.setCloudInit], and by the view
/// after a conflict.

final class VirtCloudInitFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<VirtCloudInitState>,
          (String, String)
        > {
  VirtCloudInitFamily._()
    : super(
        retry: _noRetry,
        name: r'virtCloudInitProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The cloud-init settings of one guest with a cloud-init drive. Read again
  /// after each change through [VirtHostNotifier.setCloudInit], and by the view
  /// after a conflict.

  VirtCloudInitProvider call(String serverId, String guestId) =>
      VirtCloudInitProvider._(argument: (serverId, guestId), from: this);

  @override
  String toString() => r'virtCloudInitProvider';
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

String _$virtStoragePoolsHash() => r'08630c3a281dc6b49744044ef883e17a029108af';

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

String _$virtNetworksHash() => r'dee54cbd2250ff054ed9e97c39a1f19b3926935d';

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

/// Network configuration waiting to be applied, per node (PVE). Read again
/// with [virtNetworksProvider] after every network change.

@ProviderFor(virtNetworkChanges)
final virtNetworkChangesProvider = VirtNetworkChangesFamily._();

/// Network configuration waiting to be applied, per node (PVE). Read again
/// with [virtNetworksProvider] after every network change.

final class VirtNetworkChangesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VirtNetworkChanges>>,
          List<VirtNetworkChanges>,
          FutureOr<List<VirtNetworkChanges>>
        >
    with
        $FutureModifier<List<VirtNetworkChanges>>,
        $FutureProvider<List<VirtNetworkChanges>> {
  /// Network configuration waiting to be applied, per node (PVE). Read again
  /// with [virtNetworksProvider] after every network change.
  VirtNetworkChangesProvider._({
    required VirtNetworkChangesFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'virtNetworkChangesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$virtNetworkChangesHash();

  @override
  String toString() {
    return r'virtNetworkChangesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<VirtNetworkChanges>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VirtNetworkChanges>> create(Ref ref) {
    final argument = this.argument as String;
    return virtNetworkChanges(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VirtNetworkChangesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$virtNetworkChangesHash() =>
    r'6e99e07dcc03f3b19a117e9a3ab56863e625fcc8';

/// Network configuration waiting to be applied, per node (PVE). Read again
/// with [virtNetworksProvider] after every network change.

final class VirtNetworkChangesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<VirtNetworkChanges>>, String> {
  VirtNetworkChangesFamily._()
    : super(
        retry: _noRetry,
        name: r'virtNetworkChangesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Network configuration waiting to be applied, per node (PVE). Read again
  /// with [virtNetworksProvider] after every network change.

  VirtNetworkChangesProvider call(String serverId) =>
      VirtNetworkChangesProvider._(argument: serverId, from: this);

  @override
  String toString() => r'virtNetworkChangesProvider';
}
