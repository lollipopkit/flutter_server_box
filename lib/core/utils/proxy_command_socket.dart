import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/error.dart';

class ProxyCommandSocket implements SSHSocket {
  ProxyCommandSocket._({
    required Process process,
    required Stream<Uint8List> stream,
    required StreamSink<List<int>> sink,
    required Future<void> done,
  }) : _process = process,
       _stream = stream,
       _sink = sink,
       _done = done;

  final Process _process;
  final Stream<Uint8List> _stream;
  final StreamSink<List<int>> _sink;
  final Future<void> _done;

  static Future<SSHSocket> connect({
    required String command,
    required String host,
    required int port,
    required String user,
  }) async {
    if (!isDesktop) {
      throw SSHErr(
        type: SSHErrType.connect,
        message: 'ProxyCommand is only supported on desktop platforms.',
      );
    }

    final resolvedCommand = _resolveCommand(
      command: command,
      host: host,
      port: port,
      user: user,
    );
    final shellCommand = _buildShellCommand(resolvedCommand);

    Loggers.app.info('Starting ProxyCommand for $user@$host:$port');

    final process = await Process.start(
      shellCommand.executable,
      shellCommand.arguments,
      mode: ProcessStartMode.normal,
    );

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => Loggers.app.warning('ProxyCommand stderr: $line'));

    final done = process.exitCode.then((code) {
      if (code != 0) {
        throw SSHErr(
          type: SSHErrType.connect,
          message: 'ProxyCommand exited with code $code.',
        );
      }
    });

    return ProxyCommandSocket._(
      process: process,
      stream: process.stdout.map(Uint8List.fromList),
      sink: process.stdin,
      done: done,
    );
  }

  static String _resolveCommand({
    required String command,
    required String host,
    required int port,
    required String user,
  }) {
    return command
        .replaceAll('%h', host)
        .replaceAll('%p', port.toString())
        .replaceAll('%r', user)
        .replaceAll('%%', '%');
  }

  static ({String executable, List<String> arguments}) _buildShellCommand(
    String command,
  ) {
    if (Platform.isWindows) {
      return (executable: 'cmd', arguments: ['/C', command]);
    }
    return (executable: '/bin/sh', arguments: ['-c', command]);
  }

  @override
  Stream<Uint8List> get stream => _stream;

  @override
  StreamSink<List<int>> get sink => _sink;

  @override
  Future<void> get done => _done;

  @override
  Future<void> close() async {
    await _sink.close();
    if (_process.kill()) {
      await _done.catchError((_) {});
      return;
    }
    await _done;
  }

  @override
  void destroy() {
    _process.kill();
  }

  @override
  String toString() => 'ProxyCommandSocket(pid: ${_process.pid})';
}
