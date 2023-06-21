import '../model/app/shell_func.dart';
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

final shellFuncStatus = AppShellFunc(
  'status',
  _cmdList.join('\necho $seperator\n'),
  's',
);

// Check if `htop` is installed.
// Then app open SSH term and use `htop` or `ps` to see process.
const shellFuncProcess = AppShellFunc(
  'process',
  '''
if command -v htop &> /dev/null
then
  htop
else
  top 
fi
''',
  'p',
);

final _generated = [
  shellFuncStatus,
  shellFuncProcess,
].generate;

final shellCmd = """
# Script for app `${BuildData.name} v1.0.${BuildData.build}`
# Delete this file while app is running will cause app crash

$_generated
""";

final installShellCmd = "mkdir -p $serverBoxDir && "
    "echo '$shellCmd' > $shellPath && "
    "chmod +x $shellPath";
