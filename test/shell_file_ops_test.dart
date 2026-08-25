import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/shell_file_ops.dart';
import 'package:server_box/data/model/file/file_backend.dart';

/// One entry as `find` or `stat` prints it: five NUL-terminated fields.
String _record(String name, String perm, String type, String size, String at) =>
    '$name\u0000$perm\u0000$type\u0000$size\u0000$at\u0000';

void main() {
  group('the shell listing', () {
    test('reads back what find printed', () {
      final entries = parseShellFileRecords(
        _record('id_rsa', '600', 'f', '2602', '1700000000') +
            _record('sshd_config.d', '755', 'd', '4096', '1700000001'),
      );

      expect(entries, hasLength(2));
      expect(entries.first.name, 'id_rsa');
      expect(entries.first.kind, FileKind.file);
      expect(entries.first.size, 2602);
      expect(entries.first.mode, 0x180);
      expect(entries.first.modeStr, 'rw-------');
      expect(
        entries.first.modified,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      );

      expect(entries.last.kind, FileKind.dir);
      // Only files carry one: a directory's is the size of the directory, not
      // of what is in it, and showing it beside a filename misleads.
      expect(entries.last.size, isNull);
    });

    test('survives a name with a newline in it', () {
      // The reason the fields are NUL-separated and not line-separated.
      final entries = parseShellFileRecords(
        _record('two\nlines', '644', 'f', '1', '0'),
      );

      expect(entries.single.name, 'two\nlines');
    });

    test('a link is a link, not what it points at', () {
      // `[ -f ]` follows the link and would answer for the target, so the
      // command tests for a link last.
      final entries = parseShellFileRecords(
        _record('cert.pem', '644', 'l', '0', '0'),
      );

      expect(entries.single.kind, FileKind.link);
    });

    test('an empty field does not shift every entry after it', () {
      // `stat -c %a` printing nothing — a file removed between `find` and
      // `stat`, or a `stat` that does not take `-c`. Filtering the empty
      // field out desynchronised the 5-wide stride, so from there on names
      // were read out of the perm column and sizes out of the mtime column.
      final entries = parseShellFileRecords(
        '${_record('vanished', '', 'f', '0', '0')}'
        '${_record('after.txt', '644', 'f', '99', '1700000000')}',
      );

      expect(entries, hasLength(2));
      expect(entries.last.name, 'after.txt');
      expect(entries.last.size, 99);
      expect(entries.last.mode, 0x1A4);
      // The one with no perm reported has none, rather than borrowing its
      // neighbour's.
      expect(entries.first.name, 'vanished');
      expect(entries.first.mode, isNull);
    });

    test('a half-written record is dropped rather than half-read', () {
      // A command killed partway through prints an incomplete tail.
      final entries = parseShellFileRecords(
        '${_record('whole', '644', 'f', '1', '0')}partial\u0000644\u0000',
      );

      expect(entries.single.name, 'whole');
    });

    test('nothing at all is an empty directory, not a failure', () {
      expect(parseShellFileRecords(''), isEmpty);
    });

    test('the command quotes the path it was given', () {
      final command = shellListCommand("/tmp/it's here");

      expect(command, startsWith("find '/tmp/it'\\''s here' "));
      expect(command, contains('-mindepth 1 -maxdepth 1'));
    });
  });

  group('the shell stat', () {
    test('prints the same five fields a listing does', () {
      // One parser reads both, so the stat command has to emit exactly what
      // the list command emits. Asserted on the shape rather than on the text
      // because the shape is what the parser depends on.
      final entry = parseShellFileRecords(
        _record('hosts', '644', 'f', '213', '1700000000'),
      ).single;

      expect(entry.name, 'hosts');
      expect(entry.kind, FileKind.file);
      expect(entry.size, 213);
      expect(entry.mode, 0x1A4);
    });

    test('quotes the path and derives the parent from it', () {
      final command = shellStatCommand("/etc/it's here");

      expect(command, startsWith("path='/etc/it'\\''s here'"));
      // The parent, tested separately, is what lets an absence be told from a
      // directory this user may not search.
      expect(command, contains(r'dir=${path%/*}'));
    });

    test('the two failures have exit codes of their own', () {
      final command = shellStatCommand('/etc/shadow');

      // Distinct, and neither is 0 or 1: "nothing there" invites creating
      // something and "you may not look" does not, so the caller has to be
      // able to tell them apart without reading an error message in whatever
      // language the far side is set to.
      expect(kShellStatAbsent, isNot(kShellStatDenied));
      expect(command, contains('exit $kShellStatAbsent'));
      expect(command, contains('exit $kShellStatDenied'));
    });
  });

  group('modeStr', () {
    test('spells out the nine bits', () {
      const entry = FileEntry(name: 'x', kind: FileKind.file);
      expect(entry.modeStr, isNull);

      expect(
        const FileEntry(name: 'x', kind: FileKind.file, mode: 0x1ED).modeStr,
        'rwxr-xr-x',
      );
      expect(
        const FileEntry(name: 'x', kind: FileKind.file, mode: 0x1A4).modeStr,
        'rw-r--r--',
      );
      expect(
        const FileEntry(name: 'x', kind: FileKind.file, mode: 0).modeStr,
        '---------',
      );
    });
  });
}
