import 'dart:convert';
import 'dart:typed_data';

import 'package:xterm/core.dart';

/// Normalizes the terminal byte stream carried by tmux `%output`.
///
/// This is deliberately a stream parser rather than a list of ad-hoc string
/// replacements. tmux may split any escape sequence across `%output` events,
/// and pane programs may use screen/tmux private sequences which the outer
/// xterm parser does not understand. The parser keeps partial sequences until
/// they are complete, then passes, translates, or suppresses the whole
/// sequence by category.
final class TmuxOutputNormalizer {
  /// Called for an escape final byte which the outer terminal is not known to
  /// support. The byte pair is consumed instead of being printed as text.
  void Function(String escape)? onUnknownEscape;

  /// Called for a pane's program status report, progress bar or shell
  /// integration mark (OSC 7501, OSC 9;4, OSC 133), which is then taken out of
  /// the stream. While null they pass through to xterm.
  ///
  /// The pane is the terminal these belong to, not the local xterm: it shows
  /// one pane after another, each replay starting with a full reset.
  void Function(TerminalStatusEvent event)? onStatus;

  static const _maxControlBytes = 4 * 1024;
  static const _maxPayloadBytes = 2 * 1024 * 1024;

  _ParserState _state = _ParserState.data;
  final List<int> _control = [];
  final List<int> _payload = [];
  bool _waitingForStringTerminator = false;
  bool _overflowed = false;

  /// Feeds one CC `%output` chunk and returns the bytes safe for local xterm.
  Uint8List call(List<int> data) {
    final output = <int>[];
    for (final byte in data) {
      _feed(byte, output);
    }
    return Uint8List.fromList(output);
  }

  /// Discards an incomplete sequence at a pane or replay boundary.
  ///
  /// Unlike [close], this deliberately does not flush: bytes from a previous
  /// pane must not consume the new pane's reset or captured screen.
  void reset() {
    _reset();
  }

  /// Flushes an unterminated sequence when the pane stream ends.
  ///
  /// A malformed or truncated sequence is passed through rather than dropped:
  /// once the stream has ended it can no longer consume future bytes, and
  /// dropping user output would turn a parser bug into data loss.
  Uint8List close() {
    if (_state == _ParserState.data) return Uint8List(0);

    final flushed = <int>[
      ..._control,
      if (_state == _ParserState.csi) ...const <int>[],
      ..._payload,
      if (_waitingForStringTerminator) 0x1b,
    ];
    _reset();
    return Uint8List.fromList(flushed);
  }

  void _feed(int byte, List<int> output) {
    switch (_state) {
      case _ParserState.escapeIntermediate:
        _consumeEscapeIntermediate(byte, output);
      case _ParserState.data:
        if (byte == 0x1b) {
          _control
            ..clear()
            ..add(byte);
          _payload.clear();
          _state = _ParserState.escape;
          return;
        }
        output.add(byte);
      case _ParserState.escape:
        _consumeEscapeFinal(byte, output);
      case _ParserState.csi:
        _consumeCsi(byte, output);
      case _ParserState.osc:
      case _ParserState.dcs:
      case _ParserState.sos:
      case _ParserState.pm:
      case _ParserState.apc:
      case _ParserState.tmuxTitle:
        _consumeStringControl(byte, output);
    }
  }

  void _consumeEscapeFinal(int byte, List<int> output) {
    if (byte == 0x1b) {
      // ESC ESC is two escape introducers, not one two-byte sequence.
      output.add(_control.first);
      _control
        ..clear()
        ..add(byte);
      return;
    }

    _control.add(byte);
    switch (byte) {
      case 0x5b: // [
        _state = _ParserState.csi;
      case 0x5d: // ]
        _beginString(_ParserState.osc);
      case 0x50: // P
        _beginString(_ParserState.dcs);
      case 0x58: // X
        _beginString(_ParserState.sos);
      case 0x5e: // ^
        _beginString(_ParserState.pm);
      case 0x5f: // _
        _beginString(_ParserState.apc);
      case 0x6b: // k
        _beginString(_ParserState.tmuxTitle);
      case >= 0x20 && <= 0x2f:
        // ESC SP F, ESC # 8, ESC % G, ESC ( B, ...: intermediates, then the
        // final byte which belongs to the same sequence.
        _state = _ParserState.escapeIntermediate;
      case 0x36: // DECBI
      case 0x37: // DECSC
      case 0x38: // DECRC
      case 0x39: // DECFI
      case 0x44: // IND
      case 0x45: // NEL
      case 0x48: // HTS
      case 0x4d: // RI
      case 0x4e: // SS2
      case 0x4f: // SS3
      case 0x5a: // DECID
      case 0x5c: // ST
      case 0x63: // RIS
      case 0x3c: // Exit VT52 mode
      case 0x3d: // Enter keypad mode
      case 0x3e: // Exit keypad mode
        output.addAll(_control);
        _reset();
      default:
        // Unknown escape introducers are consumed as a unit. xterm's fallback
        // for an unknown ESC final prints following payload as text, which is
        // how `ESC k<title>ST` previously became `echo1` and `vim%`.
        onUnknownEscape?.call(_escapeName(byte));
        _reset();
    }
  }

