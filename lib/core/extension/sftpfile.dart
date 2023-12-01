import 'package:dartssh2/dartssh2.dart';

extension SftpFile on SftpFileMode {
  String get str {
    final user = _getRoleMode(userRead, userWrite, userExecute);
    final group = _getRoleMode(groupRead, groupWrite, groupExecute);
    final other = _getRoleMode(otherRead, otherWrite, otherExecute);

    return '$user$group$other';
  }
}

String _getRoleMode(bool r, bool w, bool x) {
  return '${r ? 'r' : '-'}${w ? 'w' : '-'}${x ? 'x' : '-'}';
}
