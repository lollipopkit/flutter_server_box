import 'package:server_box/data/res/misc.dart';

class Conn {
  static const _maxConnIndex = 4;
  static const _attemptFailsIndex = 7;

  final int maxConn;
  final int fail;

  const Conn({
    required this.maxConn,
    required this.fail,
  });

  static Conn? parse(String raw) {
    final lines = raw.split('\n');
    final idx = lines.lastWhere(
      (element) => element.startsWith('Tcp:'),
      orElse: () => '',
    );
    if (idx != '') {
      final vals = idx.split(Miscs.blankReg);
      if (vals.length <= _attemptFailsIndex) return null;
      final maxConn = int.tryParse(vals[_maxConnIndex]);
      final fail = int.tryParse(vals[_attemptFailsIndex]);
      if (maxConn == null || fail == null) return null;
      return Conn(
        maxConn: maxConn,
        fail: fail,
      );
    }
    return null;
  }
}
