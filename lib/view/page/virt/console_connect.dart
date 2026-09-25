import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/utils/pve_termproxy.dart';
import 'package:server_box/core/utils/server_tcp.dart';
import 'package:server_box/core/utils/websocket_tunnel.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/page/virt/common.dart';

/// How each console a guest has is opened (virt.md, "Console (phase 1)").
///
/// | Host    | Console | Carried by                                          |
/// | ------- | ------- | --------------------------------------------------- |
/// | PVE     | text    | `termproxy` → `vncwebsocket` → [PveTermShellBackend] in the terminal page |
/// | PVE     | VNC     | `vncproxy` → `vncwebsocket` → [WebSocketTunnelChannel] on a loopback port → the remote desktop engine |
/// | libvirt | text    | `virsh console` typed into a shell on the host, by the terminal page |
/// | libvirt | VNC     | `ServerTcpDialer.loopback` to the display's port → the remote desktop engine |
///
/// Everything here reads the host through a [ProviderContainer] when it runs,
/// not through a notifier captured once: the terminal page and the viewer
/// call these again on every reconnect, and both outlive the view that made
/// them.
abstract final class VirtConsoleConnect {
  /// `virsh console`'s escape, Ctrl+]: leaves the console and returns to the
  /// shell it was typed into.
  static const serialEscape = [0x1d];

  /// The remote desktop session a guest's graphical console is shown in.
  static String vncSessionId(String serverId, String guestId) =>
      'virt-console:$serverId:$guestId';

  /// What to type into a shell on the host to reach [console].
  ///
  /// Through `sudo` when the host's account reaches libvirt only that way,
  /// the way the container page runs its interactive commands: the terminal
  /// shows sudo's prompt, and its sudo key answers it.
  static String serialCommand(LibvirtSerialConsole console) =>
      console.needsRoot ? 'sudo ${console.command}' : console.command;

  /// The terminal page's arguments for [guest]'s text console.
  ///
  /// PVE: a [ConsoleSource], whose every connection is a new `termproxy`
  /// ticket. libvirt: a shell on the host — over whatever the terminal tab
  /// would use for this server: SSH, the agent's PTY, or this device — with
  /// `virsh console` typed into it and Ctrl+] offered as "Disconnect".
  static Future<SshPageArgs> textArgs(
    ProviderContainer container, {
    required String serverId,
    required VirtGuest guest,
  }) async {
    final kind = container.read(virtHostProvider(serverId)).kind;
    if (kind == VirtHostKind.pve) {
      return SshPageArgs(
        source: ConsoleSource(
          id: 'virt-console:$serverId:${guest.id}',
          label: guest.name,
          connect: () => pveTerminal(
            container,
            serverId: serverId,
            guestId: guest.id,
          ),
        ),
      );
    }
    final spi = container.read(serversProvider).servers[serverId];
    if (spi == null) throw const VirtErr(type: VirtErrType.serverRemoved);
    final console = await withHost(
      container,
      serverId,
      guest.id,
      (host) => host.console(guest.id, VirtConsoleKind.text),
    );
    if (console is! LibvirtSerialConsole) {
      throw const VirtErr(type: VirtErrType.unsupported);
    }
    return SshPageArgs(
      source: ServerSource(spi),
      initCmd: serialCommand(console),
      detachInput: serialEscape,
    );
  }

  /// A PVE text console: a fresh `termproxy` ticket, its websocket, and the
  /// termproxy handshake on it.
  static Future<PveTermShellBackend> pveTerminal(
    ProviderContainer container, {
    required String serverId,
    required String guestId,
  }) async {
    try {
      return await withHost(container, serverId, guestId, (host) async {
        final console = await host.console(guestId, VirtConsoleKind.text);
        if (console is! PveTermConsole) {
          throw const VirtErr(type: VirtErrType.unsupported);
        }
        final socket = await host.openPveConsoleSocket(console);
        return PveTermShellBackend.start(
          socket,
          user: console.user,
          ticket: console.ticket,
        );
      });
    } catch (e) {
      throw TerminalConsoleErr(
        describe(e),
        retryable: e is VirtErr && e.type == VirtErrType.unreachable,
        cause: e,
      );
    }
  }

