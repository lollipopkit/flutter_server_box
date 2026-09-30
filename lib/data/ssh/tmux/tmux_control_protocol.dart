import 'dart:convert';
import 'dart:typed_data';

import 'package:server_box/data/ssh/tmux/tmux_ids.dart';

/// Thrown when a tmux control-mode stream exceeds a protocol size limit.
final class TmuxControlProtocolOverflow implements Exception {
  final String description;
  final int limit;

  const TmuxControlProtocolOverflow(this.description, this.limit);

  @override
  String toString() => 'tmux control-mode $description exceeded $limit bytes';
}

/// A completed answer from the tmux control-mode command queue.
final class TmuxControlCommandResult {
  final List<String> lines;
  final bool error;

  const TmuxControlCommandResult({required this.lines, required this.error});

  String get output => lines.join('\n');

  @override
  String toString() => error ? 'tmux error: $output' : output;
}

/// One event decoded from a `tmux -CC` stream.
sealed class TmuxControlProtocolEvent {
  const TmuxControlProtocolEvent();
}

/// `%begin ... %end` or `%begin ... %error`.
final class TmuxControlProtocolCommandResult extends TmuxControlProtocolEvent {
  final TmuxControlCommandResult result;

  const TmuxControlProtocolCommandResult(this.result);
}

/// `%output <pane-id> <escaped bytes>`.
final class TmuxControlProtocolOutput extends TmuxControlProtocolEvent {
  final TmuxPaneId paneId;
  final Uint8List data;

  const TmuxControlProtocolOutput(this.paneId, this.data);
}

/// Any asynchronous `%notification args...` line.
final class TmuxControlProtocolNotification extends TmuxControlProtocolEvent {
  final String name;
  final List<String> args;

  const TmuxControlProtocolNotification(this.name, this.args);

  @override
  String toString() => '%$name ${args.join(' ')}'.trim();
}

final class _CommandBlock {
  final String time;
  final String number;
  final String flags;
  final List<String> lines = [];

  _CommandBlock(this.time, this.number, this.flags);
}

/// Incremental parser for tmux control mode.
///
/// The parser works on bytes rather than strings because `%output` may contain
/// pane bytes which are not valid UTF-8. Protocol framing itself is ASCII;
/// pane output is escaped by tmux before it reaches this parser.
final class TmuxControlProtocolParser {
  static const _handshake = [0x1b, 0x50, 0x31, 0x30, 0x30, 0x30, 0x70];
  static const _terminator = [0x1b, 0x5c];
  static const _maxLineBytes = 64 * 1024;
  static const _maxBlockBytes = 1024 * 1024;

  final List<int> _line = [];
  int _handshakeIndex = 0;
  int _blockBytes = 0;
  bool _handshakeSeen = false;
  bool _escaped = false;
  bool _terminated = false;
  _CommandBlock? _block;

  bool get handshakeSeen => _handshakeSeen;
  bool get terminated => _terminated;

  /// Feeds one chunk and returns every complete protocol event in it.
  List<TmuxControlProtocolEvent> push(List<int> data) {
    final events = <TmuxControlProtocolEvent>[];
    for (final byte in data) {
      if (!_handshakeSeen) {
        // Some PTY wrappers emit a small preamble before tmux's DCS handshake.
        // Scan until the handshake rather than rejecting the stream on the
        // first non-matching byte; once the handshake arrives, protocol
        // parsing remains strict.
        if (!_consumeHandshakeByte(byte)) continue;
        continue;
      }
      if (_terminated) break;

      if (_escaped) {
        _escaped = false;
        if (_block == null && byte == _terminator[1]) {
          _flushLine(events);
          _terminated = true;
          continue;
        }
        // Raw escapes can occur in command output such as `capture-pane -e`.
        // Outside a block, ESC \\ is tmux's terminating ST sequence.
        _appendLineByte(_terminator[0]);
        if (byte == 0x0a) {
          // A trailing ESC does not take the line boundary with it.
          _flushLine(events);
        } else if (byte == _terminator[0]) {
          _escaped = true;
        } else {
          _appendLineByte(byte);
        }
        continue;
      }

      if (byte == _terminator[0]) {
        _escaped = true;
        continue;
      }
      if (byte == 0x0a) {
        _flushLine(events);
        continue;
      }
      _appendLineByte(byte);
    }
    return events;
  }

  /// Finishes a stream which ended without tmux's terminating ST sequence.
  List<TmuxControlProtocolEvent> close() {
    if (_handshakeSeen && !_terminated && _line.isNotEmpty) {
      final events = <TmuxControlProtocolEvent>[];
      _flushLine(events);
      return events;
    }
    return const [];
  }

  bool _consumeHandshakeByte(int byte) {
    if (byte == _handshake[_handshakeIndex]) {
      _handshakeIndex++;
      if (_handshakeIndex == _handshake.length) {
        _handshakeSeen = true;
        _handshakeIndex = 0;
      }
      return true;
    }

    // Permit a partial match to restart at this byte. The sequence is short
    // and starts with ESC, so this does not need a general stream search.
    if (byte == _handshake[0]) {
      _handshakeIndex = 1;
    } else {
      _handshakeIndex = 0;
    }
    return false;
  }

  void _appendLineByte(int byte) {
    if (_line.length >= _maxLineBytes) {
      throw const TmuxControlProtocolOverflow('line', _maxLineBytes);
    }
    _line.add(byte);
  }

