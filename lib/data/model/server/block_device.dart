import 'package:json_annotation/json_annotation.dart';

part 'block_device.g.dart';

/// One block device as `lsblk` lists it, mounted or not (#1829): mirrors
/// `sbm_parser::types::BlockDevice`, which both the SSH status and the monitor
/// agent's `/metrics` send under `block_devices`.
@JsonSerializable(fieldRename: FieldRename.snake)
class BlockDevice {
  /// `sda1`, `nvme0n1`, `pve-root`
  final String name;
  final String path;

  /// `lsblk` TYPE: `disk`, `part`, `lvm`, `crypt`, `raid1`, `rom`, ...
  final String kind;

  /// Whole disks only.
  final String? model;

  /// Bytes
  final int size;

  /// `sata`, `nvme`, `usb`, ...; top-level devices only.
  final String? tran;
  final String? fsType;

  /// `[SWAP]` for an active swap area.
  final String? mount;

  /// Mounted, carrying other devices, or a member of one (an LVM physical
  /// volume, a RAID or LUKS member). `false` is blank or a filesystem nothing
  /// mounts.
  final bool inUse;
  final List<BlockDevice> children;

  const BlockDevice({
    required this.name,
    this.path = '',
    required this.kind,
    this.model,
    this.size = 0,
    this.tran,
    this.fsType,
    this.mount,
    this.inUse = false,
    this.children = const [],
  });

  factory BlockDevice.fromJson(Map<String, dynamic> json) =>
      _$BlockDeviceFromJson(json);

  Map<String, dynamic> toJson() => _$BlockDeviceToJson(this);
}
