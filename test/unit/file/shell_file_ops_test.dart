// The app's side of the shell listing: what it carries from
// `sbm_ffi::api::files`. The commands and the parser are `sbm_parser::files`',
// whose tests (`tests/files_compat.rs`) hold this file's former fixtures.

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/shell_file_ops.dart';
import 'package:server_box/data/model/file/file_backend.dart';

import '../../helpers/rust_lib_helper.dart';

String _record(String name, String perm, String type, String size, String at) =>
    '$name\u0000$perm\u0000$type\u0000$size\u0000$at\u0000';

void main() {
  setUpAll(initRustLibForTest);

  test('records become entries', () {
    final entries = parseShellFileRecords(
      _record('id_rsa', '600', 'f', '2602', '1700000000') +
          _record('sshd_config.d', '755', 'd', '4096', '') +
          _record('docker.sock', '660', 'u', '0', '0') +
          _record('cert.pem', '644', 'l', '0', '0'),
    );

    expect(entries.map((e) => e.kind), [
      FileKind.file,
      FileKind.dir,
      FileKind.other,
      FileKind.link,
    ]);
    expect(entries.first.size, 2602);
    expect(entries.first.mode, 0x180);
    expect(entries.first.modeStr, 'rw-------');
    expect(
      entries.first.modified,
      DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
    );
    expect(entries[1].size, isNull);
    expect(entries[1].modified, isNull);
  });

  test('output that is not a listing is a ShellFileRecordException', () {
    for (final forged in [
      '${_record('whole', '644', 'f', '1', '0')}partial\u0000644\u0000',
      _record('x', '644', 'banner', '1', '0'),
      kShellStatAbsentMark,
    ]) {
      expect(
        () => parseShellFileRecords(forged),
        throwsA(isA<ShellFileRecordException>()),
      );
    }
    expect(parseShellFileRecords(''), isEmpty);
  });

  test('the stat answers are told apart', () {
    expect(kShellStatAbsent, isNot(kShellStatDenied));
    expect(kShellStatAbsentMark, isNot(kShellStatDeniedMark));
    expect(shellStatCommand('/etc/shadow'), contains(kShellStatAbsentMark));
    expect(shellStatCommand('/etc/shadow'), contains('$kShellStatDenied'));
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
        const FileEntry(name: 'x', kind: FileKind.file, mode: 0).modeStr,
        '---------',
      );
    });
  });
}
