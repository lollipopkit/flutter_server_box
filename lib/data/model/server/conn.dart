import 'package:server_box/data/res/misc.dart';

class Conn {
  final int maxConn;
  final int active;
  final int passive;
  final int fail;

  const Conn({
    required this.maxConn,
    required this.active,
    required this.passive,
    required this.fail,
  });

  static Conn? parse(String raw) {
    final lines = raw.split('\n');
    final idx = lines.lastWhere((element) => element.startsWith('Tcp:'),
        orElse: () => '');
    if (idx != '') {
      final vals = idx.split(Miscs.blankReg);
      return Conn(
        maxConn: int.tryParse(vals[5]) ?? 0,
        active: int.tryParse(vals[6]) ?? 0,
        passive: int.tryParse(vals[7]) ?? 0,
        fail: int.tryParse(vals[8]) ?? 0,
      );
    }
    return null;
  }
}