  void _consumeEscapeIntermediate(int byte, List<int> output) {
    if (byte >= 0x20 && byte <= 0x2f) {
      if (_control.length >= _maxControlBytes) {
        _reset();
        return;
      }
      _control.add(byte);
      return;
    }
    if (byte >= 0x30 && byte <= 0x7e) {
      output
        ..addAll(_control)
        ..add(byte);
      _reset();
      return;
    }
    // Not a final byte: replay what was held, as the CSI state does.
    final incomplete = List<int>.of(_control);
    _reset();
    output.addAll(incomplete);
    _feed(byte, output);
  }

  void _beginString(_ParserState state) {
    _payload.clear();
    _state = state;
    _waitingForStringTerminator = false;
  }

  void _consumeCsi(int byte, List<int> output) {
    // A CSI sequence consists of parameter bytes, optional intermediate bytes,
    // then one final byte. Anything else aborts the sequence and is replayed
    // through the data state so an unexpected ESC can still start a new one.
    final isParameter = byte >= 0x30 && byte <= 0x3f;
    final isIntermediate = byte >= 0x20 && byte <= 0x2f;
    final isFinal = byte >= 0x40 && byte <= 0x7e;

    if (_overflowed) {
      if (isFinal) _reset();
      return;
    }

    if (isFinal) {
      if (_control.length < _maxControlBytes) {
        _control.add(byte);
      }
      if (!_isTerminalQuery(_control)) {
        output.addAll(_control);
      }
      _reset();
      return;
    }

    if (!isParameter && !isIntermediate) {
      final incomplete = List<int>.of(_control);
      _reset();
      output.addAll(incomplete);
      _feed(byte, output);
      return;
    }

    if (_control.length >= _maxControlBytes) {
      _overflowed = true;
      return;
    }
    _control.add(byte);
  }

  void _consumeStringControl(int byte, List<int> output) {
    if (_waitingForStringTerminator) {
      _waitingForStringTerminator = false;
      if (byte == 0x5c) {
        _finishStringControl(output);
        return;
      }

      // An ESC not followed by `\\` is data inside this malformed string. Keep
      // it and continue waiting for the real terminator.
      if (!_appendPayload(0x1b)) return;
      if (!_appendPayload(byte)) return;
      return;
    }

    if (byte == 0x07 && _state != _ParserState.dcs) {
      _finishStringControl(output, bell: true);
      return;
    }
    if (byte == 0x1b) {
      _waitingForStringTerminator = true;
      return;
    }
    _appendPayload(byte);
  }

  bool _appendPayload(int byte) {
    if (_payload.length >= _maxPayloadBytes) {
      _overflowed = true;
      return false;
    }
    _payload.add(byte);
    return true;
  }

  void _finishStringControl(List<int> output, {bool bell = false}) {
    if (_overflowed) {
      _reset();
      return;
    }
    final state = _state;
    final payload = List<int>.of(_payload);
    _reset();

    switch (state) {
      case _ParserState.tmuxTitle:
        // screen/tmux's `ESC k title ST` is equivalent to OSC 0. Translate it
        // rather than discarding the title semantics.
        output
          ..addAll([0x1b, 0x5d, 0x30, 0x3b])
          ..addAll(payload);
        if (bell) {
          output.add(0x07);
        } else {
          output
            ..add(0x1b)
            ..add(0x5c);
        }
      case _ParserState.dcs:
        if (_isDcsQuery(payload)) return;
        _finishDcs(payload, output);
      case _ParserState.osc:
        if (_isOscQuery(payload)) return;
        if (_takeStatus(payload)) return;
        output
          ..addAll(_introducerFor(state))
          ..addAll(payload);
        if (bell) {
          output.add(0x07);
        } else {
          output
            ..add(0x1b)
            ..add(0x5c);
        }
      default:
        output
          ..addAll(_introducerFor(state))
          ..addAll(payload);
        if (bell) {
          output.add(0x07);
        } else {
          output
            ..add(0x1b)
            ..add(0x5c);
        }
    }
  }

