import 'package:dartssh2/dartssh2.dart';

extension SftpFile on SftpFileMode {
  String get str {
    final user = getRoleMode(userRead, userWrite, userExecute);
    final group = getRoleMode(groupRead, groupWrite, groupExecute);
    final other = getRoleMode(otherRead, otherWrite, otherExecute);

    return '$user$group$other';
  }
}

String getRoleMode(bool r, bool w, bool x) {
  return '${r ? 'r' : '-'}${w ? 'w' : '-'}${x ? 'x' : '-'}';
}
