import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';

part 'virt_hardware.freezed.dart';

/// A guest's hardware as the Hardware view edits it.
///
/// **The definition the next start gets**: every value here has its pending
/// changes applied, so an edit starts from what was last saved rather than
/// from what the guest happens to be running with. What the running guest
/// has instead is in [pending] — for PVE, its `pending` listing; for
/// libvirt, the running definition compared with the persistent one
/// (`LibvirtBackend.pendingOf`).
@freezed
abstract class VirtHardware with _$VirtHardware {
  const VirtHardware._();

  const factory VirtHardware({
    required VirtGuestKind kind,

    /// There is a running definition too: a change it cannot take waits for
    /// the next start, and shows in [pending] until then.
    required bool running,
    required VirtHwCpu cpu,
    required VirtHwMemory memory,
    @Default(<VirtHwDisk>[]) List<VirtHwDisk> disks,
    @Default(<VirtHwNic>[]) List<VirtHwNic> nics,

    /// Boot devices in order, by [VirtHwDisk.key] / [VirtHwNic.key]. Null
    /// where there is no order to set (a container).
    List<String>? boot,
    @Default(false) bool autostart,

    /// The guest's name as saved: a VM's `name` or a container's `hostname`
    /// on PVE, the domain's name on libvirt. The Settings view edits it.
    String? name,

    /// The note kept with the guest: PVE's `description`, libvirt's
    /// `<description>`. Null for none.
    String? description,

    /// PVE's `protection`: no deleting the guest or its disks while set.
    /// Null where the host has no such setting (libvirt).
    bool? protection,

    /// Whether the name can change while the guest runs: PVE's can (a
    /// container's waits for a restart, as pending), libvirt's
    /// `domrename` takes only a domain that is not running.
    @Default(true) bool renameRunning,
    @Default(<VirtPendingField>[]) List<VirtPendingField> pending,

    /// What an edit is made from, sent back with it: PVE's `digest`, the
    /// persistent XML libvirt printed. An edit made from an older read is
    /// refused (`VirtErrType.conflict`) rather than undoing someone else's.
    String? revision,
    @Default(VirtHwLimits()) VirtHwLimits limits,

    /// PVE: the CPU models the node offers, for [VirtHwCpu.type].
    @Default(<String>[]) List<String> cpuTypes,

    /// The configuration as the host writes it — `qm config`'s lines, the
    /// persistent XML — for the view to show as it is.
    String? configText,

    /// UEFI or BIOS; null for a container, which has neither.
    VirtHwFirmware? firmware,

    /// The console and video card; null for a container.
    VirtHwDisplay? display,

    /// Host USB and PCI devices given to the guest, and its TPM.
    @Default(<VirtHwDevice>[]) List<VirtHwDevice> devices,

    /// What this guest can be changed to, on this host.
    @Default(VirtHwSupport()) VirtHwSupport support,
  }) = _VirtHardware;

  VirtHwDevice? device(String key) {
    for (final d in devices) {
      if (d.key == key) return d;
    }
    return null;
  }

  bool get hasTpm => devices.any((d) => d.kind == VirtHwDeviceKind.tpm);

  VirtHwDisk? disk(String key) {
    for (final d in disks) {
      if (d.key == key) return d;
    }
    return null;
  }

  VirtHwNic? nic(String key) {
    for (final n in nics) {
      if (n.key == key) return n;
    }
    return null;
  }

  /// Whether a pending change touches [keys] (PVE option names; libvirt's
  /// [VirtPendingField.key]s).
  bool pendingFor(Iterable<String> keys) =>
      pending.any((p) => keys.contains(p.key));
}

@freezed
abstract class VirtHwCpu with _$VirtHwCpu {
  const VirtHwCpu._();

  const factory VirtHwCpu({
    required int sockets,
    required int cores,

    /// libvirt's threads per core, kept as they are; always 1 on PVE.
    @Default(1) int threads,

    /// vCPUs online: PVE's `vcpus`, libvirt's `current`. Null for all of
    /// them.
    int? online,

    /// PVE's CPU model (`cputype`); null where the host decides.
    String? type,
  }) = _VirtHwCpu;

  int get total => sockets * cores * threads;
}

@freezed
abstract class VirtHwMemory with _$VirtHwMemory {
  const factory VirtHwMemory({
    required int mib,

    /// The balloon's floor (PVE `balloon`, 0 turning it off) or target
    /// (libvirt `currentMemory`). Null where there is none to set.
    int? minMib,

    /// There is a balloon device, so [minMib] can be set.
    @Default(false) bool balloon,

    /// A container's swap.
    int? swapMib,
  }) = _VirtHwMemory;
}

