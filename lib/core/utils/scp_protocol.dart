/// The SCP wire protocol, as `scp -f` and `scp -t` speak it.
///
/// SCP is not a filesystem protocol — it is one program on each end of an
/// exec channel, agreeing on how to hand over the bytes of one file. That is
/// the whole of it: there is no listing, no stat, no rename, and no way to
/// start anywhere but the beginning. `ScpFileBackend` is what fills the rest
/// in, with a shell.
///
/// It exists here because SFTP is a *subsystem* sshd has to be built and
/// configured to offer, and the machines this app is asked to reach do not
/// always offer it — an OpenWrt router running dropbear, an embedded box whose
/// firmware ships `scp` and nothing else (#1288). Those hosts still run
/// commands, and running a command is all SCP needs.
///
/// One direction per function, named as the remote side sees them: the remote
/// `scp -f` is the *source* this device reads from, and the remote `scp -t` is
/// the *sink* it writes to.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:server_box/core/utils/shell_quote.dart';

/// One remote process's two byte streams and its exit status.
///
/// An interface rather than an [SSHSession] directly, because the protocol
/// below is the part worth testing and a test that needed a server could not
/// run at all. [SshScpChannel] is the only implementation the app builds; a
/// test supplies a scripted remote instead.
abstract interface class ScpChannel {
  Stream<Uint8List> get stdout;

  Stream<Uint8List> get stderr;

  /// Queues [data] for the remote's stdin.
  void add(Uint8List data);

  /// Completes once what was queued has actually left this device.
  ///
  /// The only backpressure there is: the channel accepts whatever it is handed
  /// and sends it as the remote's window allows, so a caller that never waited
  /// would hold a whole file in memory.
  Future<void> flush();

  /// Sends EOF, which is how the sink is told the transfer is over.
  Future<void> closeInput();

  /// Null where the process has not exited, or where the far side reports no
  /// exit status at all — dropbear does not always.
  ///
  /// Those two are told apart by *how* they are asked. With no [timeout] this
  /// completes when the process exits or the channel closes, so a null answer
  /// means "no status was reported"; a process that never finishes never
  /// answers. Passing [timeout] folds the second case into the first, which is
  /// why [_ScpSession.finish] bounds the wait itself instead.
  Future<int?> exitCode({Duration? timeout});

  /// Gives up on the process, whatever state it is in.
  void close();
}

/// [ScpChannel] over a real SSH session.
final class SshScpChannel implements ScpChannel {
  const SshScpChannel(this._session);

  /// The remote `scp -f`: it reads [path] and sends it here.
  static Future<ScpChannel> source(SSHClient client, String path) async =>
      SshScpChannel(await client.execute('scp -f ${shellSingleQuote(path)}'));

  /// The remote `scp -t`: it takes what is sent and writes it to [path].
  static Future<ScpChannel> sink(SSHClient client, String path) async =>
      SshScpChannel(await client.execute('scp -t ${shellSingleQuote(path)}'));

  final SSHSession _session;

  @override
  Stream<Uint8List> get stdout => _session.stdout;

  @override
  Stream<Uint8List> get stderr => _session.stderr;

  @override
  void add(Uint8List data) => _session.stdin.add(data);

  @override
  Future<void> flush() => _session.flush();

  @override
  Future<void> closeInput() => _session.stdin.close();

  @override
  Future<int?> exitCode({Duration? timeout}) =>
      _session.waitForExit(timeout: timeout);

  @override
  void close() => _session.close();
}

