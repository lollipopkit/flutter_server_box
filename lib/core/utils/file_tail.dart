import 'dart:convert';
import 'dart:io';

/// What a file somebody else is still writing to has said so far.
///
/// Written for the iOS guest, whose commands send their two streams to files
/// because the console they would otherwise share is a pseudo-terminal — see
/// `IshExec`. Kept here rather than beside it because none of this is iOS's:
/// it is a file, an offset, and the one thing that makes reading a growing file
/// different from reading a finished one.
///
/// That one thing is [_incompleteTail]. A read can land in the middle of a
/// multi-byte character, and decoding what arrived would put a replacement
/// character on this side and leave the next read starting mid-character. So
/// the trailing bytes of an unfinished character are held back for the next
/// poll, and [finish] is what gives up on one that never completed.
class FileTail {
  FileTail(this.file, this.onChunk);

  final File file;
  final void Function(String chunk)? onChunk;

  final _text = StringBuffer();

  /// Bytes read but not yet decoded, because they end mid-character.
  final _pending = <int>[];

  var _offset = 0;

  /// Everything decoded so far, including anything [adopt]ed.
  String get text => _text.toString();

  /// Adds text that did not come from the file.
  ///
  /// The iOS guest has one: what a command wrote to its terminal rather than
  /// to the file, which is where a shell puts its complaint if the redirect
  /// into that file is what failed.
  void adopt(String text) => _text.write(text);

  /// Reads whatever has been appended since the last call.
  Future<void> poll() async {
    RandomAccessFile? handle;
    try {
      handle = await file.open();
      final length = await handle.length();
      if (length <= _offset) return;
      await handle.setPosition(_offset);
      _pending.addAll(await handle.read(length - _offset));
      _offset = length;
    } on FileSystemException {
      // Not there yet, or not there at all — a command that never ran leaves
      // no file behind, and that is an answer rather than a failure.
      return;
    } finally {
      await handle?.close();
    }
    _emit(keepIncomplete: true);
  }

  /// Everything left, including a character whose rest never arrived.
  void finish() => _emit(keepIncomplete: false);

  void _emit({required bool keepIncomplete}) {
    if (_pending.isEmpty) return;
    final keep = keepIncomplete ? _incompleteTail(_pending) : 0;
    final ready = _pending.length - keep;
    if (ready == 0) return;
    final chunk = utf8.decode(_pending.sublist(0, ready), allowMalformed: true);
    _pending.removeRange(0, ready);
    _text.write(chunk);
    onChunk?.call(chunk);
  }
}

/// How many trailing bytes begin a character whose rest has not arrived.
///
/// Zero for anything that ends on a character boundary, which is every read
/// that lands between two of them and all of ASCII.
int _incompleteTail(List<int> bytes) {
  // Four, because that is the longest a UTF-8 character gets: a fifth byte
  // back cannot be the start of one that is still unfinished.
  for (var back = 1; back <= 4 && back <= bytes.length; back++) {
    final byte = bytes[bytes.length - back];
    // A character by itself, so nothing after it is waiting.
    if (byte < 0x80) return 0;
    if (byte >= 0xc0) {
      final needed = byte >= 0xf0
          ? 4
          : byte >= 0xe0
          ? 3
          : 2;
      return needed > back ? back : 0;
    }
    // A continuation byte; whatever it continues started further back.
  }
  return 0;
}
