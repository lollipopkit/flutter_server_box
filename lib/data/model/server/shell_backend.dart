import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

/// A live shell: bytes in, bytes out, and a size.
///
/// The terminal page is written against this rather than against
/// [SSHSession] because a shell does not have to come from SSH. A `monitor`
/// agent can hand out a PTY on the machine it runs on, which is the same
/// shape — a byte stream that can be resized and that ends — reached over a
/// protocol that has no SSH in it at all.
///
/// That is why the seam is here and not one layer down at `SSHSocket`, where
/// direct/jump/ProxyCommand/tunnel already meet: those all still speak SSH,
/// so they answer "where do the bytes come from". This answers "what produced
/// them".
abstract interface class ShellSession {
  Stream<Uint8List>? get stdout;

  /// Null for sources that don't separate it — a PTY merges the two streams
  /// the same way a real terminal does.
  Stream<Uint8List>? get stderr;

  void write(List<int> data);

  void resizeTerminal(int width, int height);

  /// Completes when the shell is gone for good. A source that can recover
  /// from a dropped link must not complete this for a mere disconnection.
  Future<void> get done;

  void close();
}

/// Where a [ShellSession] comes from, and what else that source can do.
abstract interface class ShellBackend {
  /// Whether the source itself is dead. A session ending does not imply this:
  /// an SSH client outlives the shells it opens.
  bool get isClosed;

  /// Whether one-off commands can run alongside the interactive shell.
  ///
  /// SSH multiplexes channels, so it can. A single PTY cannot — there is one
  /// stream and a command written into it would land in the user's shell.
  /// Everything built on [execute] (tmux, snippets that need a second
  /// channel, the AI helper's probe) has to check this rather than assume it.
  bool get supportsExec;

  Future<ShellSession> openShell({
    required int width,
    required int height,
    Map<String, String>? environment,
  });

  /// Runs [command] on its own channel. Throws [UnsupportedError] when
  /// [supportsExec] is false.
  Future<ShellSession> execute(
    String command, {
    required int width,
    required int height,
    Map<String, String>? environment,
  });

  /// Throws when the link is gone. Drives the terminal page's keep-alive.
  Future<void> ping();

  void close();
}

/// [ShellBackend] over a real SSH connection.
class SshShellBackend implements ShellBackend {
  SshShellBackend(this.client);

  final SSHClient client;

  @override
  bool get isClosed => client.isClosed;

  @override
  bool get supportsExec => true;

  @override
  Future<ShellSession> openShell({
    required int width,
    required int height,
    Map<String, String>? environment,
  }) async {
    final session = await client.shell(
      pty: SSHPtyConfig(width: width, height: height),
      environment: environment,
    );
    return SshShellSession(session);
  }

  @override
  Future<ShellSession> execute(
    String command, {
    required int width,
    required int height,
    Map<String, String>? environment,
  }) async {
    final session = await client.execute(
      command,
      pty: SSHPtyConfig(width: width, height: height),
      environment: environment,
    );
    return SshShellSession(session);
  }

  @override
  Future<void> ping() => client.ping();

  @override
  void close() => client.close();
}

/// [ShellSession] over an SSH channel.
class SshShellSession implements ShellSession {
  SshShellSession(this.session);

  final SSHSession session;

  @override
  Stream<Uint8List>? get stdout => session.stdout;

  @override
  Stream<Uint8List>? get stderr => session.stderr;

  @override
  void write(List<int> data) =>
      session.write(data is Uint8List ? data : Uint8List.fromList(data));

  @override
  void resizeTerminal(int width, int height) =>
      session.resizeTerminal(width, height);

  @override
  Future<void> get done => session.done;

  @override
  void close() => session.close();
}
