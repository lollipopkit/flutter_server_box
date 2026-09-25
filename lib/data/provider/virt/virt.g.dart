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
/// answers through `ensureExec()`, probed on demand ([probeAll] when the tab
/// first lists servers, [probe] for one), cached for the session, re-probed
/// by [refresh]. A server that is both is shown as PVE and not probed.
///
/// Kept alive: the probe cache is the point, and a probe is a connection to
/// every server.

@ProviderFor(VirtHosts)
final virtHostsProvider = VirtHostsProvider._();

/// Which servers are virtualization hosts.
///
/// PVE: a server with a `server_pve` row — explicit, and followed as it
/// changes ([pveConfigsProvider]). libvirt: `virsh`
/// answers through `ensureExec()`, probed on demand ([probeAll] when the tab
/// first lists servers, [probe] for one), cached for the session, re-probed
/// by [refresh]. A server that is both is shown as PVE and not probed.
///
/// Kept alive: the probe cache is the point, and a probe is a connection to
/// every server.
final class VirtHostsProvider
    extends $NotifierProvider<VirtHosts, VirtHostsState> {
  /// Which servers are virtualization hosts.
  ///
  /// PVE: a server with a `server_pve` row — explicit, and followed as it
  /// changes ([pveConfigsProvider]). libvirt: `virsh`
  /// answers through `ensureExec()`, probed on demand ([probeAll] when the tab
  /// first lists servers, [probe] for one), cached for the session, re-probed
  /// by [refresh]. A server that is both is shown as PVE and not probed.
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

String _$virtHostsHash() => r'8aee523c1699bedd724f9c0f1aaddf4d5b51c6bd';

/// Which servers are virtualization hosts.
///
/// PVE: a server with a `server_pve` row — explicit, and followed as it
/// changes ([pveConfigsProvider]). libvirt: `virsh`
/// answers through `ensureExec()`, probed on demand ([probeAll] when the tab
/// first lists servers, [probe] for one), cached for the session, re-probed
/// by [refresh]. A server that is both is shown as PVE and not probed.
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

String _$virtHostNotifierHash() => r'7d565dbedbfa866e3a4df4ac1de5d40b436ab564';

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