  void _flushLine(List<TmuxControlProtocolEvent> events) {
    final lineLength = _line.length;
    var bytes = Uint8List.fromList(_line);
    _line.clear();
    if (_block != null) {
      // The line feed counts too: a block of empty lines holds one list entry
      // per line, and would otherwise never reach the limit.
      if (_blockBytes + lineLength + 1 > _maxBlockBytes) {
        throw const TmuxControlProtocolOverflow(
          'command block',
          _maxBlockBytes,
        );
      }
      _blockBytes += lineLength + 1;
    }
    if (bytes.isEmpty) {
      // An empty CRLF line inside a command block is capture output, not a
      // blank protocol separator; keep it so blank pane rows survive.
      if (_block != null) _block!.lines.add('');
      return;
    }
    if (bytes.last == 0x0d) {
      bytes = bytes.sublist(0, bytes.length - 1);
      if (bytes.isEmpty) {
        if (_block != null) _block!.lines.add('');
        return;
      }
    }
    _parseLine(bytes, events);
  }

  void _parseLine(Uint8List bytes, List<TmuxControlProtocolEvent> events) {
    final line = latin1.decode(bytes);
    if (_block case final block?) {
      // tmux repeats the complete begin guard on the matching end guard. Pane
      // capture can contain a line with the same shape, so shape alone is not
      // evidence that a command block ended.
      final guard = _parseGuard(line, '%end');
      if (_isGuardFor(guard, block)) {
        events.add(
          TmuxControlProtocolCommandResult(
            TmuxControlCommandResult(lines: block.lines, error: false),
          ),
        );
        _block = null;
        _blockBytes = 0;
        return;
      }
      final errorGuard = _parseGuard(line, '%error');
      if (_isGuardFor(errorGuard, block)) {
        events.add(
          TmuxControlProtocolCommandResult(
            TmuxControlCommandResult(lines: block.lines, error: true),
          ),
        );
        _block = null;
        _blockBytes = 0;
        return;
      }
      block.lines.add(utf8.decode(bytes, allowMalformed: true));
      return;
    }

    if (_parseGuard(line, '%begin') case final begin?) {
      _block = _CommandBlock(begin[0], begin[1], begin[2]);
      _blockBytes = 0;
      return;
    }
    if (line.isEmpty || !line.startsWith('%')) return;

    final firstSpace = line.indexOf(' ');
    final name = firstSpace < 0
        ? line.substring(1)
        : line.substring(1, firstSpace);
    if (name == 'output') {
      final output = _parseOutputLine(bytes, extended: false);
      if (output != null) events.add(output);
      return;
    }
    if (name == 'extended-output') {
      final output = _parseOutputLine(bytes, extended: true);
      if (output != null) events.add(output);
      return;
    }

    final args = firstSpace < 0
        ? const <String>[]
        : line.substring(firstSpace + 1).split(' ');
    events.add(TmuxControlProtocolNotification(name, args));
  }

  List<String>? _parseGuard(String line, String prefix) {
    if (!line.startsWith(prefix)) return null;
    final args = line.substring(prefix.length).trim().split(' ');
    if (args.length != 3) return null;
    return args;
  }

  bool _isGuardFor(List<String>? guard, _CommandBlock block) {
    if (guard == null) return false;
    return guard[0] == block.time &&
        guard[1] == block.number &&
        guard[2] == block.flags;
  }

  TmuxControlProtocolOutput? _parseOutputLine(
    Uint8List bytes, {
    required bool extended,
  }) {
    final line = latin1.decode(bytes);
    final firstSpace = line.indexOf(' ');
    if (firstSpace < 0) return null;
    final secondSpace = line.indexOf(' ', firstSpace + 1);
    if (secondSpace < 0) return null;
    final paneId = TmuxPaneId.tryParse(
      line.substring(firstSpace + 1, secondSpace),
    );
    if (paneId == null) return null;

    // `%extended-output` is `pane-id age ... : value`; the colon is a complete
    // argument, not the first byte of the value. Future arguments between age
    // and that colon must be ignored rather than printed.
    final valueStart = extended
        ? line.indexOf(' : ', secondSpace + 1) + 3
        : secondSpace + 1;
    if (valueStart < 3) return null;
    final value = decodeOutputValue(bytes.sublist(valueStart));
    return TmuxControlProtocolOutput(paneId, value);
  }

  /// Decodes tmux's octal escaping in `%output`.
  ///
  /// A backslash followed by three octal digits is one byte. Every other
  /// backslash is passed through unchanged; malformed input is pane data, not
  /// a reason to drop it.
  static Uint8List decodeOutputValue(List<int> bytes) {
    final out = BytesBuilder(copy: true);
    for (var i = 0; i < bytes.length; i++) {
      final byte = bytes[i];
      if (byte != 0x5c || i + 3 >= bytes.length) {
        out.addByte(byte);
        continue;
      }
      var value = 0;
      for (var j = i + 1; j <= i + 3; j++) {
        final digit = bytes[j] - 0x30;
        // Digits only: `int.parse` would also take a sign.
        if (digit < 0 || digit > 7) {
          value = -1;
          break;
        }
        value = value * 8 + digit;
      }
      if (value < 0 || value > 0xff) {
        out.addByte(byte);
        continue;
      }
      out.addByte(value);
      i += 3;
    }
    return out.takeBytes();
  }
}