/// What the far side said, once it is clear it will not be finishing.
///
/// The message is the remote's own — `scp: /etc/shadow: Permission denied` —
/// which is what makes `classifyFileError` able to recognise a refusal and
/// offer sudo, exactly as it does for an SFTP status code.
final class ScpException implements Exception {
  const ScpException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A file, streamed off a [ScpChannel.source].
///
/// [path] is what the channel was opened on and is used only to say where a
/// failure happened; the far side already knows which file it is sending.
///
/// [offset] is honoured by dropping the first bytes here rather than by asking
/// for them: the protocol has no way to start anywhere but at zero, and the
/// alternatives — `dd`, `tail -c` — are the kind of thing the hosts this
/// backend exists for are least likely to have. Nothing in the app resumes a
/// read today; a caller that starts to should know it costs the whole file.
Stream<List<int>> scpRead(
  ScpChannel channel,
  String path, {
  int offset = 0,
  Duration? timeout,
}) async* {
  final scp = _ScpSession(channel, timeout: timeout);
  try {
    // The source waits to be asked. Nothing arrives before this.
    await scp.sendAck();

    final size = await scp.readFileHeader();
    // Only now does the far side start sending the contents.
    await scp.sendAck();

    var remaining = size;
    var toDrop = offset > size ? size : offset;
    while (remaining > 0) {
      final chunk = await scp.read(remaining);
      if (chunk == null) {
        throw ScpException(
          'scp: $path: the connection ended $remaining bytes early',
        );
      }
      remaining -= chunk.length;
      if (toDrop >= chunk.length) {
        toDrop -= chunk.length;
        continue;
      }
      yield toDrop == 0 ? chunk : Uint8List.sublistView(chunk, toDrop);
      toDrop = 0;
    }

    // A status byte follows the contents, and it is where a read that failed
    // partway says so. Without it a truncated file would arrive looking whole.
    await scp.expectAck();
    await scp.sendAck();
    await scp.finish();
  } finally {
    scp.close();
  }
}

/// [data] onto a [ScpChannel.sink], as a file of exactly [size] bytes.
///
/// [size] is a contract here, unlike everywhere else in the app, and the reason
/// is in the protocol: the sink is told how many bytes to expect *before* they
/// start, and it reads that many and then looks for a status byte. A stream
/// that turns out to be longer or shorter is refused rather than sent, because
/// sending it would leave the far side reading file contents as protocol.
///
/// [mode] is what the file is created with, as the caller would pass it to
/// `chmod`: permission bits only.
Future<void> scpWrite(
  ScpChannel channel,
  String path,
  Stream<List<int>> data, {
  required int size,
  int mode = 0x1A4,
  Duration? timeout,
}) async {
  final scp = _ScpSession(channel, timeout: timeout);
  try {
    // The sink speaks first, unlike the source.
    await scp.expectAck();

    final header =
        'C${mode.toRadixString(8).padLeft(4, '0')} $size ${_headerName(path)}\n';
    // UTF-8 rather than ASCII: the name is a filename, and refusing to encode
    // one would fail an upload over a field neither side reads.
    await scp.send(Uint8List.fromList(utf8.encode(header)));
    await scp.expectAck();

    var sent = 0;
    // Bounded, because `timeout` otherwise covered only the half of this that
    // waits on the *far* side. A producer that opens the staging channel and
    // then stalls — a source backend reading from a link that went away — left
    // this waiting forever with a remote `scp -t` holding a staging file open,
    // and no amount of configured timeout applied to it. `Stream.timeout`
    // restarts on every event, so what it bounds is the gap between chunks
    // rather than the length of the transfer.
    final bounded = timeout == null ? data : data.timeout(timeout);
    await for (final chunk in bounded) {
      if (sent + chunk.length > size) {
        throw ScpException(
          'scp: $path: more than the $size bytes this transfer declared',
        );
      }
      if (chunk.isEmpty) continue;
      final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
      // In pieces, because every piece is followed by a flush and the flush is
      // what bounds how much of the file is in memory at once.
      for (var at = 0; at < bytes.length; at += _uploadChunkSize) {
        final end = at + _uploadChunkSize;
        await scp.send(
          Uint8List.sublistView(
            bytes,
            at,
            end > bytes.length ? bytes.length : end,
          ),
        );
      }
      sent += chunk.length;
    }
    if (sent != size) {
      throw ScpException(
        'scp: $path: $sent bytes for a transfer that declared $size',
      );
    }

    // The end of the file's contents, and what the sink waits for before it
    // closes the file it has been writing.
    await scp.sendAck();
    await scp.expectAck();
    await scp.finish();
  } finally {
    scp.close();
  }
}

const _uploadChunkSize = 32 * 1024;

/// Stop reading ahead once this much is waiting to be consumed, and start
/// again once it has been. The window the far side is given follows from it.
const _readHighWater = 512 * 1024;

/// The name in a `C` header, which the far side is entitled to reject.
///
/// It is only used when the destination is a directory, and this backend never
/// writes to one — every path it hands over names the file itself. So the name
/// carries no information, and the only thing that matters about it is that a
/// separator or a newline in the destination's own name cannot be read as
/// protocol. OpenSSH refuses those outright, which would fail an upload over
/// a field neither side reads.
String _headerName(String path) {
  final slash = path.lastIndexOf('/');
  final base = slash < 0 ? path : path.substring(slash + 1);
  final safe = base.replaceAll(RegExp(r'[/\r\n]'), '_');
  return safe.isEmpty ? 'file' : safe;
}

/// One `scp` conversation, and the bytes going each way.
///
/// The reading side is pull-based: the channel is read ahead of what has been
/// asked for, up to [_readHighWater], and paused past it. Without that the far
/// side sends as fast as the window allows and this device holds the difference
/// — which for a download is the whole file.
final class _ScpSession {
  _ScpSession(this._channel, {this.timeout}) {
    _stdout = _channel.stdout.listen(
      _onData,
      onDone: _onDone,
      onError: _onError,
    );
    // Drained rather than left unread, and kept: `scp` explains itself here
    // when it fails before it can say anything in the protocol — a missing
    // binary, a shell profile that printed something. Bounded, because it is
    // an error message and not an output stream.
    _channel.stderr.listen((data) {
      if (_stderr.length < _maxStderr) _stderr.add(data);
    });
  }