enum VirtHwDiskKind {
  disk,
  cdrom,

  /// A container's root filesystem.
  rootfs,

  /// A container's mount point.
  mount,
}

@freezed
abstract class VirtHwDisk with _$VirtHwDisk {
  const factory VirtHwDisk({
    /// PVE option (`scsi0`, `rootfs`, `mp0`), libvirt target (`vda`).
    required String key,
    required VirtHwDiskKind kind,

    /// PVE volume id, libvirt path; null for an empty drive.
    String? source,

    /// Bytes, where known.
    int? size,

    /// PVE storage the volume is on.
    String? storage,

    /// A mount point's path in the container.
    String? mountPoint,
    String? bus,
    String? format,
    @Default(false) bool readonly,

    /// The cache mode; null for the host's default.
    String? cache,
  }) = _VirtHwDisk;
}

@freezed
abstract class VirtHwNic with _$VirtHwNic {
  const factory VirtHwNic({
    /// PVE option (`net0`), libvirt MAC.
    required String key,
    String? mac,

    /// libvirt's interface type (`network`, `bridge`); null on PVE.
    String? type,

    /// Bridge (PVE, libvirt `bridge`) or network (libvirt `network`).
    String? source,
    String? model,
    @Default(true) bool linkUp,

    /// PVE's firewall on this interface; null where there is no such thing.
    bool? firewall,

    /// A container's interface name (`eth0`).
    String? name,
  }) = _VirtHwNic;
}

/// One setting the running guest has differently from its next start.
@freezed
abstract class VirtPendingField with _$VirtPendingField {
  const factory VirtPendingField({
    /// PVE's option name; libvirt: `cpu`, `memory`, `boot`, a disk target
    /// or a NIC's MAC.
    required String key,
    String? current,
    String? pending,

    /// Goes at the next start.
    @Default(false) bool delete,
  }) = _VirtPendingField;
}

@freezed
abstract class VirtHwFirmware with _$VirtHwFirmware {
  const factory VirtHwFirmware({
    required bool uefi,
    @Default(false) bool secureBoot,

    /// PVE: the storage the EFI variables disk is on; null without one.
    String? varsStorage,
  }) = _VirtHwFirmware;
}

@freezed
abstract class VirtHwDisplay with _$VirtHwDisplay {
  const factory VirtHwDisplay({
    /// `vnc`, `spice`; null where the host decides (PVE: VNC through its
    /// own proxy, SPICE with a `qxl` card).
    String? protocol,

    /// The address the console listens on (libvirt); null for the default.
    String? listen,

    /// The video card: libvirt's model, PVE's `vga` type.
    String? gpu,
    int? port,
  }) = _VirtHwDisplay;
}

enum VirtHwDeviceKind { usb, pci, tpm }

/// A host device given to the guest, or its TPM.
@freezed
abstract class VirtHwDevice with _$VirtHwDevice {
  const factory VirtHwDevice({
    /// PVE option (`usb0`, `hostpci0`, `tpmstate0`); libvirt
    /// `usb:0bda:b023`, `pci:0000:01:00.0`, `tpm`.
    required String key,
    required VirtHwDeviceKind kind,

    /// `0bda:b023`, `0000:01:00.0`, a PVE mapping's name, or the TPM's
    /// model and version.
    String? detail,

    /// Given through a PVE resource mapping rather than by address.
    @Default(false) bool mapping,
  }) = _VirtHwDevice;
}

/// What a guest's hardware can be changed to, on its host: the choices the
/// view offers, and none it cannot make.
@freezed
abstract class VirtHwSupport with _$VirtHwSupport {
  const factory VirtHwSupport({
    /// Disk buses; empty: the bus is not changed here.
    @Default(<String>[]) List<String> buses,
    @Default(<String>[]) List<String> caches,
    @Default(<String>[]) List<String> nicModels,

    /// A NIC's MAC can be set.
    @Default(false) bool mac,

    /// Console protocols to choose from; empty where the host has one.
    @Default(<String>[]) List<String> protocols,

    /// The console's listen address can be set (libvirt).
    @Default(false) bool listen,
    @Default(<String>[]) List<String> gpus,
    @Default(false) bool uefi,
    @Default(false) bool secureBoot,
    @Default(false) bool tpm,
    @Default(false) bool usb,
    @Default(false) bool pci,
  }) = _VirtHwSupport;
}

