import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';

/// What opening a console needs, fetched by `VirtBackend.console`.
///
/// A handle, not a connection: a PVE ticket is good for a short while and
/// one use, so fetch it right before connecting.
sealed class VirtConsole {
  const VirtConsole();

  VirtConsoleKind get kind;
}

/// A PVE console: `termproxy` or `vncproxy`, reached through the node's
/// `vncwebsocket`, which `PveBackend.openConsoleSocket` opens over the same
/// transport and login as the API calls.
sealed class PveConsole extends VirtConsole {
  const PveConsole({
    required this.node,
    required this.guestKind,
    required this.vmid,
    required this.port,
    required this.ticket,
    required this.user,
  });

  final String node;
  final VirtGuestKind guestKind;
  final int vmid;

  /// The proxy's port on the node, passed back to `vncwebsocket`.
  final int port;

  /// The console ticket. Short-lived; never logged.
  final String ticket;

  /// The PVE user the ticket was issued to.
  final String user;

  /// `vncwebsocket`'s path and query, relative to the API's origin.
  String get websocketPath =>
      '/api2/json/nodes/${Uri.encodeComponent(node)}/${guestKind.name}/$vmid'
      '/vncwebsocket?port=$port&vncticket=${Uri.encodeQueryComponent(ticket)}';

  @override
  String toString() =>
      '$runtimeType(node: $node, ${guestKind.name}/$vmid, port: $port)';
}

/// PVE `termproxy`: an xterm.js-protocol text console.
///
/// After the websocket opens, the client sends `<user>:<ticket>\n` first;
/// then `0:<len>:<data>` for input, `1:<cols>:<rows>:` to resize, `2` as a
/// keep-alive. Output arrives as raw terminal bytes.
final class PveTermConsole extends PveConsole {
  const PveTermConsole({
    required super.node,
    required super.guestKind,
    required super.vmid,
    required super.port,
    required super.ticket,
    required super.user,
  });

  @override
  VirtConsoleKind get kind => VirtConsoleKind.text;
}

/// PVE `vncproxy`: RFB over the websocket, one binary frame per slice of
/// the stream.
final class PveVncConsole extends PveConsole {
  const PveVncConsole({
    required super.node,
    required super.guestKind,
    required super.vmid,
    required super.port,
    required super.ticket,
    required super.user,
    required this.password,
  });

  /// The VNC password QEMU was given for this connection: the one
  /// `generate-password` made, or — before PVE 7.2 — [ticket] itself. Never
  /// logged.
  final String password;

  /// [password] as RFB's VNC authentication uses it: DES keyed with the first
  /// 8 bytes, which is also all QEMU keeps of a longer one. So a ticket cut to
  /// 8 authenticates exactly as the whole ticket would.
  String get rfbPassword =>
      password.length <= 8 ? password : password.substring(0, 8);

  @override
  VirtConsoleKind get kind => VirtConsoleKind.vnc;
}

/// libvirt serial console: [command] run in a terminal session on the server
/// (it needs a PTY, so it is not an exec).
final class LibvirtSerialConsole extends VirtConsole {
  const LibvirtSerialConsole({required this.command, required this.needsRoot});

  /// `virsh ... console --force --domain '<uuid>'`. Single-quoted arguments
  /// only, so it runs the same under a POSIX shell and fish.
  final String command;

  /// This account reaches the daemon only through sudo: run it as
  /// `sudo <command>`, where the terminal can ask for the password.
  final bool needsRoot;

  @override
  VirtConsoleKind get kind => VirtConsoleKind.text;
}

/// libvirt graphical console: a VNC server on the hypervisor. Dial [host]:
/// [port] from the server's side with `ServerTcpDialer.loopback` and point
/// the VNC client at the loopback port.
final class LibvirtVncConsole extends VirtConsole {
  const LibvirtVncConsole({required this.host, required this.port});

  /// As seen from the hypervisor; a wildcard listen address is given as
  /// loopback.
  final String host;
  final int port;

  @override
  VirtConsoleKind get kind => VirtConsoleKind.vnc;

  @override
  String toString() => 'LibvirtVncConsole($host:$port)';
}