  final ScpChannel _channel;

  /// How long any one step may wait. Null waits forever, which is right inside
  /// a transfer that shows its own progress.
  final Duration? timeout;

  late final StreamSubscription<Uint8List> _stdout;

  final _chunks = Queue<Uint8List>();

  /// How far into the head of [_chunks] the reader has got.
  var _head = 0;

  var _buffered = 0;

  var _paused = false;

  var _eof = false;

  Object? _failure;

  Completer<void>? _waiting;

  final _stderr = BytesBuilder(copy: false);

  static const _maxStderr = 8 * 1024;

  static const _maxControlLine = 4 * 1024;

  void _onData(Uint8List data) {
    if (data.isNotEmpty) {
      _chunks.add(data);
      _buffered += data.length;
      if (_buffered >= _readHighWater && !_paused) {
        _paused = true;
        _stdout.pause();
      }
    }
    _wake();
  }

  void _onDone() {
    _eof = true;
    _wake();
  }

  void _onError(Object error) {
    _failure ??= error;
    _eof = true;
    _wake();
  }

  void _wake() {
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }

  /// Waits until there is something to read, or until there never will be.
  Future<void> _fill() async {
    while (_buffered == 0 && !_eof) {
      final waiting = _waiting ??= Completer<void>();
      final bound = timeout;
      await (bound == null
          ? waiting.future
          : waiting.future.timeout(
              bound,
              onTimeout: () => throw TimeoutException(
                'scp timed out waiting for the remote side',
                bound,
              ),
            ));
    }
    final failure = _failure;
    if (failure != null) throw ScpException('scp: $failure');
  }

  void _consumed(int count) {
    _buffered -= count;
    if (_paused && _buffered < _readHighWater) {
      _paused = false;
      _stdout.resume();
    }
  }

  /// The next bytes, at most [max] of them, or null once there are no more.
  Future<Uint8List?> read(int max) async {
    await _fill();
    if (_buffered == 0) return null;
    final chunk = _chunks.first;
    final available = chunk.length - _head;
    final take = available < max ? available : max;
    final out = Uint8List.sublistView(chunk, _head, _head + take);
    _head += take;
    if (_head == chunk.length) {
      _chunks.removeFirst();
      _head = 0;
    }
    _consumed(take);
    return out;
  }

  Future<int?> _readByte() async {
    final byte = await read(1);
    return byte == null ? null : byte[0];
  }

  /// Everything up to the next newline, which the protocol ends its control
  /// messages with. The newline is consumed and not returned.
  Future<String> _readLine() async {
    final out = BytesBuilder(copy: false);
    while (true) {
      final byte = await _readByte();
      if (byte == null || byte == 0x0A) break;
      out.addByte(byte);
      if (out.length >= _maxControlLine) {
        // Not returned as if it were a line. Stopping quietly at the limit
        // leaves the rest of the header in the stream, where the bytes after
        // it are then read as file contents — a transfer that arrives shifted
        // rather than one that fails.
        throw ScpException(
          'scp: a control line ran past $_maxControlLine bytes without ending',
        );
      }
    }
    return utf8.decode(out.takeBytes(), allowMalformed: true);
  }

  /// `\0`: the one-byte "go on" both ends send.
  Future<void> sendAck() => send(Uint8List(1));

  Future<void> send(Uint8List bytes) async {
    _channel.add(bytes);
    final flush = _channel.flush();
    final bound = timeout;
    await (bound == null
        ? flush
        : flush.timeout(
            bound,
            onTimeout: () => throw TimeoutException(
              'scp timed out sending to the remote side',
              bound,
            ),
          ));
  }

  /// Reads the far side's answer to something this side did.
  Future<void> expectAck() async {
    final byte = await _readByte();
    if (byte == 0) return;
    if (byte == null) throw ScpException(await _endedEarly());
    throw ScpException(await _controlError(byte));
  }

