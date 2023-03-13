import 'build_data.dart';

const seperator = 'SrvBox';
const shellPath = '.serverbox.sh';

const shellCmd = """
# Script for app `${BuildData.name}`
# Delete this file while app is running will cause app crash

export LANG=en_US.utf-8
echo $seperator
cat /proc/net/dev && date +%s
echo $seperator
cat /etc/os-release | grep PRETTY_NAME
echo $seperator
cat /proc/stat | grep cpu
echo $seperator
uptime
echo $seperator
cat /proc/net/snmp
echo $seperator
df -h
echo $seperator
cat /proc/meminfo
echo $seperator
cat /sys/class/thermal/thermal_zone*/type
echo $seperator
cat /sys/class/thermal/thermal_zone*/temp
""";
