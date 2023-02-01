const seperator = 'A====A';
const shellCmd = "export LANG=en_US.utf-8 \necho '$seperator' \n"
    "cat /proc/net/dev && date +%s \necho $seperator \n "
    "cat /etc/os-release | grep PRETTY_NAME \necho $seperator \n"
    "cat /proc/stat | grep cpu \necho $seperator \n"
    "uptime \necho $seperator \n"
    "cat /proc/net/snmp \necho $seperator \n"
    "df -h \necho $seperator \n"
    "cat /proc/meminfo \necho $seperator \n"
    "cat /sys/class/thermal/thermal_zone*/type \necho $seperator \n"
    "cat /sys/class/thermal/thermal_zone*/temp";
const shellPath = '.serverbox.sh';
