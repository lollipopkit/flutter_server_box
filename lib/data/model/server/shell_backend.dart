import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_tty/fl_tty.dart';

export 'package:fl_tty/fl_tty.dart' show ShellBackend, ShellSession;

/// [ShellBackend] over a real SSH connection.
class SshShellBackend implements ShellBackend {
  SshShellBackend(this.client);

  final SSHClient client;

  @override
  bool get isClosed => client.isClosed;

  @override
  bool get supportsExec => true;

  @override
  bool get supportsTmux => true;

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
  void resizeTerminal(int width, int height) {
    try {
      session.resizeTerminal(width, height);
    } on SSHStateError {
      // The transport closed under the channel. Nothing to tell a session that
      // is gone, and [done] is what reports it.
    }
  }

  @override
  Future<void> get done => session.done;

  @override
  void close() => session.close();
}
