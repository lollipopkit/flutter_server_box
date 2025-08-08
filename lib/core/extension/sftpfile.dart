import 'package:dartssh2/dartssh2.dart';
import 'package:server_box/view/widget/unix_perm.dart';

extension SftpFileX on SftpFileMode {
  String get str {
    final user = _getRoleMode(userRead, userWrite, userExecute);
    final group = _getRoleMode(groupRead, groupWrite, groupExecute);
    final other = _getRoleMode(otherRead, otherWrite, otherExecute);

    return '$user$group$other';
  }

  UnixPerm toUnixPerm() {
    return UnixPerm(
      user: UnixPermOp(r: userRead, w: userWrite, x: userExecute),
      group: UnixPermOp(r: groupRead, w: groupWrite, x: groupExecute),
      other: UnixPermOp(r: otherRead, w: otherWrite, x: otherExecute),
    );
  }
}

String _getRoleMode(bool r, bool w, bool x) {
  return '${r ? 'r' : '-'}${w ? 'w' : '-'}${x ? 'x' : '-'}';
}
