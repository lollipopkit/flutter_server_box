/// Which command a libvirt serial console runs, and how a graphical console
/// is named to the remote desktop engine. The terminal page's arguments per
/// host are asserted in `test/widget/virt_tab_test.dart`, over the tab's
/// providers.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/view/page/virt/console_connect.dart';

void main() {
  const command =
      "virsh --connect qemu:///system console --force --domain 'a b'";

  test('the serial console runs as this account unless libvirt needs root', () {
    expect(
      VirtConsoleConnect.serialCommand(
        const LibvirtSerialConsole(command: command, needsRoot: false),
      ),
      command,
    );
    expect(
      VirtConsoleConnect.serialCommand(
        const LibvirtSerialConsole(command: command, needsRoot: true),
      ),
      'sudo $command',
    );
  });

  test("Disconnect sends virsh console's escape, Ctrl+]", () {
    expect(VirtConsoleConnect.serialEscape, [0x1d]);
  });

  test('a graphical console is a VNC session named after the guest', () {
    const guest = VirtGuest(
      id: 'qemu/100',
      name: 'web-01',
      kind: VirtGuestKind.qemu,
      state: VirtGuestState.running,
    );
    final profile = VirtConsoleConnect.vncProfile(serverId: 's', guest: guest);
    expect(profile.id, VirtConsoleConnect.vncSessionId('s', 'qemu/100'));
    expect(profile.name, 'web-01');
    expect(profile.protocol, RemoteDesktopProtocol.vnc);
    expect(profile.password, isNull, reason: 'each attempt brings its own');
  });

  test('a PVE ticket used as a VNC password is cut to what RFB reads', () {
    const console = PveVncConsole(
      node: 'pve',
      guestKind: VirtGuestKind.qemu,
      vmid: 100,
      port: 5900,
      ticket: 'PVEVNC:0123456789',
      user: 'root@pam',
      password: 'PVEVNC:0123456789',
    );
    expect(console.rfbPassword, 'PVEVNC:0');
  });
}