/// A host device a guest can be given.
@freezed
abstract class VirtHostDevice with _$VirtHostDevice {
  const factory VirtHostDevice({
    /// What attaching sends: `0bda:b023`, `0000:01:00.0`, or a PVE
    /// mapping's name.
    required String id,
    required String label,
    String? detail,

    /// A PVE resource mapping rather than a raw device.
    @Default(false) bool mapping,
    int? iommuGroup,

    /// Devices sharing its IOMMU group, itself included: all of them go to
    /// the guest together.
    @Default(0) int groupSize,
  }) = _VirtHostDevice;
}

/// The host devices a guest can be given, and why there may be none.
@freezed
abstract class VirtHostDevices with _$VirtHostDevices {
  const factory VirtHostDevices({
    @Default(<VirtHostDevice>[]) List<VirtHostDevice> usb,
    @Default(<VirtHostDevice>[]) List<VirtHostDevice> pci,

    /// The host has an IOMMU on; false: VT-d/AMD-Vi is off or absent, and
    /// a PCI device given to a guest keeps it from starting.
    @Default(true) bool iommu,

    /// PVE: this login may only use resource mappings (only root@pam gives
    /// a guest a raw device).
    @Default(false) bool mappingsOnly,
  }) = _VirtHostDevices;
}

@freezed
abstract class VirtHwLimits with _$VirtHwLimits {
  const factory VirtHwLimits({int? hostCpus, int? hostMemoryBytes}) =
      _VirtHwLimits;
}

/// One change to a guest's hardware.
sealed class VirtHwChange {
  const VirtHwChange();
}

final class VirtHwSetCpu extends VirtHwChange {
  const VirtHwSetCpu({
    required this.sockets,
    required this.cores,
    this.online,
    this.type,
  });

  final int sockets;
  final int cores;

  /// Null for all of them.
  final int? online;

  /// PVE only; null leaves it as it is.
  final String? type;
}

final class VirtHwSetMemory extends VirtHwChange {
  const VirtHwSetMemory({required this.mib, this.minMib, this.swapMib});

  final int mib;

  /// See [VirtHwMemory.minMib]. Null: none (PVE: the default, the same as
  /// [mib]; libvirt: all of [mib]).
  final int? minMib;
  final int? swapMib;
}

final class VirtHwGrowDisk extends VirtHwChange {
  const VirtHwGrowDisk({required this.key, required this.bytes});

  final String key;

  /// The new size; never less than the disk has.
  final int bytes;
}

final class VirtHwAddDisk extends VirtHwChange {
  const VirtHwAddDisk({
    required this.storage,
    required this.gib,
    this.mountPoint,
  });

  final VirtStoragePool storage;
  final int gib;

  /// A container's mount point: where it appears inside.
  final String? mountPoint;
}

final class VirtHwRemoveDisk extends VirtHwChange {
  const VirtHwRemoveDisk({required this.key, this.deleteVolume = false});

  final String key;

  /// Deletes the volume as well, once nothing uses it.
  final bool deleteVolume;
}

final class VirtHwSetMedia extends VirtHwChange {
  const VirtHwSetMedia({required this.key, this.media});

  final String key;

  /// Null ejects.
  final VirtVolume? media;
}

final class VirtHwAddNic extends VirtHwChange {
  const VirtHwAddNic({required this.network, this.model});

  final VirtNetwork network;

  /// Null for the backend's default (virtio; a container's veth).
  final String? model;
}

final class VirtHwRemoveNic extends VirtHwChange {
  const VirtHwRemoveNic({required this.key});

  final String key;
}

final class VirtHwUpdateNic extends VirtHwChange {
  const VirtHwUpdateNic({
    required this.key,
    this.network,
    required this.linkUp,
    this.firewall,
  });

  final String key;

  /// Null keeps the one it has.
  final VirtNetwork? network;
  final bool linkUp;

  /// PVE only; null keeps it as it is.
  final bool? firewall;
}

final class VirtHwSetBoot extends VirtHwChange {
  const VirtHwSetBoot(this.order);

  final List<String> order;
}

final class VirtHwSetAutostart extends VirtHwChange {
  const VirtHwSetAutostart(this.on);

  final bool on;
}

/// A new name: PVE `name` / `hostname`, libvirt `domrename`.
final class VirtHwSetName extends VirtHwChange {
  const VirtHwSetName(this.name);

