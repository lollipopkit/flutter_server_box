import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/android_rootfs.dart';
import 'package:server_box/core/utils/ish_proxy_socket.dart';
import 'package:server_box/core/utils/process_tree.dart';
import 'package:server_box/data/model/app/error.dart';

/// An [SSHSocket] over a ProxyCommand's standard streams.
///
/// Where the command runs is the platform's answer to "a shell": the host's
/// own on a desktop, and the Linux guest on a phone, where the host has none a
/// user's tools are in. Android's guest is a process under proot and goes
/// through this class like the desktop; iOS has no processes to start, and
/// [IshProxySocket] runs the command in its interpreter instead.
class ProxyCommandSocket implements SSHSocket {
  ProxyCommandSocket._({
    required Process process,
    required int? processGroupId,
    required Stream<Uint8List> stream,
    required IOSink sink,
    required Future<void> done,
    void Function()? release,
  }) : _process = process,
       _processGroupId = processGroupId,
       _stream = stream,
       _sink = sink,
       _done = done,
       _release = release {
    // The guest stays "in use" — and so cannot be deleted — for exactly as
    // long as the proxy runs.
    unawaited(_done.whenComplete(_releaseOnce).catchError((_) {}));
  }

  final Process _process;
  final int? _processGroupId;
  final Stream<Uint8List> _stream;
  final IOSink _sink;
  final Future<void> _done;
  final void Function()? _release;
  var _released = false;

  void _releaseOnce() {
    if (_released) return;
    _released = true;
    _release?.call();
  }

  static Future<SSHSocket> connect({
    required String command,
    required String host,
    required int port,
    required String user,
    required String originalHost,
    required String jump,
    Duration? timeout,
  }) async {
    if (command.length > 4096) {
      throw SSHErr(
        type: SSHErrType.connect,
        message: 'ProxyCommand too long (${command.length} chars, max 4096)',
      );
    }

    final resolvedCommand = resolveCommand(
      command: command,
      host: host,
      port: port,
      user: user,
      originalHost: originalHost,
      jump: jump,
    );
    if (isIOS) {
      return IshProxySocket.connect(
        command: resolvedCommand,
        timeout: timeout,
      );
    }

    // Android: in the selected Linux system, under proot. The host has a
    // shell, but none of the tools a ProxyCommand names — `nc`, `socat`,
    // `ssh`, `cloudflared` are installed in the guest, not on Android.
    final guest = isAndroid
        ? await AndroidRootfs.enter(command: resolvedCommand)
        : null;
    if (isAndroid && guest == null) {
      throw SSHErr(
        type: SSHErrType.connect,
        message: l10n.proxyCommandNeedsLinux,
      );
    }
    final shellCommand = guest == null
        ? _buildShellCommand(resolvedCommand)
        : (executable: guest.executable, arguments: guest.arguments);

    // Not `$user@$host:$port`. This line said which account on which machine,
    // and it is an `info` — so it landed in the log of every run that used a
    // ProxyCommand, including the ones pasted into bug reports. The port is
    // kept because it is the part that explains a failure and names nothing.
    Loggers.app.info(
      'Starting ProxyCommand for ${Redact.host(host)}:$port',
    );

    final processFuture = Process.start(
      shellCommand.executable,
      shellCommand.arguments,
      // The guest's own PATH and home: Android's names directories that do
      // not exist inside it, and the command would find none of its tools.
      environment: guest == null ? null : AndroidRootfs.environment,
      // This creates a separate Unix session. The returned PID is the final
      // fork rather than the session leader, so its actual PGID is queried
      // below. Windows cleanup uses taskkill /T.
      mode: ProcessStartMode.detachedWithStdio,
    );
    late final Process process;
    try {
      process = timeout == null
          ? await processFuture
          : await processFuture.timeout(timeout);
    } on TimeoutException {
      // Timing out this Future does not cancel process creation. Kill a child
      // that appears later instead of leaving a detached proxy behind — and
      // only then free the guest it was running in.
      unawaited(
        processFuture
            .then<void>((lateProcess) async {
              final groupId = await ProcessTree.groupId(lateProcess);
              ProcessTree.terminate(lateProcess, groupId);
            }, onError: (_, _) {})
            .whenComplete(() => guest?.release()),
      );
      throw SSHErr(
        type: SSHErrType.connect,
        message: _explain(
          'ProxyCommand process start timed out after ${timeout!.inSeconds}s.',
        ),
      );
    } catch (_) {
      guest?.release();
      rethrow;
    }
    final processGroupId = await ProcessTree.groupId(process);
    final stdoutController = StreamController<Uint8List>();

    process.stdout.listen(
      (data) {
        final chunk = Uint8List.fromList(data);
        stdoutController.add(chunk);
      },
      onError: (error, stackTrace) {
        stdoutController.addError(error, stackTrace);
      },
      onDone: () {
        stdoutController.close();
      },
    );
    process.stderr.listen(
      (data) {
        const maxLoggedBytes = 4096;
        final capped = data.length <= maxLoggedBytes
            ? data
            : data.sublist(0, maxLoggedBytes);
        final message = utf8.decode(capped, allowMalformed: true).trimRight();
        if (message.isEmpty) return;
        final suffix = data.length > maxLoggedBytes ? ' [truncated]' : '';
        Loggers.app.warning('ProxyCommand stderr: $message$suffix');
      },
      onError: (error, stackTrace) {
        Loggers.app.warning(
          'ProxyCommand stderr stream error',
          error,
          stackTrace,
        );
      },
    );

    // The SSH socket's lifecycle is the byte stream, not the helper process.
    // A proxy that keeps its process alive after closing the transport would
    // otherwise leave SSHSocket.done pending forever, while a shell that
    // exits non-zero after forwarding ended would incorrectly report a
    // transport failure.
    final done = stdoutController.done;

    return ProxyCommandSocket._(
      process: process,
      processGroupId: processGroupId,
      stream: stdoutController.stream,
      sink: process.stdin,
      done: done,
      release: guest?.release,
    );
  }

