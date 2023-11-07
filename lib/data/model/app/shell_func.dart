import '../../res/build_data.dart';
import '../server/system.dart';

const seperator = 'SrvBoxSep';

/// The suffix `\t` is for formatting
const _cmdDivider = '\necho $seperator\n\t';
const _homeVar = '\$HOME';

enum ShellFunc {
  status,
  docker,
  process,
  shutdown,
  reboot,
  suspend,
  ;

  static const _srvBoxDir = '.config/server_box';
  static const _scriptFile = 'mobile_v${BuildData.script}.sh';

  /// Issue #159
  ///
  /// Use script commit count as version of shell script.
  ///
  /// So different version of app can run at the same time.
  ///
  /// **Can't** use it in SFTP, because SFTP can't recognize `$HOME`
  static String getShellPath(String home) => '$home/$_srvBoxDir/$_scriptFile';

  static const srvBoxDir = '$_homeVar/$_srvBoxDir';
  static const _installShellPath = '$_homeVar/$_srvBoxDir/$_scriptFile';

  /// Issue #168
  /// Use `sh` for compatibility
  static final installShellCmd = """
mkdir -p $_homeVar/$_srvBoxDir
cat << 'EOF' > $_installShellPath
${ShellFunc.allScript}
EOF
chmod +x $_installShellPath
""";

  String get flag {
    switch (this) {
      case ShellFunc.status:
        return 's';
      case ShellFunc.docker:
        return 'd';
      case ShellFunc.process:
        return 'p';
      case ShellFunc.shutdown:
        return 'sd';
      case ShellFunc.reboot:
        return 'r';
      case ShellFunc.suspend:
        return 'sp';
    }
  }

  String get exec => 'sh $_installShellPath -$flag';

  String get name {
    switch (this) {
      case ShellFunc.status:
        return 'status';
      case ShellFunc.docker:
        // `dockeR` -> avoid conflict with `docker` command
        // 以防止循环递归
        return 'dockeR';
      case ShellFunc.process:
        return 'process';
      case ShellFunc.shutdown:
        return 'ShutDown';
      case ShellFunc.reboot:
        return 'Reboot';
      case ShellFunc.suspend:
        return 'Suspend';
    }
  }

  String get _cmd {
    switch (this) {
      case ShellFunc.status:
        return '''
if [ "\$macSign" = "" ] && [ "\$bsdSign" = "" ]; then
\t${_statusCmds.join(_cmdDivider)}
else
\t${_bsdStatusCmd.join(_cmdDivider)}
fi''';
      case ShellFunc.docker:
        return '''
result=\$(docker version 2>&1 | grep "permission denied")
if [ "\$result" != "" ]; then
\t${_dockerCmds.join(_cmdDivider)}
else
\t${_dockerCmds.map((e) => "sudo -S $e").join(_cmdDivider)}
fi''';
      case ShellFunc.process:
        return '''
if [ "\$macSign" = "" ] && [ "\$bsdSign" = "" ]; then
\tif [ "\$isBusybox" != "" ]; then
\t\tps w
\telse
\t\tps -aux
\tfi
else
\tps -ax
fi
''';
      case ShellFunc.shutdown:
        return '''
if [ "\$userId" = "0" ]; then
\tshutdown -h now
else
\tsudo -S shutdown -h now
fi''';
      case ShellFunc.reboot:
        return '''
if [ "\$userId" = "0" ]; then
\treboot
else
\tsudo -S reboot
fi''';
      case ShellFunc.suspend:
        return '''
if [ "\$userId" = "0" ]; then
\tsystemctl suspend
else
\tsudo -S systemctl suspend
fi''';
    }
  }

  static final String allScript = () {
    final sb = StringBuffer();
    sb.write('''
#!/bin/sh
# Script for ServerBox app v1.0.${BuildData.build}
# DO NOT delete this file while app is running

export LANG=en_US.UTF-8

# If macSign & bsdSign are both empty, then it's linux
macSign=\$(uname -a 2>&1 | grep "Darwin")
bsdSign=\$(uname -a 2>&1 | grep "BSD")

# Link /bin/sh to busybox?
isBusybox=\$(ls -l /bin/sh | grep "busybox")

userId=\$(id -u)

''');
    // Write each func
    for (final func in values) {
      sb.write('''
${func.name}() {
${func._cmd.split('\n').map((e) => '\t$e').join('\n')}
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
  }();
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
  diskio;
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
  "cat /proc/meminfo | grep -E 'Mem|Swap'",
  'cat /sys/class/thermal/thermal_zone*/type',
  'cat /sys/class/thermal/thermal_zone*/temp',
  'hostname',
  'cat /proc/diskstats',
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
