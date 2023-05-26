import '../../../core/extension/stringx.dart';
import '../../res/misc.dart';

class ConnStatus {
/*
{
  "maxConn": 0,
  "active": 1,
  "passive": 2,
  "fail": 3
} 
*/

  late int maxConn;
  late int active;
  late int passive;
  late int fail;

  ConnStatus(
    this.maxConn,
    this.active,
    this.passive,
    this.fail,
  );
}

ConnStatus? parseConn(String raw) {
  final lines = raw.split('\n');
  final idx = lines.lastWhere((element) => element.startsWith('Tcp:'),
      orElse: () => '');
  if (idx != '') {
    final vals = idx.split(numReg);
    return ConnStatus(vals[5].i, vals[6].i, vals[7].i, vals[8].i);
  }
  return null;
}
