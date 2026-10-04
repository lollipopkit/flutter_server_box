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

/// `sbm_virt::libvirt::VirtHwCpu`.
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
    String? cache,
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

/// One definition of a domain's hardware (`sbm_virt::libvirt::VirtHwConfig`).
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
    @Default(false) bool efi,
    @Default(false) bool secureBoot,
    String? machine,
    LibvirtHwGraphics? graphics,
    String? video,
    LibvirtHwTpm? tpm,
    @Default(<LibvirtHwHostdev>[]) List<LibvirtHwHostdev> hostdevs,

    /// The domain's own cloud-init seed, as the app named it when it made
    /// the domain.
    String? seed,
  }) = _LibvirtHwConfig;

  factory LibvirtHwConfig.fromJson(Map<String, dynamic> json) =>
      _$LibvirtHwConfigFromJson(json);
}

@freezed
abstract class LibvirtHwGraphics with _$LibvirtHwGraphics {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtHwGraphics({
    @Default('') String kind,
    String? listen,
    int? port,
  }) = _LibvirtHwGraphics;

  factory LibvirtHwGraphics.fromJson(Map<String, dynamic> json) =>
      _$LibvirtHwGraphicsFromJson(json);
}

@freezed
abstract class LibvirtHwTpm with _$LibvirtHwTpm {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtHwTpm({
    @Default('') String model,
    @Default('') String backend,
    String? version,
  }) = _LibvirtHwTpm;

  factory LibvirtHwTpm.fromJson(Map<String, dynamic> json) =>
      _$LibvirtHwTpmFromJson(json);
}

@freezed
abstract class LibvirtHwHostdev with _$LibvirtHwHostdev {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtHwHostdev({
    required String key,
    @Default('') String kind,
    String? vendor,
    String? product,
    String? address,
  }) = _LibvirtHwHostdev;

  factory LibvirtHwHostdev.fromJson(Map<String, dynamic> json) =>
      _$LibvirtHwHostdevFromJson(json);
}

/// `sbm_virt::libvirt::VirtHwCaps`: what the host offers this domain.
@freezed
abstract class LibvirtHwCaps with _$LibvirtHwCaps {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtHwCaps({
    @Default(false) bool efi,
    @Default(false) bool secureBoot,
    @Default(false) bool tpmEmulator,
    @Default(<String>[]) List<String> graphics,
    @Default(<String>[]) List<String> video,
    @Default(<String>[]) List<String> diskBuses,
    @Default(false) bool hostdev,
  }) = _LibvirtHwCaps;

  factory LibvirtHwCaps.fromJson(Map<String, dynamic> json) =>
      _$LibvirtHwCapsFromJson(json);
}

/// One of QEMU's firmware descriptors (`/usr/share/qemu/firmware/*.json`):
/// what libvirt's `firmware='efi'` autoselection can pick.
@freezed
abstract class LibvirtFirmware with _$LibvirtFirmware {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtFirmware({
    required String name,
    @Default(false) bool secureBoot,

    /// Carries the vendor's keys, which a domain with Secure Boot on needs.
    @Default(false) bool enrolledKeys,
  }) = _LibvirtFirmware;

  factory LibvirtFirmware.fromJson(Map<String, dynamic> json) =>
      _$LibvirtFirmwareFromJson(json);
}

/// `sbm_virt::libvirt::VirtHostDevices`.
@freezed
abstract class LibvirtHostDevices with _$LibvirtHostDevices {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtHostDevices({
    @Default(<LibvirtHostUsb>[]) List<LibvirtHostUsb> usb,
    @Default(<LibvirtHostPci>[]) List<LibvirtHostPci> pci,
    @Default(false) bool iommu,
  }) = _LibvirtHostDevices;

  factory LibvirtHostDevices.fromJson(Map<String, dynamic> json) =>
      _$LibvirtHostDevicesFromJson(json);
}

@freezed
abstract class LibvirtHostUsb with _$LibvirtHostUsb {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtHostUsb({
    required String vendor,
    required String product,
    String? vendorName,
    String? productName,

    /// Where it sits, for an address-based hostdev: the bus and the device
    /// number on it.
    int? bus,
    int? device,

    /// The port chain (`4`, or `1.2` behind a hub), for the label.
    String? port,
  }) = _LibvirtHostUsb;

  factory LibvirtHostUsb.fromJson(Map<String, dynamic> json) =>
      _$LibvirtHostUsbFromJson(json);
}

@freezed
abstract class LibvirtHostPci with _$LibvirtHostPci {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtHostPci({
    required String address,
    String? vendor,
    String? product,
    String? vendorName,
    String? productName,
    @JsonKey(name: 'class') String? pciClass,
    int? iommuGroup,
    @Default(0) int groupSize,
  }) = _LibvirtHostPci;

  factory LibvirtHostPci.fromJson(Map<String, dynamic> json) =>
      _$LibvirtHostPciFromJson(json);
}

/// `sbm_virt::libvirt::VirtHardwareInfo`.
@freezed
abstract class LibvirtHardwareInfo with _$LibvirtHardwareInfo {
  const LibvirtHardwareInfo._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LibvirtHardwareInfo({
    required LibvirtHwConfig config,
    LibvirtHwConfig? live,

    /// The persistent definition with its secrets (`--security-info`): what
    /// a change is made from and compared against. Never shown.
    required String configXml,

    /// [configXml] with its secrets redacted: what the view shows.
    @Default('') String configText,

    /// `dumpxml` (the running definition) as read; empty while the domain
    /// is not running. What a revert to the running definition is made
    /// from.
    @Default('') String liveXml,
    @Default(false) bool autostart,
    String? description,
    int? hostCpus,
    int? hostMemoryKib,
    LibvirtHwCaps? caps,

    /// QEMU's firmware descriptors: what the host can boot with, and which
    /// carry Secure Boot's enrolled keys.
    @Default(<LibvirtFirmware>[]) List<LibvirtFirmware> firmware,
  }) = _LibvirtHardwareInfo;

  /// Without the definitions, whose secrets [configXml] and [liveXml] carry:
  /// this reaches logs through string interpolation.
  @override
  String toString() =>
      'LibvirtHardwareInfo(autostart: $autostart, running: ${liveXml.isNotEmpty})';

  factory LibvirtHardwareInfo.fromJson(Map<String, dynamic> json) =>
      _$LibvirtHardwareInfoFromJson(json);
}