  /// The `C<mode> <size> <name>` line, and the size out of it.
  ///
  /// Anything else is a failure to report rather than a shape to handle: `D`
  /// is a directory, which is only sent for a recursive transfer this never
  /// asks for, and `E` ends one.
  Future<int> readFileHeader() async {
    var byte = await _readByte();
    // `T` carries times and only ever precedes the `C` line, and only when the
    // far side was asked to preserve them. Skipped rather than refused, since
    // a server is free to volunteer it.
    while (byte == 0x54) {
      await _readLine();
      await sendAck();
      byte = await _readByte();
    }
    if (byte == null) throw ScpException(await _endedEarly());
    if (byte != 0x43) throw ScpException(await _controlError(byte));

    final line = await _readLine();
    // `<mode> <size> <name>`, and the name may contain spaces, so the split is
    // bounded rather than complete.
    final firstSpace = line.indexOf(' ');
    final secondSpace = firstSpace < 0 ? -1 : line.indexOf(' ', firstSpace + 1);
    final size = secondSpace < 0
        ? null
        : int.tryParse(line.substring(firstSpace + 1, secondSpace));
    // Every field, not only the one that gets used. A login banner or a
    // `.profile` that echoes something arrives in this stream ahead of the
    // protocol, and a line of it starting with `C` that happens to carry a
    // number between two spaces was taken for a header — after which that many
    // bytes of the banner are read as the file's contents and the transfer
    // arrives looking whole. An `scp` header has an octal mode and a name.
    if (size == null ||
        size < 0 ||
        !_fileMode.hasMatch(line.substring(0, firstSpace)) ||
        secondSpace + 1 >= line.length) {
      throw ScpException('scp: unreadable file header: C$line');
    }
    return size;
  }

  /// `0644`, as `scp` writes it: `%04o` of the permission bits.
  static final _fileMode = RegExp(r'^[0-7]{4,5}$');

  /// What a non-zero control byte means, as a message worth showing.
  ///
  /// `\x01` is a warning and `\x02` is fatal; both are followed by a line of
  /// text, and for this app's purposes the difference does not matter — a
  /// warning here means the file did not come across.
  Future<String> _controlError(int byte) async {
    if (byte == 0x01 || byte == 0x02) {
      final message = (await _readLine()).trim();
      if (message.isNotEmpty) return message;
      return 'scp reported an error without saying what';
    }
    // Not protocol at all. Almost always a login shell that prints a banner or
    // a `.profile` that echoes something, which lands in the stream ahead of
    // everything scp says and makes the rest unreadable.
    final text = String.fromCharCode(byte) + await _readLine();
    return 'scp: unexpected reply: ${text.trim()}';
  }

  Future<String> _endedEarly() async {
    final said = utf8.decode(_stderr.toBytes(), allowMalformed: true).trim();
    if (said.isNotEmpty) return said;
    final code = await _channel.exitCode(timeout: _exitWait);
    // 127 is what a shell answers for a command it could not find, which for
    // this backend is the failure worth naming: the host has no `scp`.
    if (code == 127) return 'scp: not found on the remote host';
    return 'scp: the remote side closed the connection'
        '${code == null ? '' : ' (exit $code)'}';
  }

  /// Closes this side and waits for `scp` to report how it went.
  Future<void> finish() async {
    // Bounded like every other step, and by the same fallback as the wait
    // below rather than by [timeout], which may be null. Sending EOF is a
    // write like any other — a peer that has stopped reading its stdin leaves
    // it pending — and it was the one step of a transfer no configured timeout
    // reached, so a stall here held the channel, the remote `scp` and the
    // staged destination for as long as the process lived.
    final bound = timeout ?? _exitWait;
    await _channel.closeInput().timeout(
      bound,
      onTimeout: () => throw TimeoutException(
        'scp timed out closing the remote side\'s input',
        bound,
      ),
    );
    // Bounded here rather than by [ScpChannel.exitCode]'s own `timeout`, which
    // answers *null* when it expires — the same null the contract uses for a
    // host that reports no exit status at all. The two are not the same thing
    // and this is where the difference matters: a remote `scp` that took the
    // last acknowledgement and then never exited was read as one of those
    // silent hosts, and the transfer was reported finished. Asked without a
    // bound the future completes when the channel closes, so a host that
    // simply sends no status still answers at once.
    final int? code;
    try {
      code = await _channel.exitCode().timeout(bound);
    } on TimeoutException {
      throw ScpException('scp: the remote side never finished');
    }
    if (code != null && code != 0) {
      final said = utf8.decode(_stderr.toBytes(), allowMalformed: true).trim();
      throw ScpException(said.isNotEmpty ? said : 'scp exited with $code');
    }
  }

  /// How long to wait for an exit status that is only ever used to explain a
  /// failure. Bounded on its own rather than by [timeout], which may be null.
  static const _exitWait = Duration(seconds: 10);

  void close() {
    _stdout.cancel().ignore();
    _channel.close();
  }
}
