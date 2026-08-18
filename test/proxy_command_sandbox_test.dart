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
}