  final String name;
}

/// The guest's note; empty clears it.
final class VirtHwSetDescription extends VirtHwChange {
  const VirtHwSetDescription(this.text);

  final String text;
}

/// PVE's `protection`.
final class VirtHwSetProtection extends VirtHwChange {
  const VirtHwSetProtection(this.on);

  final bool on;
}

/// A disk's bus and cache mode; null keeps it. A new bus is a new name on
/// it, and waits for the guest to be stopped.
final class VirtHwUpdateDisk extends VirtHwChange {
  const VirtHwUpdateDisk({required this.key, this.bus, this.cache});

  final String key;
  final String? bus;

  /// `default` for the host's.
  final String? cache;
}

/// A NIC's model and MAC; null keeps it.
final class VirtHwSetNicHardware extends VirtHwChange {
  const VirtHwSetNicHardware({required this.key, this.model, this.mac});

  final String key;
  final String? model;
  final String? mac;
}

/// UEFI (with Secure Boot or without) or BIOS.
final class VirtHwSetFirmware extends VirtHwChange {
  const VirtHwSetFirmware({
    required this.uefi,
    this.secureBoot = false,
    this.storage,
  });

  final bool uefi;
  final bool secureBoot;

  /// PVE: the storage's name (`local-lvm`) a new EFI variables disk goes
  /// on.
  final String? storage;
}

/// The console's protocol and listen address, and the video card; null
/// keeps it.
final class VirtHwSetDisplay extends VirtHwChange {
  const VirtHwSetDisplay({this.protocol, this.listen, this.gpu});

  final String? protocol;
  final String? listen;
  final String? gpu;
}

/// A host device, or a TPM.
final class VirtHwAddDevice extends VirtHwChange {
  const VirtHwAddDevice({required this.kind, this.host, this.storage});

  final VirtHwDeviceKind kind;

  /// The device, for USB and PCI.
  final VirtHostDevice? host;

  /// PVE: the storage's name (`local-lvm`) the TPM's state goes on.
  final String? storage;
}

final class VirtHwRemoveDevice extends VirtHwChange {
  const VirtHwRemoveDevice({required this.key});

  final String key;
}

/// Drops pending changes to [keys] (PVE `revert`).
final class VirtHwRevert extends VirtHwChange {
  const VirtHwRevert(this.keys);

  final List<String> keys;
}

/// What a change came to, beyond succeeding.
final class VirtHwOutcome {
  const VirtHwOutcome({this.liveError, this.volumeKept = false});

  /// The running guest refused its half, in the host's words: the next start
  /// gets the change.
  final String? liveError;

  /// A disk was to be deleted, but the running guest still has it: kept.
  final bool volumeKept;
}

/// Why a change cannot be sent. First wins; see [virtHwIssue].
enum VirtHwIssue {
  /// Fewer than one, or more vCPUs than the host has: it would not start.
  cpuCount,

  /// Online vCPUs outside 1..total.
  cpuOnline,
  memory,

  /// A balloon floor above the memory.
  memoryMin,
  swap,

  /// Smaller than the disk is: disks only grow.
  diskShrink,
  diskSize,

  /// More than the storage has free.
  storageSpace,
  mountPoint,
  bootEmpty,

  /// Not a name the host takes: see [virtPveNamePattern] and
  /// [virtLibvirtNamePattern].
  nameInvalid,

  /// libvirt renames only a guest that is not running.
  nameRunning,

  /// Longer than a note is kept, or with control characters in it.
  description,

  /// Not a unicast MAC address.
  mac,

  /// A disk moves to another bus, or the firmware changes, only while the
  /// guest is stopped.
  stopFirst,

  /// A TPM or an EFI disk needs a storage to go on.
  storageMissing,

  /// No device picked, or a second TPM.
  device,
}

/// A unicast MAC: six octets, the first even, not all zero.
bool virtIsUnicastMac(String mac) {
  if (!RegExp(r'^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$').hasMatch(mac)) {
    return false;
  }
  if (int.parse(mac.substring(0, 2), radix: 16).isOdd) return false;
  return mac.replaceAll(':', '').replaceAll('0', '').isNotEmpty;
}

/// The longest note kept with a guest here: PVE's `description` is capped at
/// 8 KiB, and libvirt's is held to the same.
const virtHwDescriptionMax = 8192;

/// The least memory a guest is given here.
const virtHwMinMemoryMib = 16;

