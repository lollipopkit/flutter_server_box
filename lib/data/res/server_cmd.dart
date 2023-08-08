import '../model/app/shell_func.dart';
import 'build_data.dart';

const seperator = 'SrvBoxSep';
const serverBoxDir = r'$HOME/.config/server_box';
const shellPath = '$serverBoxDir/mobile_app.sh';

const echoPWD = 'echo \$PWD';

const statusCmds = [
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

const dockerCmds = [
  'docker version',
  'docker ps -a',
  'docker stats --no-stream',
  'docker image ls',
];

final shellCmd = """
# Script for app `${BuildData.name} v1.0.${BuildData.build}`
# Delete this file while app is running will cause app crash

export LANG=en_US.UTF-8

${AppShellFuncType.shellScript}
""";

final installShellCmd = "mkdir -p $serverBoxDir && "
    "echo '$shellCmd' > $shellPath && "
    "chmod +x $shellPath";
