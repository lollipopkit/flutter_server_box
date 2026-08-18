import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/file_tail.dart';

/// How the Agent's output arrives on iOS, where a command's two streams go to
/// files rather than to the pseudo-terminal its session runs on.
///
/// Worth a test of its own because the rest of that path needs a device and an
/// engine that is not in this repository, while this part is a file and an
/// offset. The character-boundary case is the one that would otherwise be found
/// by a user whose command printed anything but ASCII.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('file_tail_test');
    file = File('${dir.path}/out');
  });

  tearDown(() => dir.delete(recursive: true));

  Future<void> append(List<int> bytes) async =>
      file.writeAsBytes(bytes, mode: FileMode.append, flush: true);

  test('a file that is not there yet is not a failure', () async {
    final tail = FileTail(file, null);

    await tail.poll();

    expect(tail.text, isEmpty);
  });

  test('only what is new arrives, and only once', () async {
    final chunks = <String>[];
    final tail = FileTail(file, chunks.add);

    await append(utf8.encode('one\n'));
    await tail.poll();
    await tail.poll();
    await append(utf8.encode('two\n'));
    await tail.poll();

    expect(chunks, ['one\n', 'two\n']);
    expect(tail.text, 'one\ntwo\n');
  });

  group('a character split across two polls', () {
    test('waits for the rest instead of being mangled', () async {
      final chunks = <String>[];
      final tail = FileTail(file, chunks.add);
      // Three bytes, and the poll lands after the first.
      final bytes = utf8.encode('中');
      expect(bytes.length, 3);

      await append([...bytes.take(1)]);
      await tail.poll();
      expect(chunks, isEmpty, reason: 'a lead byte alone is not a character');

      await append([...bytes.skip(1)]);
      await tail.poll();

      expect(chunks, ['中']);
      expect(tail.text, '中');
    });

    test('what precedes it still arrives', () async {
      final tail = FileTail(file, null);
      final bytes = utf8.encode('ok 中');

      await append(bytes.sublist(0, bytes.length - 1));
      await tail.poll();
      expect(tail.text, 'ok ');

      await append(bytes.sublist(bytes.length - 1));
      await tail.poll();
      expect(tail.text, 'ok 中');
    });

    test('a four-byte one is held back too', () async {
      final tail = FileTail(file, null);
      // An emoji, which is where a three-byte assumption would break.
      final bytes = utf8.encode('🎉');
      expect(bytes.length, 4);

      await append(bytes.sublist(0, 3));
      await tail.poll();
      expect(tail.text, isEmpty);

      await append(bytes.sublist(3));
      await tail.poll();
      expect(tail.text, '🎉');
    });
  });

  test('finish gives up on a character that never completed', () async {
    // What a killed command leaves behind. Held back forever, the last line of
    // its output would be missing entirely.
    final tail = FileTail(file, null);
    await append(utf8.encode('done ').followedBy(utf8.encode('中').take(1)).toList());

    await tail.poll();
    expect(tail.text, 'done ');

    tail.finish();
    expect(tail.text, startsWith('done '));
    expect(tail.text.length, greaterThan('done '.length));
  });

  test('what did not come from the file is kept in order with what did',
      () async {
    // The iOS guest's console: the shell's own complaint when the redirect
    // into these files is what failed.
    final tail = FileTail(file, null);

    await append(utf8.encode('from the file\n'));
    await tail.poll();
    tail.adopt('from the terminal\n');

    expect(tail.text, 'from the file\nfrom the terminal\n');
  });
}
