import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';

part 'libvirt.freezed.dart';
part 'libvirt.g.dart';

/// `sbm_parser::virt` output as it crosses the FFI: serde JSON with
/// snake_case keys. Raw counters only; `VirtRateTracker` turns two readings
/// into rates.

/// `virsh version`.
@freezed
abstract class LibvirtVersion with _$LibvirtVersion {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtVersion({
    String? libvirt,
    String? hypervisor,
    String? hypervisorVersion,
  }) = _LibvirtVersion;

  factory LibvirtVersion.fromJson(Map<String, dynamic> json) =>
      _$LibvirtVersionFromJson(json);
}

/// What the host probe found on a server (`VirtHostProbe`).
@freezed
abstract class VirtHostProbeResult with _$VirtHostProbeResult {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory VirtHostProbeResult({
    /// `pveversion`'s line on a Proxmox VE host; nothing else was asked.
    String? pve,

    /// The container the server runs in (`lxc`, `docker`, …).
    String? container,

    /// `virsh version`, when `virsh` is installed and answered.
    LibvirtVersion? libvirt,
  }) = _VirtHostProbeResult;

  factory VirtHostProbeResult.fromJson(Map<String, dynamic> json) =>
      _$VirtHostProbeResultFromJson(json);
}

@freezed
abstract class LibvirtBlockStats with _$LibvirtBlockStats {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtBlockStats({
    @Default('') String name,
    String? path,
    int? rdBytes,
    int? wrBytes,
    int? capacity,
    int? allocation,
  }) = _LibvirtBlockStats;

  factory LibvirtBlockStats.fromJson(Map<String, dynamic> json) =>
      _$LibvirtBlockStatsFromJson(json);
}

@freezed
abstract class LibvirtNetStats with _$LibvirtNetStats {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtNetStats({
    @Default('') String name,
    int? rxBytes,
    int? txBytes,
  }) = _LibvirtNetStats;

  factory LibvirtNetStats.fromJson(Map<String, dynamic> json) =>
      _$LibvirtNetStatsFromJson(json);
}

/// Cumulative counters from `domstats`; absent for an inactive domain.
@freezed
abstract class LibvirtCounters with _$LibvirtCounters {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtCounters({
    /// Nanoseconds.
    int? cpuTimeNs,

    /// KiB.
    int? balloonRssKib,
    int? balloonAvailableKib,
    int? balloonUnusedKib,
    @Default(<LibvirtBlockStats>[]) List<LibvirtBlockStats> blocks,
    @Default(<LibvirtNetStats>[]) List<LibvirtNetStats> nets,
  }) = _LibvirtCounters;

  factory LibvirtCounters.fromJson(Map<String, dynamic> json) =>
      _$LibvirtCountersFromJson(json);
}

/// One domain of the overview.
@freezed
abstract class LibvirtDomain with _$LibvirtDomain {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtDomain({
    required String uuid,
    required String name,

    /// `sbm_parser::virt::VirtState`: `running`, `paused`, `stopped`,
    /// `starting`, `stopping`, `unknown`.
    required String state,

    /// Raw `virDomainState`; -1 when `domstats` did not report the domain.
    @Default(-1) int stateCode,
    @Default(0) int reasonCode,
    @Default('unknown') String reason,
    @Default(false) bool autostart,
    @Default(false) bool persistent,
    int? vcpuCurrent,
    int? vcpuMax,
    int? memCurrentKib,
    int? memMaxKib,
    @Default(LibvirtCounters()) LibvirtCounters counters,
  }) = _LibvirtDomain;

  factory LibvirtDomain.fromJson(Map<String, dynamic> json) =>
      _$LibvirtDomainFromJson(json);
}

@freezed
abstract class LibvirtOverview with _$LibvirtOverview {
  const factory LibvirtOverview({
    LibvirtVersion? version,
    @Default(<LibvirtDomain>[]) List<LibvirtDomain> domains,
  }) = _LibvirtOverview;

  factory LibvirtOverview.fromJson(Map<String, dynamic> json) =>
      _$LibvirtOverviewFromJson(json);
}

/// The part of `dumpxml` the app reads.
@freezed
abstract class LibvirtDomainXml with _$LibvirtDomainXml {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtDomainXml({
    String? name,
    String? uuid,
    String? description,
    String? arch,
    String? machine,
    @Default(<VirtDisk>[]) List<VirtDisk> disks,
    @Default(<VirtNic>[]) List<VirtNic> nics,
    @Default(<VirtGraphics>[]) List<VirtGraphics> graphics,
    @Default(false) bool hasSerialConsole,
  }) = _LibvirtDomainXml;

  factory LibvirtDomainXml.fromJson(Map<String, dynamic> json) =>
      _$LibvirtDomainXmlFromJson(json);
}

