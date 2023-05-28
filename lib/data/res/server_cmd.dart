import 'build_data.dart';

const seperator = 'SrvBox';
const serverBoxDir = r'$HOME/.config/server_box';
const shellPath = '$serverBoxDir/mobile_app.sh';

const echoPWD = 'echo \$PWD';

enum CmdType {
  export,
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
  'export LANG=en_US.utf-8',
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

final shellCmd = """
# Script for app `${BuildData.name} v${BuildData.build}`
# Delete this file while app is running will cause app crash

${_cmdList.join('\necho $seperator\n')}
""";

final installShellCmd = "mkdir -p $serverBoxDir && "
    "echo '$shellCmd' > $shellPath && "
    "chmod +x $shellPath";
