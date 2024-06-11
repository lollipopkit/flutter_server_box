import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/proc.dart';

void main() {
  test('parse process', () {
    const raw = '''
  PID USER       VSZ STAT COMMAND
    1 root      1276 S    /sbin/procd
''';
    final psResult = PsResult.parse(raw);
    expect(psResult.procs.length, 1);
  });
}