@freezed
abstract class LibvirtDomainDetail with _$LibvirtDomainDetail {
  const factory LibvirtDomainDetail({
    VirtDisplay? display,
    @Default(LibvirtDomainXml()) LibvirtDomainXml xml,
  }) = _LibvirtDomainDetail;

  factory LibvirtDomainDetail.fromJson(Map<String, dynamic> json) =>
      _$LibvirtDomainDetailFromJson(json);
}

/// `sbm_parser::virt::VirtVncConsoleInfo`: a display and its VNC password.
///
/// Not freezed: a generated `toString` would print the password.
final class LibvirtVncConsoleInfo {
  const LibvirtVncConsoleInfo({
    this.display,
    this.password,
    this.passwordKnown = false,
  });

  factory LibvirtVncConsoleInfo.fromJson(Map<String, dynamic> json) =>
      LibvirtVncConsoleInfo(
        display: switch (json['display']) {
          final Map<String, dynamic> d => VirtDisplay.fromJson(d),
          _ => null,
        },
        password: json['password'] as String?,
        passwordKnown: json['password_known'] as bool? ?? false,
      );

  final VirtDisplay? display;

  /// Kept in memory for one connection, then gone. Never logged.
  final String? password;

  /// Whether the password could be read at all; false leaves the VNC server
  /// to say whether it wants one.
  final bool passwordKnown;

  @override
  String toString() =>
      'LibvirtVncConsoleInfo($display, password: '
      '${password == null ? 'none' : '[redacted]'}, known: $passwordKnown)';
}

/// `sbm_parser::virt::VirtSnapshotInfo`.
@freezed
abstract class LibvirtSnapshot with _$LibvirtSnapshot {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtSnapshot({
    required String name,
    String? description,
    String? parent,

    /// `running`, `paused`, `shutoff`, `disk-snapshot`.
    String? state,

    /// Seconds since the epoch.
    int? creationTime,
    @Default(false) bool memory,
    @Default(false) bool external,
    @Default(false) bool current,
  }) = _LibvirtSnapshot;

  factory LibvirtSnapshot.fromJson(Map<String, dynamic> json) =>
      _$LibvirtSnapshotFromJson(json);
}

@freezed
abstract class LibvirtVolumeRef with _$LibvirtVolumeRef {
  const factory LibvirtVolumeRef({required String name, String? path}) =
      _LibvirtVolumeRef;

  factory LibvirtVolumeRef.fromJson(Map<String, dynamic> json) =>
      _$LibvirtVolumeRefFromJson(json);
}

/// `sbm_parser::virt::VirtPool`.
@freezed
abstract class LibvirtPool with _$LibvirtPool {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtPool({
    required String name,
    String? uuid,
    String? poolType,
    @Default(false) bool active,
    @Default(false) bool autostart,
    int? capacity,
    int? allocation,
    int? available,
    String? target,
    String? source,

    /// Null when they could not be listed (an inactive pool).
    List<LibvirtVolumeRef>? volumes,
  }) = _LibvirtPool;

  factory LibvirtPool.fromJson(Map<String, dynamic> json) =>
      _$LibvirtPoolFromJson(json);
}

/// One disk of one domain (`domblklist --details`).
@freezed
abstract class LibvirtDiskUse with _$LibvirtDiskUse {
  const factory LibvirtDiskUse({
    required String domain,
    @Default('') String kind,
    @Default('') String device,
    @Default('') String target,
    String? source,
  }) = _LibvirtDiskUse;

  factory LibvirtDiskUse.fromJson(Map<String, dynamic> json) =>
      _$LibvirtDiskUseFromJson(json);
}

@freezed
abstract class LibvirtStorage with _$LibvirtStorage {
  const factory LibvirtStorage({
    @Default(<LibvirtPool>[]) List<LibvirtPool> pools,
    @Default(<LibvirtDiskUse>[]) List<LibvirtDiskUse> disks,
  }) = _LibvirtStorage;

  factory LibvirtStorage.fromJson(Map<String, dynamic> json) =>
      _$LibvirtStorageFromJson(json);
}

/// `sbm_parser::virt::VirtVolume`.
@freezed
abstract class LibvirtVolume with _$LibvirtVolume {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtVolume({
    required String name,
    String? volType,
    String? path,
    String? format,
    int? capacity,
    int? allocation,
    String? backing,
  }) = _LibvirtVolume;

  factory LibvirtVolume.fromJson(Map<String, dynamic> json) =>
      _$LibvirtVolumeFromJson(json);
}

@freezed
abstract class LibvirtNetIp with _$LibvirtNetIp {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtNetIp({
    @Default('ipv4') String family,
    required String cidr,
    @Default(<String>[]) List<String> dhcpRanges,
  }) = _LibvirtNetIp;

  factory LibvirtNetIp.fromJson(Map<String, dynamic> json) =>
      _$LibvirtNetIpFromJson(json);
}