  /// [message], plus what a sandboxed build has almost certainly done to it.
  ///
  /// Measured on a build signed with `app-sandbox`, against the same binary
  /// signed without it: the child does not merely lose access to `~/.ssh`, its
  /// `$HOME` is replaced by the app's container. So `~` silently points
  /// somewhere else and only an absolute path into the real home reports
  /// `Operation not permitted`.
  ///
  /// Which makes the failure unrecognisable. `ssh -W %h:%p alias` cannot read
  /// `~/.ssh/config`, so the alias is never resolved, ssh takes it for a literal
  /// hostname and reports `connect to host alias port 22: Operation timed
  /// out` — a network fault, naming the user's jump host, with nothing anywhere
  /// saying "sandbox".
  ///
  /// Appended rather than substituted, and hedged: a command that touches no
  /// home-directory path works there (`nc %h %p` was measured working, network
  /// access being granted), so this is the likely cause and not the certain one.
  static String _explain(String message) =>
      explain(message, sandboxed: Pfs.isMacSandboxed);

  static String explain(String message, {required bool sandboxed}) {
    if (!sandboxed) return message;
    return '$message\n\n${l10n.proxyCommandSandboxed}';
  }

  /// Everything a hostname, an IPv4 or IPv6 literal, or a POSIX user name is
  /// made of, and nothing a shell reads as syntax. `%` is absent on purpose:
  /// a value carrying one could introduce a placeholder of its own.
  static final _substitutable = RegExp(r'^[A-Za-z0-9._,@:\-\[\]]*$');

  /// Refuses a value that `/bin/sh` would not read as one word.
  ///
  /// The expansion below is textual and the result is handed to `sh -c`, so a
  /// host of `h; curl … | sh` is a local command that runs before anything has
  /// been authenticated. That the ProxyCommand itself is the user's own is not
  /// the answer: the address it expands is not necessarily — it arrives from
  /// an imported `~/.ssh/config`, a restored backup or a synced peer.
  ///
  /// Rejected rather than quoted. Quoting correctly means knowing which
  /// context the placeholder sits in — bare, inside `"…"`, inside `'…'` — and
  /// guessing that wrong is how a quoting fix becomes the next injection.
  /// Nothing that names a real host or user is refused here.
  @visibleForTesting
  static String checkSubstitutable(String what, String value) {
    if (_substitutable.hasMatch(value)) return value;
    throw SSHErr(
      type: SSHErrType.connect,
      message:
          'ProxyCommand cannot use this $what: "$value" contains characters '
          'a shell would read as syntax.',
    );
  }

  static String resolveCommand({
    required String command,
    required String host,
    required int port,
    required String user,
    required String originalHost,
    required String jump,
  }) {
    const percentPlaceholder = '\u0000PERCENT\u0000';
    return command
        .replaceAll('%%', percentPlaceholder)
        .replaceAll('%h', checkSubstitutable('host', host))
        .replaceAll('%n', checkSubstitutable('original host', originalHost))
        .replaceAll('%p', port.toString())
        .replaceAll('%r', checkSubstitutable('user', user))
        .replaceAll('%j', checkSubstitutable('jump', jump))
        .replaceAll(percentPlaceholder, '%');
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
    // Kill first so a child that ignores stdin EOF does not block close().
    ProcessTree.terminate(_process, _processGroupId);
    try {
      await _sink.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await _done.timeout(const Duration(seconds: 2)).catchError((_) {});
    } catch (_) {}
    // Ensure the process is gone even if the above timed out.
    try {
      _process.kill(ProcessSignal.sigkill);
    } catch (_) {}
    try {
      if (!Platform.isWindows && _processGroupId != null) {
        Process.killPid(-_processGroupId, ProcessSignal.sigkill);
      }
    } catch (_) {}
    _releaseOnce();
  }

  @override
  Future<void> flush() => _sink.flush();

  @override
  void destroy() {
    ProcessTree.terminate(_process, _processGroupId);
    _releaseOnce();
  }

  @override
  String toString() => 'ProxyCommandSocket(pid: ${_process.pid})';
}
