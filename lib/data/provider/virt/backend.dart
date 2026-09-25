import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';

/// One virtualization host, as the Virtualization tab talks to it.
///
/// The UI only sees this and the models; how a host is reached — PVE's HTTP
/// API over `ServerTcpDialer`, or `virsh` over `ServerNotifier.ensureExec()` —
/// stays inside `PveBackend` and `LibvirtBackend`.
///
/// Every method throws `VirtErr`. Methods may be called concurrently; a
/// backend serialises what must not overlap (a PVE login) itself.
abstract interface class VirtBackend {
  String get serverId;
  VirtHostKind get kind;

  /// Host, guests and their current usage. Connects and logs in first when
  /// needed. Rates come from the difference to the previous [load] — see
  /// `VirtRateTracker` — so the first load has none.
  Future<VirtSnapshot> load();

  /// Runs [action] on [guest] and returns once the host has finished it (PVE:
  /// its task has stopped; libvirt: `virsh` has returned). Throws
  /// `VirtErrType.unsupported` for an action not in [VirtGuest.actions], and
  /// `VirtErrType.actionFailed` with the host's text when it refused.
  Future<void> power(VirtGuest guest, VirtPowerAction action);

  /// Disks, NICs, display and consoles.
  Future<VirtGuestDetail> detail(VirtGuest guest);

  /// A fresh handle for [kind] of console on [guest]. Fetch right before
  /// connecting: PVE tickets are short-lived.
  Future<VirtConsole> console(VirtGuest guest, VirtConsoleKind kind);

  /// Usage over [window] as the host stored it, oldest first; null when the
  /// host keeps none (`VirtCapabilities.storedHistory` false).
  Future<List<VirtStats>?> history(
    VirtGuest guest, {
    VirtHistoryWindow window = VirtHistoryWindow.hour,
  });

  /// [guest]'s snapshots, in no particular order (`virtSnapshotTree` orders
  /// them). Only where `VirtCapabilities.snapshots`.
  Future<List<VirtGuestSnapshot>> snapshots(VirtGuest guest);

  /// Takes a snapshot named [name] (checked with `virtSnapshotNameIssue`
  /// first), and returns once the host has finished. [memory] asks for the
  /// guest's memory as well, where `virtSnapshotMemory` says it is optional;
  /// where it is always taken, it is taken whatever this says.
  Future<void> createSnapshot(
    VirtGuest guest, {
    required String name,
    String? description,
    bool memory = false,
  });

  /// Reverts [guest] to the snapshot [name]. A snapshot without memory leaves
  /// the guest stopped — a running one is stopped by it — unless [start].
  Future<void> revertSnapshot(
    VirtGuest guest,
    String name, {
    bool start = false,
  });

  /// Deletes the snapshot [name]. Its children keep their contents and move
  /// up to its parent.
  Future<void> deleteSnapshot(VirtGuest guest, String name);

  /// Storage pools, every node's for a PVE cluster. Only where
  /// `VirtCapabilities.storage`.
  Future<List<VirtStoragePool>> storagePools();

  /// What is in [pool], with the guests using each volume.
  Future<List<VirtVolume>> volumes(VirtStoragePool pool);

  /// Networks with the guests on each. Only where `VirtCapabilities.network`.
  Future<List<VirtNetwork>> networks();

  /// The VMID PVE would give a new guest (`/cluster/nextid`); null where the
  /// host has no such thing.
  Future<int?> nextVmid();

  /// Creates [spec] (checked with `virtCreateIssue` first) and returns once
  /// the host has finished — started too, when asked. Throws
  /// `VirtErrType.exists` for a name, VMID or disk already there, and
  /// `VirtErrType.actionFailed` with the host's words for the rest. A guest
  /// that was created and then failed to start is not a failure:
  /// [VirtCreated.startError] says why. Only where `VirtCapabilities.create`.
  Future<VirtCreated> create(VirtCreateSpec spec);

  /// Deletes [guest], which must be stopped (a running one is refused, not
  /// stopped), with its snapshots. [removeDisks] deletes its disks as well;
  /// PVE always does (`VirtCapabilities.deleteKeepsDisks`). Install media
  /// attached to it is never deleted.
  Future<void> delete(VirtGuest guest, {bool removeDisks = true});

  /// Drops any session, so the next call starts over (a new login, a new
  /// sudo probe). Keeps what the user confirmed or typed: a pinned
  /// certificate, a sudo password.
  Future<void> reset();

  /// Releases everything. The backend is not used afterwards.
  Future<void> close();
}