  void _finishDcs(List<int> payload, List<int> output) {
    const prefix = [0x74, 0x6d, 0x75, 0x78, 0x3b]; // "tmux;"
    if (!_startsWith(payload, prefix)) {
      output
        ..addAll([0x1b, 0x50])
        ..addAll(payload)
        ..addAll([0x1b, 0x5c]);
      return;
    }

    // tmux passthrough wraps a complete inner terminal sequence. Unwrap it and
    // normalize that sequence through the same rules instead of letting xterm
    // swallow the whole DCS as an unsupported string. tmux doubles every ESC
    // inside the payload; each pair is one ESC of the inner sequence.
    final inner = payload.sublist(prefix.length);
    for (var i = 0; i < inner.length; i++) {
      final byte = inner[i];
      if (byte == 0x1b && i + 1 < inner.length && inner[i + 1] == 0x1b) i++;
      _feed(byte, output);
    }
  }

  bool _isTerminalQuery(List<int> sequence) {
    if (sequence.length < 3 || sequence[0] != 0x1b || sequence[1] != 0x5b) {
      return false;
    }

    var at = 2;
    String? prefix;
    if (sequence[at] == 0x3e || sequence[at] == 0x3d || sequence[at] == 0x3f) {
      prefix = String.fromCharCode(sequence[at]);
      at++;
    }

    var parameterEnd = at;
    while (parameterEnd < sequence.length - 1) {
      final byte = sequence[parameterEnd];
      if (byte < 0x30 || byte > 0x3f) break;
      parameterEnd++;
    }
    final parameters = String.fromCharCodes(
      sequence.getRange(at, parameterEnd),
    );
    final finalByte = sequence.last;

    final isAttributesQuery =
        finalByte == 0x63 &&
        (prefix == null || prefix == '>' || prefix == '=') &&
        (parameters.isEmpty || parameters == '0');
    final isStatusQuery =
        finalByte == 0x6e &&
        (prefix == null || prefix == '?') &&
        (parameters == '5' || parameters == '6');
    final firstParameter = parameters.split(';').first;
    final isWindowOrTextSizeQuery =
        finalByte == 0x74 &&
        prefix == null &&
        const {
          '14',
          '16',
          '18',
          '19',
          '20',
          '21',
          '22',
        }.contains(firstParameter);
    final isKeyboardQuery =
        finalByte == 0x75 && prefix == '?' && parameters.isEmpty;
    return isAttributesQuery ||
        isStatusQuery ||
        isWindowOrTextSizeQuery ||
        isKeyboardQuery;
  }

  bool _isOscQuery(List<int> payload) {
    if (payload.isEmpty) return false;
    final text = latin1.decode(payload, allowInvalid: true);
    final separator = text.indexOf(';');
    final code = separator < 0 ? text : text.substring(0, separator);
    final value = separator < 0 ? '' : text.substring(separator + 1);
    if (const {'10', '11', '12'}.contains(code)) {
      return value.isEmpty || value.trim() == '?';
    }
    if (code == '4') {
      return value.split(';').any((item) => item.trim() == '?');
    }
    // Its answer would reach the pane after tmux has answered the DA that
    // follows it, which is how a program tells there is no support, and would
    // land in the input of whatever runs there by then.
    if (code == ProgramStatusReport.oscCode) return value == '?';
    // OSC 52 is handled by TerminalSession: set requests write the system
    // clipboard and query requests are ignored.
    return false;
  }

  bool _takeStatus(List<int> payload) {
    final onStatus = this.onStatus;
    if (onStatus == null) return false;
    final fields = utf8.decode(payload, allowMalformed: true).split(';');
    final event = TerminalStatusEvent.fromOsc(fields.first, fields.sublist(1));
    if (event == null) return false;
    onStatus(event);
    return true;
  }

  bool _isDcsQuery(List<int> payload) {
    if (payload.length < 2) return false;
    final first = payload[0];
    final second = payload[1];
    return (first == 0x2b && second == 0x71) || // XTGETTCAP: +q
        (first == 0x24 && second == 0x71); // DECRQSS: $q
  }

  List<int> _introducerFor(_ParserState state) {
    final finalByte = switch (state) {
      _ParserState.osc => 0x5d,
      _ParserState.dcs => 0x50,
      _ParserState.sos => 0x58,
      _ParserState.pm => 0x5e,
      _ParserState.apc => 0x5f,
      _ParserState.tmuxTitle => 0x6b,
      _ => throw StateError('not a string control: $state'),
    };
    return [0x1b, finalByte];
  }

  void _reset() {
    _state = _ParserState.data;
    _control.clear();
    _payload.clear();
    _waitingForStringTerminator = false;
    _overflowed = false;
  }

  String _escapeName(int byte) {
    final hex = byte.toRadixString(16).padLeft(2, '0').toUpperCase();
    return 'ESC 0x$hex';
  }

  bool _startsWith(List<int> value, List<int> prefix) {
    if (value.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (value[i] != prefix[i]) return false;
    }
    return true;
  }
}

enum _ParserState {
  data,
  escape,
  escapeIntermediate,
  csi,
  osc,
  dcs,
  sos,
  pm,
  apc,
  tmuxTitle,
}
