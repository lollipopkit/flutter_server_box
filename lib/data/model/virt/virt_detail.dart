import 'package:freezed_annotation/freezed_annotation.dart';

part 'virt_detail.freezed.dart';

/// The consoles a guest offers — see `VirtConsole` for what opening one gives.
enum VirtConsoleKind {
  /// Text: PVE `termproxy` (an LXC shell, or a QEMU guest's `serial0`), or
  /// libvirt's `virsh console` on the guest's serial device.
  text,

  /// Graphical: VNC.
  vnc,
}

/// A disk, CD drive or container volume.
@freezed
abstract class VirtDisk with _$VirtDisk {
  const factory VirtDisk({
    /// `disk`, `cdrom`, `floppy`, `lun`; PVE containers: `rootfs`, `mp`.
    @Default('disk') String device,

    /// libvirt's source kind (`file`, `block`, `network`, `volume`).
    String? sourceType,

    /// Path, `pool/volume`, PVE `storage:volume`; null for an empty drive.
    String? source,

    /// libvirt target (`vda`) or PVE key (`scsi0`, `rootfs`, `mp0`).
    String? target,
    String? bus,

    /// Image format, e.g. `qcow2`.
    String? format,
    @Default(false) bool readonly,

    /// Size in bytes, where the configuration says (PVE `size=`).
    int? size,
  }) = _VirtDisk;
}

/// A network interface.
@freezed
abstract class VirtNic with _$VirtNic {
  const factory VirtNic({
    /// libvirt `network`/`bridge`/`direct`/...; PVE `net0`, `net1`, ...
    @Default('') String kind,
    String? mac,

    /// Network, bridge or host device.
    String? source,

    /// NIC model (`virtio`, `e1000e`), or `veth` for a container.
    String? model,

    /// Host-side device while running (libvirt `vnetN`), or a container's
    /// interface name (`eth0`).
    String? target,
  }) = _VirtNic;
}

/// A graphics device in the guest's configuration.
@freezed
abstract class VirtGraphics with _$VirtGraphics {
  const factory VirtGraphics({
    /// `vnc`, `spice`, ...; PVE's `vga` type (`std`, `qxl`, `serial0`).
    @Default('') String kind,
    int? port,
    int? tlsPort,
    @Default(false) bool autoport,
    String? listen,
    String? socket,
  }) = _VirtGraphics;
}

/// Where a running libvirt guest's display listens (`virsh domdisplay`).
@freezed
abstract class VirtDisplay with _$VirtDisplay {
  const factory VirtDisplay({
    required String uri,
    required String protocol,

    /// On the hypervisor's side; `localhost` means the hypervisor itself.
    String? host,
    int? port,
    int? tlsPort,
    String? socket,
  }) = _VirtDisplay;
}

/// Phase 1 guest detail: disks, NICs, display, and which consoles open.
@freezed
abstract class VirtGuestDetail with _$VirtGuestDetail {
  const factory VirtGuestDetail({
    @Default(<VirtDisk>[]) List<VirtDisk> disks,
    @Default(<VirtNic>[]) List<VirtNic> nics,
    @Default(<VirtGraphics>[]) List<VirtGraphics> graphics,

    /// libvirt, while running with graphics.
    VirtDisplay? display,
    @Default(<VirtConsoleKind>{}) Set<VirtConsoleKind> consoles,
    String? description,
    String? arch,

    /// libvirt machine type, or PVE `ostype`.
    String? machine,
  }) = _VirtGuestDetail;
}