  /// Where each connection attempt of [guestId]'s graphical console goes.
  ///
  /// PVE: a new `vncproxy` ticket and its websocket every time, since the
  /// proxy behind it accepts one connection and QEMU's password changes with
  /// the ticket. libvirt: the display's port, dialled from the host.
  static RemoteDesktopTargetOpener vncTarget(
    ProviderContainer container, {
    required String serverId,
    required String guestId,
  }) => () async {
    try {
      return await withHost(container, serverId, guestId, (host) async {
        final console = await host.console(guestId, VirtConsoleKind.vnc);
        switch (console) {
          case PveVncConsole():
            final socket = await host.openPveConsoleSocket(console);
            final tunnel = await WebSocketTunnelChannel.loopbackOnce(
              WebSocketTunnelChannel(socket),
            );
            return (tunnel: tunnel, password: console.rfbPassword);
          case LibvirtVncConsole(host: final at, :final port):
            final dialer = _dialer(container, serverId);
            try {
              return (tunnel: await dialer.loopback(at, port), password: null);
            } finally {
              // The tunnel owns what it runs on.
              dialer.close();
            }
          default:
            throw const VirtErr(type: VirtErrType.unsupported);
        }
      });
    } catch (e) {
      throw VirtConsoleFailure(describe(e), cause: e);
    }
  };

  /// A session for [guest]'s graphical console, as the remote desktop engine
  /// needs one. Not stored: [RemoteDesktopSessions.openConsole] takes the
  /// address and the password from [vncTarget] instead.
  static RemoteDesktopProfile vncProfile({
    required String serverId,
    required VirtGuest guest,
  }) => RemoteDesktopProfile(
    id: vncSessionId(serverId, guest.id),
    serverId: serverId,
    name: guest.name,
    protocol: RemoteDesktopProtocol.vnc,
    port: RemoteDesktopProtocol.vnc.defaultPort,
  );

  /// A failure in words for the user: the tab's title for a [VirtErr] and the
  /// host's own text under it.
  static String describe(Object e) => switch (e) {
    final VirtErr err => [err.title, ?err.detail].join('\n'),
    final ServerTcpErr err => [
      err.message ?? err.type.name,
      ?err.solution,
    ].join('\n'),
    _ => e.toString(),
  };

  /// Runs [action] on [serverId]'s host, kept alive while it does.
  ///
  /// The host's provider is disposed when nothing watches it, which can be
  /// the case for a terminal page left open over a tab that has moved on;
  /// the subscription holds it for the length of the call. A host that has
  /// not loaded [guestId] yet is loaded first.
  ///
  /// "Loaded first" is the build's own load when this call is what built the
  /// provider: building it starts one, so asking for another as well was two
  /// full host loads per console opened. A second is asked for only when the
  /// first has finished without the guest — a host loaded before it existed.
  static Future<T> withHost<T>(
    ProviderContainer container,
    String serverId,
    String guestId,
    Future<T> Function(VirtHostNotifier host) action,
  ) async {
    final provider = virtHostProvider(serverId);
    final sub = container.listen(provider, (_, _) {});
    try {
      final host = container.read(provider.notifier);
      if (container.read(provider).guest(guestId) == null) {
        await host.firstLoad;
        if (container.read(provider).guest(guestId) == null) {
          await host.refresh();
        }
      }
      return await action(host);
    } finally {
      sub.close();
    }
  }

  static ServerTcpDialer _dialer(ProviderContainer container, String id) {
    final spi = container.read(serversProvider).servers[id];
    if (spi == null) throw const VirtErr(type: VirtErrType.serverRemoved);
    return ServerTcpDialer(
      spi: spi,
      ssh: () async => ServerTcpSsh.client(
        await container.read(serverProvider(id).notifier).ensureShellClient(),
      ),
      relayGrant: () => container.read(serverProvider(id)).remoteAccess,
    );
  }
}

/// A graphical console that could not be opened. [toString] is [message],
/// which is what the viewer shows.
class VirtConsoleFailure implements Exception {
  const VirtConsoleFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
