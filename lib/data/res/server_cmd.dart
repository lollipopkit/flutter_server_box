import '../model/app/shell_func.dart';
import 'build_data.dart';

const seperator = 'SrvBox';
const serverBoxDir = r'$HOME/.config/server_box';
const shellPath = '$serverBoxDir/mobile_app.sh';

const echoPWD = 'echo \$PWD';

enum CmdType {
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
  sysRhel,
}

const _cmdList = [
  'cat /proc/net/dev && date +%s',
  'cat /etc/os-release | grep PRETTY_NAME',
  'cat /proc/stat | grep cpu',
  'uptime',
  'cat /proc/net/snmp',
  'df -h',
  'cat /proc/meminfo',
  'cat /sys/class/thermal/thermal_zone*/type',
  'cat /sys/class/thermal/thermal_zone*/temp',
  'hostname',
  'cat /etc/redhat-release',
];

final shellFuncStatus = AppShellFunc(
  'status',
  _cmdList.join('\necho $seperator\n'),
  's',
);

const dockerCmds = [
  'docker version',
  'docker ps -a',
  'docker stats --no-stream',
  'docker image ls',
];

final shellFuncDocker = AppShellFunc(
  // `dockeR` -> avoid conflict with `docker` command
  // 以防止循环递归
  'dockeR',
  dockerCmds.join('\necho $seperator\n'),
  'd',
);

final _generated = [
  shellFuncStatus,
  shellFuncDocker,
].generate;

final shellCmd = """
# Script for app `${BuildData.name} v1.0.${BuildData.build}`
# Delete this file while app is running will cause app crash

export LANG=en_US.utf-8

$_generated
""";

final installShellCmd = "mkdir -p $serverBoxDir && "
    "echo '$shellCmd' > $shellPath && "
    "chmod +x $shellPath";
