import '../../res/build_data.dart';
import '../../res/server_cmd.dart';
import '../server/system.dart';

const _cmdDivider = '\necho $seperator\n';

const _serverBoxDir = r'$HOME/.config/server_box';
const _shellPath = '$_serverBoxDir/mobile_app.sh';

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

  String get exec => 'sh $_shellPath -$flag';

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
        return '''
result=\$(uname 2>&1 | grep "Linux")
if [ "\$result" != "" ]; then
${_statusCmds.join(_cmdDivider)}
else
${_bsdStatusCmd.join(_cmdDivider)}
fi''';
      case AppShellFuncType.docker:
        return '''
result=\$(docker version 2>&1 | grep "permission denied")
if [ "\$result" != "" ]; then
${_dockerCmds.join(_cmdDivider)}
else
${_dockerCmds.map((e) => "sudo -S $e").join(_cmdDivider)}
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

extension EnumX on Enum {
  /// Find out the required segment from [segments]
  String find(List<String> segments) {
    return segments[index];
  }
}

enum StatusCmdType {
  echo,
  time,
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
  ;
}

/// Cmds for linux server
const _statusCmds = [
  'echo $linuxSign',
  'date +%s',
  'cat /proc/net/dev',
  'cat /etc/*-release | grep PRETTY_NAME',
  'cat /proc/stat | grep cpu',
  'uptime',
  'cat /proc/net/snmp',
  'df -h',
  'cat /proc/meminfo',
  'cat /sys/class/thermal/thermal_zone*/type',
  'cat /sys/class/thermal/thermal_zone*/temp',
  'hostname',
];

enum DockerCmdType {
  version,
  ps,
  //stats,
  images,
  ;
}

const _dockerCmds = [
  'docker version',
  'docker ps -a',
  //'docker stats --no-stream',
  'docker image ls',
];

enum BSDStatusCmdType {
  echo,
  time,
  net,
  sys,
  cpu,
  uptime,
  disk,
  mem,
  //temp,
  host,
  ;
}

/// Cmds for BSD server
const _bsdStatusCmd = [
  'echo $bsdSign',
  'date +%s',
  'netstat -ibn',
  'uname -or',
  'top -l 1 | grep "CPU usage"',
  'uptime',
  'df -h',
  'top -l 1 | grep PhysMem',
  //'sysctl -a | grep temperature',
  'hostname',
];

final _shellCmd = """
#!/bin/sh
#
# Script for ServerBox app v1.0.${BuildData.build}
#
# DO NOT delete this file while app is running
# DO NOT run multi ServerBox apps with different version at the same time

export LANG=en_US.UTF-8

${AppShellFuncType.shellScript}
""";

final installShellCmd = "mkdir -p $_serverBoxDir && "
    "echo '$_shellCmd' > $_shellPath && "
    "chmod +x $_shellPath";
