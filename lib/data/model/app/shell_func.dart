import '../../res/server_cmd.dart';

const _cmdDivider = '\necho $seperator\n';

enum AppShellFuncType {
  status,
  docker;

  String get flag {
    switch (this) {
      case AppShellFuncType.status:
        return 's';
      case AppShellFuncType.docker:
        return 'd';
    }
  }

  String get exec => 'sh $shellPath -$flag';

  String get name {
    switch (this) {
      case AppShellFuncType.status:
        return 'status';
      case AppShellFuncType.docker:
        // `dockeR` -> avoid conflict with `docker` command
        // 以防止循环递归
        return 'dockeR';
    }
  }

  String get cmd {
    switch (this) {
      case AppShellFuncType.status:
        return statusCmds.join(_cmdDivider);
      case AppShellFuncType.docker:
        return '''
result=\$(docker version 2>&1)
deniedStr="permission denied"
containStr=\$(echo \$result | grep "\${deniedStr}")
if [[ \$containStr != "" ]]; then
${dockerCmds.join(_cmdDivider)}
else
${dockerCmds.map((e) => "sudo -S $e").join(_cmdDivider)}
fi''';
    }
  }

  static String get shellScript {
    final sb = StringBuffer();
    // Write each func
    for (final func in values) {
      sb.write('''
${func.name}() {
${func.cmd}
}

''');
    }

    // Write switch case
    sb.write('case \$1 in\n');
    for (final func in values) {
      sb.write('''
  '-${func.flag}')
    ${func.name}
    ;;
''');
    }
    sb.write('''
  *)
    echo "Invalid argument \$1"
    ;;
esac''');
    return sb.toString();
  }
}

abstract class _CmdType {
  /// Find out the required segment from [segments]
  String find(List<String> segments);
}

enum StatusCmdType implements _CmdType {
  net,
  sys,
  cpu,
  uptime,
  conn,
  disk,
  mem,
  tempType,
  tempVal,
  host,
  sysRhel;

  @override
  String find(List<String> segments) {
    return segments[index];
  }
}

enum DockerCmdType implements _CmdType {
  version,
  ps,
  stats,
  images;

  @override
  String find(List<String> segments) {
    return segments[index];
  }
}
