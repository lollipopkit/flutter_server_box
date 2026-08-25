/// Which virtual keys a terminal can actually use.
///
/// Four of them act on a *server*, and on a shell that is not on one — this
/// device's, and the Linux systems installed in it — they used to return
/// without a word: the strip drew them, they took a tap, and nothing happened.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';

Spi _ssh({String user = 'me'}) => Spi(
  id: 's-1',
  name: 'box',
  ssh: SshCredential(ip: '10.0.0.1', user: user),
);

Spi _monitor() => Spi(
  id: 's-2',
  name: 'agent',
  monitorHttp: const MonitorHttpCredential(addr: 'https://10.0.0.2'),
);

void main() {
  group('a shell on this device', () {
    test('is offered nothing that needs a server', () {
      // The report this exists for: on a Linux system installed in the app,
      // the file, sudo and tmux keys were all dead buttons.
      expect(VirtKey.sftp.worksOn(null), isFalse);
      expect(VirtKey.sudo.worksOn(null), isFalse);
      expect(VirtKey.tmux.worksOn(null), isFalse);
    });

    test('keeps everything the terminal itself does', () {
      // Including snippets: a snippet is a script typed into whatever shell is
      // there, and the ones naming no server run here perfectly well. That key
      // used to bail for want of a server it never needed.
      for (final key in [
        VirtKey.snippet,
        VirtKey.clipboard,
        VirtKey.ime,
        VirtKey.ctrl,
        VirtKey.esc,
        VirtKey.up,
        VirtKey.f1,
        VirtKey.slash,
      ]) {
        expect(
          key.worksOn(null),
          isTrue,
          reason: "${key.name} is the terminal's own",
        );
      }
    });
  });

  group('a server over SSH', () {
    test('is offered all of them', () {
      for (final key in VirtKey.values) {
        expect(key.worksOn(_ssh()), isTrue, reason: key.name);
      }
    });

    test('except sudo where the session is already root', () {
      // The same rule the toolbar's own sudo button applies, so the two cannot
      // disagree about the same server.
      expect(VirtKey.sudo.worksOn(_ssh(user: 'root')), isFalse);
    });
  });

  group('a server reached through its monitor agent', () {
    test('has files and a shell, but nothing to drive tmux with', () {
      final spi = _monitor();
      // tmux needs a channel that does not echo what is written into it, and
      // the agent carries no exec channel at all.
      expect(VirtKey.tmux.worksOn(spi), isFalse);
      // The file key opens `ServerFilePage`, which serves a monitor server
      // from the agent's own file API.
      expect(VirtKey.sftp.worksOn(spi), isTrue);
      expect(VirtKey.snippet.worksOn(spi), isTrue);
    });
  });
}
