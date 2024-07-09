import 'package:server_box/core/extension/context/locale.dart';

import '../../res/build_data.dart';
import '../server/system.dart';

enum ShellFunc {
  status,
  //docker,
  process,
  shutdown,
  reboot,
  suspend,
  ;

  static const seperator = 'SrvBoxSep';

  /// The suffix `\t` is for formatting
  static const cmdDivider = '\necho $seperator\n\t';

  /// srvboxm -> ServerBox Mobile
  static const scriptFile = 'srvboxm_v${BuildData.script}.sh';
  static const scriptPath = '/dev/shm/$scriptFile';
  static const installShellCmd = """
cat > $scriptPath
chmod 744 $scriptPath
""";

  String get flag {
    switch (this) {
      case ShellFunc.status:
        return 's';
      // case ShellFunc.docker:
      //   return 'd';
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

  String get exec => 'sh $scriptPath -$flag';

  String get name {
    switch (this) {
      case ShellFunc.status:
        return 'status';
      // case ShellFunc.docker:
      //   // `dockeR` -> avoid conflict with `docker` command
      //   return 'dockeR';
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
\t${StatusCmdType.values.map((e) => e.cmd).join(cmdDivider)}
else
\t${BSDStatusCmdType.values.map((e) => e.cmd).join(cmdDivider)}
fi''';
//       case ShellFunc.docker:
//         return '''
// result=\$(docker version 2>&1 | grep "permission denied")
// if [ "\$result" != "" ]; then
// \t${_dockerCmds.join(_cmdDivider)}
// else
// \t${_dockerCmds.map((e) => "sudo -S $e").join(_cmdDivider)}
// fi''';
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

  static String allScript(Map<String, String>? customCmds) {
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

exec 2>/dev/null

''');
    // Write each func
    for (final func in values) {
      final customCmdsStr = () {
        if (func == ShellFunc.status &&
            customCmds != null &&
            customCmds.isNotEmpty) {
          return '$cmdDivider\n\t${customCmds.values.join(cmdDivider)}';
        }
        return '';
      }();
      sb.write('''
${func.name}() {
${func._cmd.split('\n').map((e) => '\t$e').join('\n')}
$customCmdsStr
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
  echo._('echo ${SystemType.linuxSign}'),
  time._('date +%s'),
  net._('cat /proc/net/dev'),
  sys._('cat /etc/*-release | grep PRETTY_NAME'),
  cpu._('cat /proc/stat | grep cpu'),
  uptime._('uptime'),
  conn._('cat /proc/net/snmp'),
  disk._('df'),
  mem._("cat /proc/meminfo | grep -E 'Mem|Swap'"),
  tempType._('cat /sys/class/thermal/thermal_zone*/type'),
  tempVal._('cat /sys/class/thermal/thermal_zone*/temp'),
  host._('cat /etc/hostname'),
  diskio._('cat /proc/diskstats'),
  battery._(
      'for f in /sys/class/power_supply/*/uevent; do cat "\$f"; echo; done'),
  nvidia._('nvidia-smi -q -x'),
  sensors._('sensors'),
  ;

  final String cmd;

  const StatusCmdType._(this.cmd);
}

enum BSDStatusCmdType {
  echo._('echo ${SystemType.bsdSign}'),
  time._('date +%s'),
  net._('netstat -ibn'),
  sys._('uname -or'),
  cpu._('top -l 1 | grep "CPU usage"'),
  uptime._('uptime'),
  disk._('df -k'),
  mem._('top -l 1 | grep PhysMem'),
  //temp,
  host._('hostname'),
  ;

  final String cmd;

  const BSDStatusCmdType._(this.cmd);
}

extension StatusCmdTypeX on StatusCmdType {
  String get i18n => switch (this) {
        StatusCmdType.sys => l10n.system,
        StatusCmdType.host => l10n.host,
        StatusCmdType.uptime => l10n.uptime,
        StatusCmdType.battery => l10n.battery,
        final val => val.name,
      };
}
