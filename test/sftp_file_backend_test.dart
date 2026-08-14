import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/sftp_file_backend.dart';
import 'package:server_box/data/model/file/file_backend.dart';

/// One entry as the escalated `find` prints it: five NUL-terminated fields.
String _record(String name, String perm, String type, String size, String at) =>
    '$name\u0000$perm\u0000$type\u0000$size\u0000$at\u0000';

void main() {
  group('the escalated listing', () {
    test('reads back what find printed', () {
      final entries = SftpFileBackend.parseListOutput(
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
      final entries = SftpFileBackend.parseListOutput(
        _record('two\nlines', '644', 'f', '1', '0'),
      );

      expect(entries.single.name, 'two\nlines');
    });

    test('a link is a link, not what it points at', () {
      // `[ -f ]` follows the link and would answer for the target, so the
      // command tests for a link last.
      final entries = SftpFileBackend.parseListOutput(
        _record('cert.pem', '644', 'l', '0', '0'),
      );

      expect(entries.single.kind, FileKind.link);
    });

    test('a half-written record is dropped rather than half-read', () {
      // A command killed partway through prints an incomplete tail.
      final entries = SftpFileBackend.parseListOutput(
        '${_record('whole', '644', 'f', '1', '0')}partial\u0000644\u0000',
      );

      expect(entries.single.name, 'whole');
    });

    test('nothing at all is an empty directory, not a failure', () {
      expect(SftpFileBackend.parseListOutput(''), isEmpty);
    });

    test('the command quotes the path it was given', () {
      final command = SftpFileBackend.listCommand("/tmp/it's here");

      expect(command, startsWith("find '/tmp/it'\\''s here' "));
      expect(command, contains('-mindepth 1 -maxdepth 1'));
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
