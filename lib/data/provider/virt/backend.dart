import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';

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

  /// Drops any session, so the next call starts over (a new login, a new
  /// sudo probe). Keeps what the user confirmed or typed: a pinned
  /// certificate, a sudo password.
  Future<void> reset();

  /// Releases everything. The backend is not used afterwards.
  Future<void> close();
}
