/// What a `ProxyCommand` failure says on a sandboxed build.
///
/// Measured, on one binary signed twice — with `app-sandbox` and without —
/// spawning `/bin/sh -c` children the way `ProxyCommandSocket` does:
///
/// | probe                          | sandboxed                  | not      |
/// |--------------------------------|----------------------------|----------|
/// | `$HOME` as the child sees it   | the app's container        | the home |
/// | `$HOME/.ssh/config`            | no such file               | reads    |
/// | `/Users/<me>/.ssh/config`      | Operation not permitted    | reads    |
/// | `ssh -W 127.0.0.1:22 <alias>`  | exit 255, "timed out"      | exit 0   |
/// | `/dev/tcp/127.0.0.1/22`        | works                      | works    |
///
/// So it is not only that `~/.ssh` is unreadable: `$HOME` is *replaced*, and
/// the error that reaches the user names their jump host and says "Operation
/// timed out". Nothing in it says sandbox, and the app used to pass that
/// through as a bare `ProxyCommand exited with code 255.`
///
/// The last row is why this is a note rather than a refusal — a command that
/// touches no home-directory path still works there.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/proxy_command_socket.dart';

void main() {
  group('the sandbox note', () {
    test('is appended to a failure, not substituted for it', () {
      const original = 'ProxyCommand exited with code 255.';
      final explained = ProxyCommandSocket.debugExplain(
        original,
        sandboxed: true,
      );

      // The command's own outcome still has to be readable: it is the only
      // thing that says which command and how it ended
      expect(explained, startsWith(original));
      expect(explained.length, greaterThan(original.length));
    });

    test('says nothing on a build that is not confined', () {
      const original = 'ProxyCommand timed out after 5s.';
      expect(
        ProxyCommandSocket.debugExplain(original, sandboxed: false),
        original,
      );
    });

    test('names the home directory, which is the part that surprises', () {
      final explained = ProxyCommandSocket.debugExplain('x', sandboxed: true);
      // Not "permission denied": the child gets a *different* home, so the
      // failure it reports is about a host or a missing file, never about
      // access. A note that said "denied" would send someone looking for a
      // permission dialog that does not exist.
      expect(explained.toLowerCase(), contains('home'));
      expect(explained, contains('~/.ssh'));
    });
  });

  group('what a placeholder may expand to', () {
    test('the shapes a real host or user comes in are all allowed', () {
      for (final value in [
        'example.com',
        '192.168.1.10',
        '[2001:db8::1]',
        'fe80::1',
        'my-host_01.internal',
        'root',
        'ad\\user',
        'user@realm',
      ]) {
        expect(
          ProxyCommandSocket.checkSubstitutable('host', value),
          value,
          reason: '$value names a host or a user and has to go through',
        );
      }
    });

    test('anything a shell would read as syntax is refused', () {
      // The expansion is textual and the result runs under `sh -c`, so each of
      // these is a local command executing before authentication. The address
      // is not necessarily this device's own: it arrives from an imported
      // `~/.ssh/config`, a restored backup or a synced peer.
      for (final value in [
        'h; touch /tmp/pwned',
        r'h$(id)',
        'h`id`',
        'h | sh',
        'h && id',
        r'h$IFS',
        'h\nid',
        "h'",
        'h"',
        'h%p',
      ]) {
        expect(
          () => ProxyCommandSocket.checkSubstitutable('host', value),
          throwsA(isA<Object>()),
          reason: '$value must not reach /bin/sh',
        );
      }
    });
  });
}
