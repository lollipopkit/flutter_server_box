import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/conn.dart';

void main() {
  test('Conn.parse reads MaxConn and AttemptFails from /proc/net/snmp', () {
    const raw = '''Tcp: RtoAlgorithm RtoMin RtoMax MaxConn ActiveOpens PassiveOpens AttemptFails EstabResets CurrEstab InSegs OutSegs RetransSegs InErrs OutRsts InCsumErrors
Tcp: 1 200 120000 -1 11 22 33 44 55 66 77 88 99 111 222''';

    final result = Conn.parse(raw);

    expect(result?.maxConn, -1);
    expect(result?.fail, 33);
  });

  test('Conn.parse rejects truncated TCP rows', () {
    expect(Conn.parse('Tcp: 1 2 3'), isNull);
  });

  test('Conn.parse rejects non-numeric TCP counters', () {
    const raw = 'Tcp: 1 200 120000 unknown 11 22 invalid 44';

    expect(Conn.parse(raw), isNull);
  });
}