/// `sbm_parser::virt::VirtNetworkInfo`.
@freezed
abstract class LibvirtNetwork with _$LibvirtNetwork {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtNetwork({
    required String name,
    String? uuid,
    @Default(false) bool active,
    @Default(false) bool autostart,
    @Default('isolated') String mode,
    String? bridge,
    @Default(<String>[]) List<String> forwardDevs,
    @Default(<LibvirtNetIp>[]) List<LibvirtNetIp> ips,
    int? connections,
  }) = _LibvirtNetwork;

  factory LibvirtNetwork.fromJson(Map<String, dynamic> json) =>
      _$LibvirtNetworkFromJson(json);
}

/// One interface of one domain (`domiflist`).
@freezed
abstract class LibvirtIfaceUse with _$LibvirtIfaceUse {
  const factory LibvirtIfaceUse({
    required String domain,
    String? interface,
    @Default('') String kind,
    String? source,
    String? model,
    String? mac,
  }) = _LibvirtIfaceUse;

  factory LibvirtIfaceUse.fromJson(Map<String, dynamic> json) =>
      _$LibvirtIfaceUseFromJson(json);
}

@freezed
abstract class LibvirtLease with _$LibvirtLease {
  const factory LibvirtLease({
    required String network,
    required String mac,
    required String ip,
    String? hostname,
  }) = _LibvirtLease;

  factory LibvirtLease.fromJson(Map<String, dynamic> json) =>
      _$LibvirtLeaseFromJson(json);
}

@freezed
abstract class LibvirtNetworks with _$LibvirtNetworks {
  const factory LibvirtNetworks({
    @Default(<LibvirtNetwork>[]) List<LibvirtNetwork> networks,
    @Default(<LibvirtIfaceUse>[]) List<LibvirtIfaceUse> ifaces,
    @Default(<LibvirtLease>[]) List<LibvirtLease> leases,
  }) = _LibvirtNetworks;

  factory LibvirtNetworks.fromJson(Map<String, dynamic> json) =>
      _$LibvirtNetworksFromJson(json);
}

// --- Hardware -----------------------------------------------------------------

/// `sbm_parser::virt::VirtHwCpu`.
@freezed
abstract class LibvirtHwCpu with _$LibvirtHwCpu {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtHwCpu({
    required int sockets,
    @Default(1) int dies,
    @Default(1) int clusters,
    required int cores,
    @Default(1) int threads,
    required int max,
    required int current,
    @Default(false) bool topology,
  }) = _LibvirtHwCpu;

  factory LibvirtHwCpu.fromJson(Map<String, dynamic> json) =>
      _$LibvirtHwCpuFromJson(json);
}

@freezed
abstract class LibvirtHwDisk with _$LibvirtHwDisk {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtHwDisk({
    required String target,
    @Default('disk') String device,
    String? bus,
    String? sourceType,
    String? source,
    String? format,
    @Default(false) bool readonly,
    int? capacity,
    int? bootOrder,
  }) = _LibvirtHwDisk;

  factory LibvirtHwDisk.fromJson(Map<String, dynamic> json) =>
      _$LibvirtHwDiskFromJson(json);
}

@freezed
abstract class LibvirtHwNic with _$LibvirtHwNic {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtHwNic({
    required String mac,
    @Default('') String kind,
    String? source,
    String? model,
    @Default(true) bool linkUp,
    int? bootOrder,
  }) = _LibvirtHwNic;

  factory LibvirtHwNic.fromJson(Map<String, dynamic> json) =>
      _$LibvirtHwNicFromJson(json);
}

/// One definition of a domain's hardware (`sbm_parser::virt::VirtHwConfig`).
@freezed
abstract class LibvirtHwConfig with _$LibvirtHwConfig {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtHwConfig({
    required LibvirtHwCpu cpu,
    required int memoryKib,
    required int currentMemoryKib,
    @Default(<LibvirtHwDisk>[]) List<LibvirtHwDisk> disks,
    @Default(<LibvirtHwNic>[]) List<LibvirtHwNic> nics,
    @Default(<String>[]) List<String> boot,
    @Default(false) bool balloon,
  }) = _LibvirtHwConfig;

  factory LibvirtHwConfig.fromJson(Map<String, dynamic> json) =>
      _$LibvirtHwConfigFromJson(json);
}

/// `sbm_parser::virt::VirtHardwareInfo`.
@freezed
abstract class LibvirtHardwareInfo with _$LibvirtHardwareInfo {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtHardwareInfo({
    required LibvirtHwConfig config,
    LibvirtHwConfig? live,
    required String configXml,
    @Default(false) bool autostart,
    String? description,
    int? hostCpus,
    int? hostMemoryKib,
  }) = _LibvirtHardwareInfo;

  factory LibvirtHardwareInfo.fromJson(Map<String, dynamic> json) =>
      _$LibvirtHardwareInfoFromJson(json);
}
