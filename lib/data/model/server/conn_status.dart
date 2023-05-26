import '../../../core/extension/stringx.dart';
import '../../res/misc.dart';

class ConnStatus {
  final int maxConn;
  final int active;
  final int passive;
  final int fail;

  ConnStatus({
    required this.maxConn,
    required this.active,
    required this.passive,
    required this.fail,
  });
}

ConnStatus? parseConn(String raw) {
  final lines = raw.split('\n');
  final idx = lines.lastWhere((element) => element.startsWith('Tcp:'),
      orElse: () => '');
  if (idx != '') {
    final vals = idx.split(numReg);
    return ConnStatus(
      maxConn: vals[5].i,
      active: vals[6].i,
      passive: vals[7].i,
      fail: vals[8].i,
    );
  }
  return null;
}
