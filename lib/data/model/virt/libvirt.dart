import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';

part 'libvirt.freezed.dart';
part 'libvirt.g.dart';

/// `sbm_virt::libvirt` output as it crosses the FFI: serde JSON with
/// snake_case keys. Raw counters only; `sbm_virt::rates` turns two readings
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

/// `sbm_virt::libvirt::VirtVncConsoleInfo`: a display and its VNC password.
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

/// `sbm_virt::libvirt::snapshot::VirtSnapDiff`.
@freezed
abstract class LibvirtSnapDiff with _$LibvirtSnapDiff {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtSnapDiff({
    @Default('') String group,
    @Default('') String key,
    String? before,
    String? after,
    @Default(false) bool removed,
    @Default(false) bool added,
  }) = _LibvirtSnapDiff;

  factory LibvirtSnapDiff.fromJson(Map<String, dynamic> json) =>
      _$LibvirtSnapDiffFromJson(json);
}

@freezed
abstract class LibvirtVolumeRef with _$LibvirtVolumeRef {
  const factory LibvirtVolumeRef({required String name, String? path}) =
      _LibvirtVolumeRef;

  factory LibvirtVolumeRef.fromJson(Map<String, dynamic> json) =>
      _$LibvirtVolumeRefFromJson(json);
}

/// `sbm_virt::libvirt::VirtPool`.
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

// --- Hardware -----------------------------------------------------------------