/// A container mount point: absolute, and nothing PVE's option syntax would
/// read as the next option.
final virtMountPointPattern = RegExp(r'^/[^,=\s]*[^,=\s/]$');

/// Why [change] cannot be made to [hw]; null when it can. [host] decides
/// which names are taken; without it a name is checked against both.
VirtHwIssue? virtHwIssue(
  VirtHardware hw,
  VirtHwChange change, {
  VirtHostKind? host,
}) {
  final limits = hw.limits;
  switch (change) {
    case VirtHwSetCpu(:final sockets, :final cores, :final online):
      final total = sockets * cores * hw.cpu.threads;
      if (sockets < 1 || cores < 1) return VirtHwIssue.cpuCount;
      final hostCpus = limits.hostCpus;
      if (total > (hostCpus ?? 4096)) return VirtHwIssue.cpuCount;
      if (online != null && (online < 1 || online > total)) {
        return VirtHwIssue.cpuOnline;
      }
    case VirtHwSetMemory(:final mib, :final minMib, :final swapMib):
      final host = limits.hostMemoryBytes;
      if (mib < virtHwMinMemoryMib ||
          (host != null && mib * (1 << 20) > host)) {
        return VirtHwIssue.memory;
      }
      if (minMib != null && (minMib < 0 || minMib > mib)) {
        return VirtHwIssue.memoryMin;
      }
      if (swapMib != null && swapMib < 0) return VirtHwIssue.swap;
    case VirtHwGrowDisk(:final key, :final bytes):
      final size = hw.disk(key)?.size;
      if (size != null && bytes <= size) return VirtHwIssue.diskShrink;
      if (bytes > 1 << 50) return VirtHwIssue.diskSize;
    case VirtHwAddDisk(:final storage, :final gib, :final mountPoint):
      if (gib < 1 || gib > 65536) return VirtHwIssue.diskSize;
      final available = storage.available;
      if (available != null && gib * (1 << 30) > available) {
        return VirtHwIssue.storageSpace;
      }
      if (hw.kind == VirtGuestKind.lxc &&
          !virtMountPointPattern.hasMatch(mountPoint ?? '')) {
        return VirtHwIssue.mountPoint;
      }
    case VirtHwSetBoot(:final order):
      if (order.isEmpty) return VirtHwIssue.bootEmpty;
    case VirtHwSetName(:final name):
      final ok = switch (host) {
        VirtHostKind.pve => virtPveNamePattern.hasMatch(name),
        VirtHostKind.libvirt => virtLibvirtNamePattern.hasMatch(name),
        null =>
          virtPveNamePattern.hasMatch(name) &&
              virtLibvirtNamePattern.hasMatch(name),
      };
      if (!ok) return VirtHwIssue.nameInvalid;
      if (hw.running && !hw.renameRunning) return VirtHwIssue.nameRunning;
    case VirtHwSetDescription(:final text):
      if (text.length > virtHwDescriptionMax ||
          text.runes.any((r) => r < 0x20 && r != 0x0a && r != 0x09)) {
        return VirtHwIssue.description;
      }
    case VirtHwUpdateDisk(:final bus):
      if (bus != null && hw.running) return VirtHwIssue.stopFirst;
    case VirtHwSetNicHardware(:final mac):
      if (mac != null && !virtIsUnicastMac(mac)) return VirtHwIssue.mac;
    case VirtHwSetFirmware(:final uefi, :final storage):
      if (hw.running) return VirtHwIssue.stopFirst;
      if (host == VirtHostKind.pve && uefi && storage == null) {
        return VirtHwIssue.storageMissing;
      }
    case VirtHwAddDevice(:final kind, host: final device, :final storage):
      switch (kind) {
        case VirtHwDeviceKind.tpm:
          if (hw.hasTpm) return VirtHwIssue.device;
          if (host == VirtHostKind.pve && storage == null) {
            return VirtHwIssue.storageMissing;
          }
        case VirtHwDeviceKind.usb || VirtHwDeviceKind.pci:
          if (device == null) return VirtHwIssue.device;
      }
    case VirtHwRemoveDisk() ||
        VirtHwSetDisplay() ||
        VirtHwRemoveDevice() ||
        VirtHwSetMedia() ||
        VirtHwAddNic() ||
        VirtHwRemoveNic() ||
        VirtHwUpdateNic() ||
        VirtHwSetAutostart() ||
        VirtHwSetProtection() ||
        VirtHwRevert():
      break;
  }
  return null;
}
