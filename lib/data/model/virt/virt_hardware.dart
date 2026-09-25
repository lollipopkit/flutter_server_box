import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:server_box/data/model/virt/virt.dart';
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
  }) = _VirtHardware;

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
}

/// The least memory a guest is given here.
const virtHwMinMemoryMib = 16;

/// A container mount point: absolute, and nothing PVE's option syntax would
/// read as the next option.
final virtMountPointPattern = RegExp(r'^/[^,=\s]*[^,=\s/]$');

/// Why [change] cannot be made to [hw]; null when it can.
VirtHwIssue? virtHwIssue(VirtHardware hw, VirtHwChange change) {
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
    case VirtHwRemoveDisk() ||
        VirtHwSetMedia() ||
        VirtHwAddNic() ||
        VirtHwRemoveNic() ||
        VirtHwUpdateNic() ||
        VirtHwSetAutostart() ||
        VirtHwRevert():
      break;
  }
  return null;
}
