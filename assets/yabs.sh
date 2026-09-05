#!/bin/bash

# Yet Another Bench Script by Mason Rowe
# Initial Oct 2019; Last update Jul 2026

# Disclaimer: This project is a work in progress. Any errors or suggestions should be
#             relayed to me via the GitHub project page linked below.
#
# Purpose:    The purpose of this script is to quickly gauge the performance of a Linux-
#             based server by benchmarking network performance via iperf3, CPU and
#             overall system performance via Geekbench 4/5/6/7, and random disk
#             performance via fio. The script is designed to not require any dependencies
#             - either compiled or installed - nor admin privileges to run.

YABS_VERSION="v2026-07-24"

echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e '#              Yet-Another-Bench-Script              #'
echo -e '#                     '$YABS_VERSION'                    #'
echo -e '# https://github.com/masonr/yet-another-bench-script #'
echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'

echo -e
date
TIME_START=$(date '+%Y%m%d-%H%M%S')
YABS_START_TIME=$(date +%s)

# override locale to eliminate parsing errors (i.e. using commas as delimiters rather than periods)
if locale -a 2>/dev/null | grep ^C$ > /dev/null; then
	# locale "C" installed
	export LC_ALL=C
else
	# locale "C" not installed, display warning
	echo -e "\nWarning: locale 'C' not detected. Test outputs may not be parsed correctly."
fi

# determine architecture of host
ARCH=$(uname -m)
if [[ $ARCH = *x86_64* ]]; then
	# host is running a 64-bit kernel
	ARCH="x64"
elif [[ $ARCH = *i?86* ]]; then
	# host is running a 32-bit kernel
	ARCH="x86"
elif [[ $ARCH = *aarch* || $ARCH = *arm* ]]; then
	KERNEL_BIT=$(getconf LONG_BIT)
	if [[ $KERNEL_BIT = *64* ]]; then
		# host is running an ARM 64-bit kernel
		ARCH="aarch64"
	else
		# host is running an ARM 32-bit kernel
		ARCH="arm"
	fi
	echo -e "\nARM compatibility is considered *experimental*"
else
	# host is running a non-supported kernel
	echo -e "Architecture not supported by YABS."
	exit 1
fi

# flags to skip certain performance tests
unset PREFER_BIN SKIP_FIO SKIP_IPERF SKIP_GEEKBENCH SKIP_NET PRINT_HELP REDUCE_NET GEEKBENCH_4 GEEKBENCH_5 GEEKBENCH_6 GEEKBENCH_7 DD_FALLBACK IPERF_DL_FAIL JSON JSON_SEND JSON_RESULT JSON_FILE IPERF_SERVERS
GEEKBENCH_6="True" # gb6 test enabled by default

# get any arguments that were passed to the script and set the associated skip flags (if applicable)
while getopts 'bfdignhr45796jw:s:p:' flag; do
	case "${flag}" in
		b) PREFER_BIN="True" ;;
		f) SKIP_FIO="True" ;;
		d) SKIP_FIO="True" ;;
		i) SKIP_IPERF="True" ;;
		g) SKIP_GEEKBENCH="True" && unset GEEKBENCH_6 ;;
		n) SKIP_NET="True" ;;
		h) PRINT_HELP="True" ;;
		r) REDUCE_NET="True" ;;
		4) GEEKBENCH_4="True" && unset GEEKBENCH_6 ;;
		5) GEEKBENCH_5="True" && unset GEEKBENCH_6 ;;
		7) GEEKBENCH_7="True" && unset GEEKBENCH_6 ;;
		9) GEEKBENCH_4="True" && GEEKBENCH_5="True" && unset GEEKBENCH_6 ;;
		6) GEEKBENCH_6="True" ;;
		j) JSON+="j" ;;
		w) JSON+="w" && JSON_FILE=${OPTARG} ;;
		s) JSON+="s" && JSON_SEND=${OPTARG} ;;
		p) IPERF_SERVERS=${OPTARG} ;;
		*) exit 1 ;;
	esac
done

# check for local fio/iperf installs
if command -v fio >/dev/null 2>&1; then
    LOCAL_FIO=true
else
    unset LOCAL_FIO
fi

if command -v iperf3 >/dev/null 2>&1; then
    LOCAL_IPERF=true
else
    unset LOCAL_IPERF
fi

# check for ping
if command -v ping >/dev/null 2>&1; then
    LOCAL_PING=true
else
    unset LOCAL_PING
fi

# check for curl/wget
if command -v curl >/dev/null 2>&1; then
    LOCAL_CURL=true
else
    unset LOCAL_CURL
fi


# test if the host has IPv4/IPv6 connectivity
[[ -n $LOCAL_CURL ]] && IP_CHECK_CMD="curl -s -m 4" || IP_CHECK_CMD="wget -qO- -T 4"
IPV4_CHECK=$( (ping -4 -c 1 -W 4 ipv4.google.com >/dev/null 2>&1 && echo true) || $IP_CHECK_CMD -4 icanhazip.com 2> /dev/null)
IPV6_CHECK=$( (ping -6 -c 1 -W 4 ipv6.google.com >/dev/null 2>&1 && echo true) || $IP_CHECK_CMD -6 icanhazip.com 2> /dev/null)
if [[ -z "$IPV4_CHECK" && -z "$IPV6_CHECK" ]]; then
	echo -e
	echo -e "Warning: Both IPv4 AND IPv6 connectivity were not detected. Check for DNS issues..."
fi

# print help and exit script, if help flag was passed
if [ -n "$PRINT_HELP" ]; then
	echo -e
	echo -e "Usage: ./yabs.sh [-flags]"
	echo -e "       curl -sL yabs.sh | bash"
	echo -e "       curl -sL yabs.sh | bash -s -- -flags"
	echo -e "       wget -qO- yabs.sh | bash"
	echo -e "       wget -qO- yabs.sh | bash -s -- -flags"
	echo -e
	echo -e "Flags:"
	echo -e "       -b : prefer pre-compiled binaries from repo over local packages"
	echo -e "       -f/d : skips the fio disk benchmark test"
	echo -e "       -i : skips the iperf network test"
	echo -e "       -g : skips the geekbench performance test"
	echo -e "       -n : skips the network information lookup and print out"
	echo -e "       -h : prints this lovely message, shows any flags you passed,"
	echo -e "            shows if fio/iperf3 local packages have been detected,"
	echo -e "            then exits"
	echo -e "       -r : reduce number of iperf3 network locations (to only three)"
	echo -e "            to lessen bandwidth usage"
	echo -e "       -4 : use geekbench 4 instead of geekbench 6"
	echo -e "       -5 : use geekbench 5 instead of geekbench 6"
	echo -e "       -7 : use geekbench 7 instead of geekbench 6"
	echo -e "       -9 : use both geekbench 4 AND geekbench 5 instead of geekbench 6"
	echo -e "       -6 : use geekbench 6 in addition to 4, 5, and/or 7 (only needed if -4, -5, -7, or -9 are set; -6 must come last)"
	echo -e "       -j : print jsonified YABS results at conclusion of test"
	echo -e "       -w <filename> : write jsonified YABS results to disk using file name provided"
	echo -e "       -s <url> : send jsonified YABS results to URL"
	echo -e "       -p <servers> : specify custom iperf servers (format: host:port_range:name:location:network_modes)"
	echo -e "                      multiple servers separated by commas"
	echo -e "                      example: -p \"example.com:5201-5210:MyServer:New York (10G):IPv4|IPv6\""
	echo -e
	echo -e "Detected Arch: $ARCH"
	echo -e
	echo -e "Detected Flags:"
	[[ -n $PREFER_BIN ]] && echo -e "       -b, force using precompiled binaries from repo"
	[[ -n $SKIP_FIO ]] && echo -e "       -f/d, skipping fio disk benchmark test"
	[[ -n $SKIP_IPERF ]] && echo -e "       -i, skipping iperf network test"
	[[ -n $SKIP_GEEKBENCH ]] && echo -e "       -g, skipping geekbench test"
	[[ -n $SKIP_NET ]] && echo -e "       -n, skipping network info lookup and print out"
	[[ -n $REDUCE_NET ]] && echo -e "       -r, using reduced (3) iperf3 locations"
	[[ -n $GEEKBENCH_4 ]] && echo -e "       running geekbench 4"
	[[ -n $GEEKBENCH_5 ]] && echo -e "       running geekbench 5"
	[[ -n $GEEKBENCH_6 ]] && echo -e "       running geekbench 6"
	[[ -n $GEEKBENCH_7 ]] && echo -e "       running geekbench 7"
	[[ -n $IPERF_SERVERS ]] && echo -e "       -p, using custom iperf servers: $IPERF_SERVERS"
	echo -e
	echo -e "Local Binary Check:"
	([[ -z $LOCAL_FIO ]] && echo -e "       fio not detected, will download precompiled binary") ||
		([[ -z $PREFER_BIN ]] && echo -e "       fio detected, using local package") ||
		echo -e "       fio detected, but using precompiled binary instead"
	([[ -z $LOCAL_IPERF ]] && echo -e "       iperf3 not detected, will download precompiled binary") ||
		([[ -z $PREFER_BIN ]] && echo -e "       iperf3 detected, using local package") ||
		echo -e "       iperf3 detected, but using precompiled binary instead"
	echo -e
	echo -e "Detected Connectivity:"
	[[ -n $IPV4_CHECK ]] && echo -e "       IPv4 connected" ||
		echo -e "       IPv4 not connected"
	[[ -n $IPV6_CHECK ]] && echo -e "       IPv6 connected" ||
		echo -e "       IPv6 not connected"
	echo -e
	echo -e "JSON Options:"
	[[ -z $JSON ]] && echo -e "       none"
	[[ $JSON = *j* ]] && echo -e "       printing json to screen after test"
	[[ $JSON = *w* ]] && echo -e "       writing json to file ($JSON_FILE) after test"
	[[ $JSON = *s* ]] && echo -e "       sharing json YABS results to $JSON_SEND"
	echo -e
	echo -e "Exiting..."

	exit 0
fi

# format_size
# Purpose: Formats raw disk and memory sizes from kibibytes (KiB) to largest unit
# Parameters:
#          1. RAW - the raw memory size (RAM/Swap) in kibibytes
# Returns:
#          Formatted memory size in KiB, MiB, GiB, or TiB
function format_size {
	RAW=$1 # mem size in KiB
	RESULT=$RAW
	local DENOM=1
	local UNIT="KiB"

	# ensure the raw value is a number, otherwise return blank
	re='^[0-9]+$'
	if ! [[ $RAW =~ $re ]] ; then
		echo ""
		return 0
	fi

	if [ "$RAW" -ge 1073741824 ]; then
		DENOM=1073741824
		UNIT="TiB"
	elif [ "$RAW" -ge 1048576 ]; then
		DENOM=1048576
		UNIT="GiB"
	elif [ "$RAW" -ge 1024 ]; then
		DENOM=1024
		UNIT="MiB"
	fi

	# divide the raw result to get the corresponding formatted result (based on determined unit)
	RESULT=$(awk -v a="$RESULT" -v b="$DENOM" 'BEGIN { print a / b }')
	# shorten the formatted result to two decimal places (i.e. x.x)
	RESULT=$(echo "$RESULT" | awk -F. '{ printf "%0.1f",$1"."substr($2,1,2) }')
	# concat formatted result value with units and return result
	RESULT="$RESULT $UNIT"
	echo "$RESULT"
}

# gather basic system information (inc. CPU, AES-NI/virt status, RAM + swap + disk size)
echo -e
echo -e "Basic System Information:"
echo -e "---------------------------------"
UPTIME=$(uptime | awk -F'( |,|:)+' '{d=h=m=0; if ($7=="min") m=$6; else {if ($7~/^day/) {d=$6; if ($9~/^min/) m=$8; else {h=$8;m=$9}} else {h=$6;m=$7}}} {print d+0,"days,",h+0,"hours,",m+0,"minutes"}')
echo -e "Uptime     : $UPTIME"
# check for local lscpu installs
if command -v lscpu >/dev/null 2>&1; then
  LOCAL_LSCPU=true
else
  unset LOCAL_LSCPU
fi
if [[ $ARCH = *aarch64* || $ARCH = *arm* ]] && [[ -n $LOCAL_LSCPU ]]; then
	CPU_PROC=$(lscpu | grep "Model name" | sed 's/Model name: *//g')
else
	CPU_PROC=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
fi
echo -e "Processor  : $CPU_PROC"
if [[ $ARCH = *aarch64* || $ARCH = *arm* ]] && [[ -n $LOCAL_LSCPU ]]; then
	CPU_CORES=$(lscpu | grep "^[[:blank:]]*CPU(s):" | sed 's/CPU(s): *//g')
	CPU_FREQ=$(lscpu | grep "CPU max MHz" | sed 's/CPU max MHz: *//g')
	[[ -z "$CPU_FREQ" ]] && CPU_FREQ="???"
	CPU_FREQ="${CPU_FREQ} MHz"
else
	CPU_CORES=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)
	CPU_FREQ=$(awk -F: ' /cpu MHz/ {freq=$2} END {print freq " MHz"}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
fi
echo -e "CPU cores  : $CPU_CORES @ $CPU_FREQ"
CPU_AES=$(grep aes /proc/cpuinfo)
[[ -z "$CPU_AES" ]] && CPU_AES="\xE2\x9D\x8C Disabled" || CPU_AES="\xE2\x9C\x94 Enabled"
echo -e "AES-NI     : $CPU_AES"
CPU_VIRT=$(grep 'vmx\|svm' /proc/cpuinfo)
[[ -z "$CPU_VIRT" ]] && CPU_VIRT="\xE2\x9D\x8C Disabled" || CPU_VIRT="\xE2\x9C\x94 Enabled"
echo -e "VM-x/AMD-V : $CPU_VIRT"
TOTAL_RAM_RAW=$(free | awk 'NR==2 {print $2}')
TOTAL_RAM=$(format_size "$TOTAL_RAM_RAW")
echo -e "RAM        : $TOTAL_RAM"
TOTAL_SWAP_RAW=$(free | grep Swap | awk '{ print $2 }')
TOTAL_SWAP=$(format_size "$TOTAL_SWAP_RAW")
echo -e "Swap       : $TOTAL_SWAP"
# total disk size is calculated by adding all partitions of the types listed below (after the -t flags)
TOTAL_DISK_RAW=$(df -t simfs -t ext2 -t ext3 -t ext4 -t btrfs -t xfs -t vfat -t exfat -t ntfs -t swap --total 2>/dev/null | grep total | awk '{ print $2 }')
TOTAL_DISK=$(format_size "$TOTAL_DISK_RAW")
echo -e "Disk       : $TOTAL_DISK"
DISTRO=$(grep 'PRETTY_NAME' /etc/os-release | cut -d '"' -f 2 )
echo -e "Distro     : $DISTRO"
KERNEL=$(uname -r)
echo -e "Kernel     : $KERNEL"
VIRT=$(systemd-detect-virt 2>/dev/null)
VIRT=${VIRT^^} || VIRT="UNKNOWN"
echo -e "VM Type    : $VIRT"
[[ -z "$IPV4_CHECK" ]] && ONLINE="\xE2\x9D\x8C Offline / " || ONLINE="\xE2\x9C\x94 Online / "
[[ -z "$IPV6_CHECK" ]] && ONLINE+="\xE2\x9D\x8C Offline" || ONLINE+="\xE2\x9C\x94 Online"
echo -e "IPv4/IPv6  : $ONLINE"

# Function to get information from IP Address using ip-api.com free API
function ip_info() {
	# check for curl vs wget
	[[ -n $LOCAL_CURL ]] && DL_CMD="curl -s" || DL_CMD="wget -qO-"

	# declare local vars
	local ip6me_resp net_type net_ip response country region region_code city isp org as

	ip6me_resp="$($DL_CMD http://ip6.me/api/)"
	net_type="$(echo "$ip6me_resp" | cut -d, -f1)"
	net_ip="$(echo "$ip6me_resp" | cut -d, -f2)"

	response=$($DL_CMD http://ip-api.com/json/"$net_ip")

	# if no response, skip output
	if [[ -z $response ]]; then
		return
	fi

	country=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^country/ {print $2}' | head -1 | sed 's/^"\(.*\)"$/\1/')
	region=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^regionName/ {print $2}' | sed 's/^"\(.*\)"$/\1/')
	region_code=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^region/ {print $2}' | head -1 | sed 's/^"\(.*\)"$/\1/')
	city=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^city/ {print $2}' | sed 's/^"\(.*\)"$/\1/')
	isp=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^isp/ {print $2}' | sed 's/^"\(.*\)"$/\1/')
	org=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^org/ {print $2}' | sed 's/^"\(.*\)"$/\1/')
	as=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^as/ {print $2}' | sed 's/^"\(.*\)"$/\1/')

	echo
	echo "$net_type Network Information:"
	echo "---------------------------------"

	if [[ -n "$isp" ]]; then
		echo "ISP        : $isp"
	else
		echo "ISP        : Unknown"
	fi
	if [[ -n "$as" ]]; then
		echo "ASN        : $as"
	else
		echo "ASN        : Unknown"
	fi
	if [[ -n "$org" ]]; then
		echo "Host       : $org"
	fi
	if [[ -n "$city" && -n "$region" ]]; then
		echo "Location   : $city, $region ($region_code)"
	fi
	if [[ -n "$country" ]]; then
		echo "Country    : $country"
	fi

	[[ -n $JSON ]] && JSON_RESULT+=',"ip_info":{"protocol":"'$net_type'","isp":"'$isp'","asn":"'$as'","org":"'$org'","city":"'$city'","region":"'$region'","region_code":"'$region_code'","country":"'$country'"}'
}

if [[ -n $JSON ]]; then
	UPTIME_S=$(awk '{print $1}' /proc/uptime)
	IPV4=$([ -n "$IPV4_CHECK" ] && echo "true" || echo "false")
	IPV6=$([ -n "$IPV6_CHECK" ] && echo "true" || echo "false")
	AES=$([[ "$CPU_AES" = *Enabled* ]] && echo "true" || echo "false")
	CPU_VIRT_BOOL=$([[ "$CPU_VIRT" = *Enabled* ]] && echo "true" || echo "false")
	JSON_RESULT='{"version":"'$YABS_VERSION'","time":"'$TIME_START'","os":{"arch":"'$ARCH'","distro":"'$DISTRO'","kernel":"'$KERNEL'",'
	JSON_RESULT+='"uptime":'$UPTIME_S',"vm":"'$VIRT'"},"net":{"ipv4":'$IPV4',"ipv6":'$IPV6'},"cpu":{"model":"'$CPU_PROC'","cores":'$CPU_CORES','
	JSON_RESULT+='"freq":"'$CPU_FREQ'","aes":'$AES',"virt":'$CPU_VIRT_BOOL'},"mem":{"ram":'$TOTAL_RAM_RAW',"ram_units":"KiB","swap":'$TOTAL_SWAP_RAW',"swap_units":"KiB","disk":'$TOTAL_DISK_RAW',"disk_units":"KB"}'
fi

if [ -z $SKIP_NET ]; then
	ip_info
fi

# create a directory in the same location that the script is being run to temporarily store YABS-related files
DATE=$(date -Iseconds | sed -e "s/:/_/g")
YABS_PATH=./$DATE
touch "$DATE.test" 2> /dev/null
# test if the user has write permissions in the current directory and exit if not
if [ ! -f "$DATE.test" ]; then
	echo -e
	echo -e "You do not have write permission in this directory. Switch to an owned directory and re-run the script.\nExiting..."
	exit 1
fi
rm "$DATE.test"
mkdir -p "$YABS_PATH"

# trap CTRL+C signals to exit script cleanly
trap catch_abort INT

# catch_abort
# Purpose: This method will catch CTRL+C signals in order to exit the script cleanly and remove
#          yabs-related files.
function catch_abort() {
	echo -e "\n** Aborting YABS. Cleaning up files...\n"
	rm -rf "$YABS_PATH"
	unset LC_ALL
	exit 0
}

# format_speed
# Purpose: This method is a convenience function to format the output of the fio disk tests which
#          always returns a result in KiB/s (fio terse v3 bandwidth fields are always KiB/s regardless
#          of --kb_base setting). Converts KiB/s to decimal units (KB/s, MB/s, GB/s) for display.
#          Conversion: multiply KiB/s by 1024 to get bytes/s, then divide by 1000, 1000000, or
#          1000000000 to get KB/s, MB/s, or GB/s respectively.
#          Thresholds (in KiB/s): >= 976563 -> GB/s, >= 977 -> MB/s, otherwise -> KB/s
# Parameters:
#          1. RAW - the raw disk speed result (in KiB/s)
# Returns:
#          Formatted disk speed in GB/s, MB/s, or KB/s
function format_speed {
	RAW=$1 # disk speed in KiB/s
	RESULT=$RAW
	local UNIT="KB/s"

	# ensure raw value is not null, if it is, return blank
	if [ -z "$RAW" ]; then
		echo ""
		return 0
	fi

	# check if disk speed >= 1 GB/s (976563 KiB/s = 1,000,000,000 bytes/s)
	if [ "$RAW" -ge 976563 ]; then
		UNIT="GB/s"
		RESULT=$(awk -v a="$RAW" 'BEGIN { print a * 1024 / 1000000000 }')
	# check if disk speed >= 1 MB/s (977 KiB/s ~ 1,000,000 bytes/s)
	elif [ "$RAW" -ge 977 ]; then
		UNIT="MB/s"
		RESULT=$(awk -v a="$RAW" 'BEGIN { print a * 1024 / 1000000 }')
	else
		# convert KiB/s to KB/s (multiply by 1.024)
		RESULT=$(awk -v a="$RAW" 'BEGIN { print a * 1024 / 1000 }')
	fi

	# shorten the formatted result to two decimal places (i.e. x.xx)
	RESULT=$(echo "$RESULT" | awk -F. '{ printf "%0.2f",$1"."substr($2,1,2) }')
	# concat formatted result value with units and return result
	RESULT="$RESULT $UNIT"
	echo "$RESULT"
}

# format_iops
# Purpose: This method is a convenience function to format the output of the raw IOPS result
# Parameters:
#          1. RAW - the raw IOPS result
# Returns:
#          Formatted IOPS (i.e. 8, 123, 1.7k, 275.9k, etc.)
function format_iops {
	RAW=$1 # iops
	RESULT=$RAW

	# ensure raw value is not null, if it is, return blank
	if [ -z "$RAW" ]; then
		echo ""
		return 0
	fi

	# check if IOPS speed > 1k
	if [ "$RAW" -ge 1000 ]; then
		# divide the raw result by 1k
		RESULT=$(awk -v a="$RESULT" 'BEGIN { print a / 1000 }')
		# shorten the formatted result to one decimal place (i.e. x.x)
		RESULT=$(echo "$RESULT" | awk -F. '{ printf "%0.1f",$1"."substr($2,1,1) }')
		RESULT="$RESULT"k
	fi

	echo "$RESULT"
}

# disk_test
# Purpose: This method is designed to test the disk performance of the host using the partition that the
#          script is being run from using fio random read/write speed tests.
# Parameters:
#          - (none)
function disk_test {
	if [[ "$ARCH" = "aarch64" || "$ARCH" = "arm" ]]; then
		FIO_SIZE=512M
	else
		FIO_SIZE=2G
	fi

	# run a quick test to generate the fio test file to be used by the actual tests
	echo -en "Generating fio test file..."
	$FIO_CMD --name=setup --ioengine=libaio --rw=read --bs=64k --iodepth=64 --numjobs=2 --size=$FIO_SIZE --runtime=1 --gtod_reduce=1 --filename="$DISK_PATH/test.fio" --direct=1 --minimal &> /dev/null
	echo -en "\r\033[0K"

	# get array of block sizes to evaluate
	BLOCK_SIZES=("$@")

	for BS in "${BLOCK_SIZES[@]}"; do
		# run rand read/write mixed fio test with block size = $BS
		echo -en "Running fio random mixed R+W disk test with $BS block size..."
		DISK_TEST=$(timeout 35 "$FIO_CMD" --name=rand_rw_"$BS" --ioengine=libaio --rw=randrw --rwmixread=50 --bs="$BS" --iodepth=64 --numjobs=2 --size="$FIO_SIZE" --runtime=30 --gtod_reduce=1 --direct=1 --filename="$DISK_PATH/test.fio" --group_reporting --minimal 2> /dev/null | grep rand_rw_"$BS")
		DISK_IOPS_R=$(echo "$DISK_TEST" | awk -F';' '{print $8}')
		DISK_IOPS_W=$(echo "$DISK_TEST" | awk -F';' '{print $49}')
		DISK_IOPS=$(awk -v a="$DISK_IOPS_R" -v b="$DISK_IOPS_W" 'BEGIN { print a + b }')
		DISK_TEST_R=$(echo "$DISK_TEST" | awk -F';' '{print $7}')
		DISK_TEST_W=$(echo "$DISK_TEST" | awk -F';' '{print $48}')
		DISK_TEST=$(awk -v a="$DISK_TEST_R" -v b="$DISK_TEST_W" 'BEGIN { print a + b }')
		DISK_RESULTS_RAW+=( "$DISK_TEST" "$DISK_TEST_R" "$DISK_TEST_W" "$DISK_IOPS" "$DISK_IOPS_R" "$DISK_IOPS_W" )

		DISK_IOPS=$(format_iops "$DISK_IOPS")
		DISK_IOPS_R=$(format_iops "$DISK_IOPS_R")
		DISK_IOPS_W=$(format_iops "$DISK_IOPS_W")
		DISK_TEST=$(format_speed "$DISK_TEST")
		DISK_TEST_R=$(format_speed "$DISK_TEST_R")
		DISK_TEST_W=$(format_speed "$DISK_TEST_W")

		DISK_RESULTS+=( "$DISK_TEST" "$DISK_TEST_R" "$DISK_TEST_W" "$DISK_IOPS" "$DISK_IOPS_R" "$DISK_IOPS_W" )
		echo -en "\r\033[0K"
	done
}

# dd_test
# Purpose: This method is invoked if the fio disk test failed. dd sequential speed tests are
#          not indiciative or real-world results, however, some form of disk speed measure
#          is better than nothing.
# Parameters:
#          - (none)
function dd_test {
	I=0
	DISK_WRITE_TEST_RES=()
	DISK_READ_TEST_RES=()
	DISK_WRITE_TEST_AVG=0
	DISK_READ_TEST_AVG=0

	# run the disk speed tests (write and read) thrice over
	while [ $I -lt 3 ]
	do
		# write test using dd, "direct" flag is used to test direct I/O for data being stored to disk
		DISK_WRITE_TEST=$(dd if=/dev/zero of="$DISK_PATH/$DATE.test" bs=64k count=16k oflag=direct |& grep copied | awk '{ print $(NF-1) " " $(NF)}')
		VAL=$(echo "$DISK_WRITE_TEST" | cut -d " " -f 1)
		[[ "$DISK_WRITE_TEST" == *"GB"* ]] && VAL=$(awk -v a="$VAL" 'BEGIN { print a * 1000 }')
		DISK_WRITE_TEST_RES+=( "$DISK_WRITE_TEST" )
		DISK_WRITE_TEST_AVG=$(awk -v a="$DISK_WRITE_TEST_AVG" -v b="$VAL" 'BEGIN { print a + b }')

		# read test using dd using the 1G file written during the write test
		DISK_READ_TEST=$(dd if="$DISK_PATH/$DATE.test" of=/dev/null bs=8k |& grep copied | awk '{ print $(NF-1) " " $(NF)}')
		VAL=$(echo "$DISK_READ_TEST" | cut -d " " -f 1)
		[[ "$DISK_READ_TEST" == *"GB"* ]] && VAL=$(awk -v a="$VAL" 'BEGIN { print a * 1000 }')
		DISK_READ_TEST_RES+=( "$DISK_READ_TEST" )
		DISK_READ_TEST_AVG=$(awk -v a="$DISK_READ_TEST_AVG" -v b="$VAL" 'BEGIN { print a + b }')

		I=$(( I + 1 ))
	done
	# calculate the write and read speed averages using the results from the three runs
	DISK_WRITE_TEST_AVG=$(awk -v a="$DISK_WRITE_TEST_AVG" 'BEGIN { print a / 3 }')
	DISK_READ_TEST_AVG=$(awk -v a="$DISK_READ_TEST_AVG" 'BEGIN { print a / 3 }')
}

# check if disk performance is being tested and the host has required space (2G)
AVAIL_SPACE=$(df -k . | awk 'NR==2{print $4}')
if [[ -z "$SKIP_FIO" && "$AVAIL_SPACE" -lt 2097152 && "$ARCH" != "aarch64" && "$ARCH" != "arm" ]]; then # 2GB = 2097152KB
	echo -e "\nLess than 2GB of space available. Skipping disk test..."
elif [[ -z "$SKIP_FIO" && "$AVAIL_SPACE" -lt 524288 && ("$ARCH" = "aarch64" || "$ARCH" = "arm") ]]; then # 512MB = 524288KB
	echo -e "\nLess than 512MB of space available. Skipping disk test..."
# if the skip disk flag was set, skip the disk performance test, otherwise test disk performance
elif [ -z "$SKIP_FIO" ]; then
	# Perform ZFS filesystem detection and determine if we have enough free space according to spa_asize_inflation
	ZFSCHECK="/sys/module/zfs/parameters/spa_asize_inflation"
	if [[ -f "$ZFSCHECK" ]]; then
    # Calculate mul_spa, which is assumed to be an integer (e.g., 2 * 2 = 4)
    mul_spa=$(( $(cat /sys/module/zfs/parameters/spa_asize_inflation) * 2 ))
    warning=0
    poss=()

    # Find relevant filesystem paths that are parent directories or the current directory itself
    for pathls in $(df -Th | awk '{print $7}' | tail -n +2)
    do
        # Check if PWD starts with (is a subdirectory of or same as) pathls
        if [[ "${PWD}" == "${pathls}"* ]]; then
            poss+=("$pathls")
        fi
    done

    long=""
    m=-1 # Initialize max length to -1 to ensure the first valid path is picked
    # Select the longest matching path from the 'poss' array
    # This ensures we get the most specific mounted point for the current directory
    for x in "${poss[@]}"
    do
        if [ "${#x}" -gt "$m" ];then
            m=${#x}
            long=$x
        fi
    done

    # Proceed only if a relevant ZFS path was found
    if [[ -n "$long" ]]; then
        # Get the 'Avail' space directly for the detected path and explicitly for ZFS type
        # The 'Avail' column is the 5th field in `df -Th` output (-T adds a Type column, shifting fields right)
        # Example: '7.3T', '104G', '17G'
        avail_space_with_unit=$(df -Th | grep -w "$long" | awk '$2 == "zfs" {print $5; exit}')

        # If a valid free space value was extracted
        if [[ -n "$avail_space_with_unit" ]]; then
            # Use awk to parse the numeric part and unit, then convert to Gigabytes (integer)
            # This handles units like T, G, M, K, or empty (assumed bytes) and rounds to nearest integer
            free_space_gb_int=$(echo "$avail_space_with_unit" | awk '
            {
                # Extract numeric part and unit
                numeric_part = $0;
                unit = "";
                # Use match to find the number and an optional unit at the end
                if (match($0, /([0-9.]+)([KMGTB]?)$/)) {
                    numeric_part = substr($0, RSTART, RLENGTH - length(substr($0, RSTART + RLENGTH - 1, 1)));
                    unit = substr($0, RSTART + RLENGTH - 1, 1);
                    # If the last character was part of the number (e.g., "1.2"), unit should be empty
                    if (unit ~ /[0-9.]/) {
                        unit = "";
                    }
                }

                # Convert unit to uppercase for consistent logic
                unit = toupper(unit);

                converted_value_gb = 0;
                if (unit == "T") {
                    converted_value_gb = numeric_part * 1024;
                } else if (unit == "G") {
                    converted_value_gb = numeric_part;
                } else if (unit == "M") {
                    converted_value_gb = numeric_part / 1024;
                } else if (unit == "K") {
                    converted_value_gb = numeric_part / (1024 * 1024);
                } else if (unit == "B" || unit == "") { # Assume bytes if unit is B or empty
                    converted_value_gb = numeric_part / (1024 * 1024 * 1024);
                }

                # Print rounded to nearest integer
                printf "%.0f\n", converted_value_gb;
            }')

            # Now, perform the arithmetic comparison with the integer free_space_gb_int
            if ((free_space_gb_int < mul_spa)); then
                warning=1
            fi
        else
            # Handle case where avail_space_with_unit doesn't match expected format
            echo "Warning: Could not parse free space format for $long: '$avail_space_with_unit'"
            # Potentially set warning=1 here if unparseable space is critical
        fi
    else
        echo "Note: No relevant filesystem path detected for current directory ($PWD)."
    fi

    # Display warning if conditions are met
    if [[ $warning -eq 1 ]];then
        echo -en "\nWarning! You are running YABS on a ZFS Filesystem and your disk space is too low for the fio test. Your test results will be inaccurate. You need at least $mul_spa GB free in order to complete this test accurately. For more information, please see https://github.com/masonr/yet-another-bench-script/issues/13\n"
    fi
fi

	echo -en "\nPreparing system for disk tests..."

	# create temp directory to store disk write/read test files
	DISK_PATH=$YABS_PATH/disk
	mkdir -p "$DISK_PATH"

	if [[ -z "$PREFER_BIN" && -n "$LOCAL_FIO" ]]; then # local fio has been detected, use instead of pre-compiled binary
		FIO_CMD=fio
	else
		# download fio binary
		if [[ -n $LOCAL_CURL ]]; then
			curl -s --connect-timeout 5 --retry 5 --retry-delay 0 https://raw.githubusercontent.com/masonr/yet-another-bench-script/master/bin/fio/fio_$ARCH -o "$DISK_PATH/fio"
		else
			wget -q -T 5 -t 5 -w 0 https://raw.githubusercontent.com/masonr/yet-another-bench-script/master/bin/fio/fio_$ARCH -O "$DISK_PATH/fio"
		fi

		if [ ! -f "$DISK_PATH/fio" ]; then # ensure fio binary download successfully
			echo -en "\r\033[0K"
			echo -e "Fio binary download failed. Running dd test as fallback...."
			DD_FALLBACK=True
		else
			chmod +x "$DISK_PATH/fio"
			FIO_CMD=$DISK_PATH/fio
		fi
	fi

	if [ -z "$DD_FALLBACK" ]; then # if not falling back on dd tests, run fio test
		echo -en "\r\033[0K"

		# init global array to store disk performance values
		declare -a DISK_RESULTS DISK_RESULTS_RAW
		# disk block sizes to evaluate
		BLOCK_SIZES=( "4k" "64k" "512k" "1m" )

		# execute disk performance test
		disk_test "${BLOCK_SIZES[@]}"
	fi

	if [[ -n "$DD_FALLBACK" || ${#DISK_RESULTS[@]} -eq 0 ]]; then # fio download failed or test was killed or returned an error, run dd test instead
		if [ -z "$DD_FALLBACK" ]; then # print error notice if ended up here due to fio error
			echo -e "fio disk speed tests failed. Run manually to determine cause.\nRunning dd test as fallback..."
		fi

		dd_test

		# format the speed averages by converting to GB/s if > 1000 MB/s
		if [ "$(echo "$DISK_WRITE_TEST_AVG" | cut -d "." -f 1)" -ge 1000 ]; then
			DISK_WRITE_TEST_AVG=$(awk -v a="$DISK_WRITE_TEST_AVG" 'BEGIN { print a / 1000 }')
			DISK_WRITE_TEST_UNIT="GB/s"
		else
			DISK_WRITE_TEST_UNIT="MB/s"
		fi
		if [ "$(echo "$DISK_READ_TEST_AVG" | cut -d "." -f 1)" -ge 1000 ]; then
			DISK_READ_TEST_AVG=$(awk -v a="$DISK_READ_TEST_AVG" 'BEGIN { print a / 1000 }')
			DISK_READ_TEST_UNIT="GB/s"
		else
			DISK_READ_TEST_UNIT="MB/s"
		fi

		# print dd sequential disk speed test results
		echo -e
		echo -e "dd Sequential Disk Speed Tests:"
		echo -e "---------------------------------"
		printf "%-6s | %-6s %-4s | %-6s %-4s | %-6s %-4s | %-6s %-4s\n" "" "Test 1" "" "Test 2" ""  "Test 3" "" "Avg" ""
		printf "%-6s | %-6s %-4s | %-6s %-4s | %-6s %-4s | %-6s %-4s\n" "" "" "" "" "" "" "" "" ""
		printf "%-6s | %-11s | %-11s | %-11s | %-6.2f %-4s\n" "Write" "${DISK_WRITE_TEST_RES[0]}" "${DISK_WRITE_TEST_RES[1]}" "${DISK_WRITE_TEST_RES[2]}" "${DISK_WRITE_TEST_AVG}" "${DISK_WRITE_TEST_UNIT}"
		printf "%-6s | %-11s | %-11s | %-11s | %-6.2f %-4s\n" "Read" "${DISK_READ_TEST_RES[0]}" "${DISK_READ_TEST_RES[1]}" "${DISK_READ_TEST_RES[2]}" "${DISK_READ_TEST_AVG}" "${DISK_READ_TEST_UNIT}"
	else # fio tests completed successfully, print results
		CURRENT_PARTITION=$(df -P . 2>/dev/null | tail -1 | cut -d' ' -f 1)
		[[ -n $JSON ]] && JSON_RESULT+=',"partition":"'$CURRENT_PARTITION'","fio":['
		DISK_RESULTS_NUM=$((${#DISK_RESULTS[@]} / 6))
		DISK_COUNT=0

		# print disk speed test results
		echo -e "fio Disk Speed Tests (Mixed R/W 50/50) (Partition $CURRENT_PARTITION):"
		echo -e "---------------------------------"

		while [[ $DISK_COUNT -lt $DISK_RESULTS_NUM ]] ; do
			if [[ $DISK_COUNT -gt 0 ]]; then printf "%-10s | %-20s | %-20s\n" "" "" ""; fi
			printf "%-10s | %-11s %8s | %-11s %8s\n" "Block Size" "${BLOCK_SIZES[DISK_COUNT]}" "(IOPS)" "${BLOCK_SIZES[DISK_COUNT+1]}" "(IOPS)"
			printf "%-10s | %-11s %8s | %-11s %8s\n" "  ------" "---" "---- " "----" "---- "
			printf "%-10s | %-11s %8s | %-11s %8s\n" "Read" "${DISK_RESULTS[DISK_COUNT*6+1]}" "(${DISK_RESULTS[DISK_COUNT*6+4]})" "${DISK_RESULTS[(DISK_COUNT+1)*6+1]}" "(${DISK_RESULTS[(DISK_COUNT+1)*6+4]})"
			printf "%-10s | %-11s %8s | %-11s %8s\n" "Write" "${DISK_RESULTS[DISK_COUNT*6+2]}" "(${DISK_RESULTS[DISK_COUNT*6+5]})" "${DISK_RESULTS[(DISK_COUNT+1)*6+2]}" "(${DISK_RESULTS[(DISK_COUNT+1)*6+5]})"
			printf "%-10s | %-11s %8s | %-11s %8s\n" "Total" "${DISK_RESULTS[DISK_COUNT*6]}" "(${DISK_RESULTS[DISK_COUNT*6+3]})" "${DISK_RESULTS[(DISK_COUNT+1)*6]}" "(${DISK_RESULTS[(DISK_COUNT+1)*6+3]})"
			if [[ -n $JSON ]]; then
				JSON_RESULT+='{"bs":"'${BLOCK_SIZES[DISK_COUNT]}'","speed_r":'${DISK_RESULTS_RAW[DISK_COUNT*6+1]}',"iops_r":'${DISK_RESULTS_RAW[DISK_COUNT*6+4]}
				JSON_RESULT+=',"speed_w":'${DISK_RESULTS_RAW[DISK_COUNT*6+2]}',"iops_w":'${DISK_RESULTS_RAW[DISK_COUNT*6+5]}',"speed_rw":'${DISK_RESULTS_RAW[DISK_COUNT*6]}
				JSON_RESULT+=',"iops_rw":'${DISK_RESULTS_RAW[DISK_COUNT*6+3]}',"speed_units":"KBps"},'
				JSON_RESULT+='{"bs":"'${BLOCK_SIZES[DISK_COUNT+1]}'","speed_r":'${DISK_RESULTS_RAW[(DISK_COUNT+1)*6+1]}',"iops_r":'${DISK_RESULTS_RAW[(DISK_COUNT+1)*6+4]}
				JSON_RESULT+=',"speed_w":'${DISK_RESULTS_RAW[(DISK_COUNT+1)*6+2]}',"iops_w":'${DISK_RESULTS_RAW[(DISK_COUNT+1)*6+5]}',"speed_rw":'${DISK_RESULTS_RAW[(DISK_COUNT+1)*6]}
				JSON_RESULT+=',"iops_rw":'${DISK_RESULTS_RAW[(DISK_COUNT+1)*6+3]}',"speed_units":"KBps"},'
			fi
			DISK_COUNT=$((DISK_COUNT + 2))
		done
		[[ -n $JSON ]] && JSON_RESULT=${JSON_RESULT::${#JSON_RESULT}-1} && JSON_RESULT+=']'
	fi
fi

# iperf_test
# Purpose: This method is designed to test the network performance of the host by executing an
#          iperf3 test to/from the public iperf server passed to the function. Both directions
#          (send and receive) are tested.
# Parameters:
#          1. URL - URL/domain name of the iperf server
#          2. PORTS - the range of ports on which the iperf server operates
#          3. HOST - the friendly name of the iperf server host/owner
#          4. FLAGS - any flags that should be passed to the iperf command
function iperf_test {
	URL=$1
	PORTS=$2
	HOST=$3
	FLAGS=$4

	# attempt the iperf send test 3 times, allowing for a slot to become available on the
	#   server or to throw out any bad/error results
	I=1
	while [ $I -le 3 ]
	do
		echo -en "Performing $MODE iperf3 send test to $HOST (Attempt #$I of 3)..."
		# select a random iperf port from the range provided
		PORT=$(shuf -i "$PORTS" -n 1)
		# run the iperf test sending data from the host to the iperf server; includes
		#   a timeout of 15s in case the iperf server is not responding; uses 8 parallel
		#   threads for the network test
		IPERF_RUN_SEND="$(timeout 15 "$IPERF_CMD" "$FLAGS" -c "$URL" -p "$PORT" -P 8 2> /dev/null)"
		# check if iperf exited cleanly and did not return an error
		if [[ "$IPERF_RUN_SEND" == *"receiver"* && "$IPERF_RUN_SEND" != *"error"* ]]; then
			# test did not result in an error, parse speed result
			SPEED=$(echo "${IPERF_RUN_SEND}" | grep SUM | grep receiver | awk '{ print $6 }')
			# if speed result is blank or bad (0.00), rerun, otherwise set counter to exit loop
			[[ -z $SPEED || "$SPEED" == "0.00" ]] && I=$(( I + 1 )) || I=11
		else
			# if iperf server is not responding, set counter to exit, otherwise increment, sleep, and rerun
			[[ "$IPERF_RUN_SEND" == *"unable to connect"* ]] && I=11 || I=$(( I + 1 )) && sleep 2
		fi
		echo -en "\r\033[0K"
	done

	# small sleep necessary to give iperf server a breather to get ready for a new test
	sleep 1

	# attempt the iperf receive test 3 times, allowing for a slot to become available on
	#   the server or to throw out any bad/error results
	J=1
	while [ $J -le 3 ]
	do
		echo -n "Performing $MODE iperf3 recv test from $HOST (Attempt #$J of 3)..."
		# select a random iperf port from the range provided
		PORT=$(shuf -i "$PORTS" -n 1)
		# run the iperf test receiving data from the iperf server to the host; includes
		#   a timeout of 15s in case the iperf server is not responding; uses 8 parallel
		#   threads for the network test
		IPERF_RUN_RECV="$(timeout 15 "$IPERF_CMD" "$FLAGS" -c "$URL" -p "$PORT" -P 8 -R 2> /dev/null)"
		# check if iperf exited cleanly and did not return an error
		if [[ "$IPERF_RUN_RECV" == *"receiver"* && "$IPERF_RUN_RECV" != *"error"* ]]; then
			# test did not result in an error, parse speed result
			SPEED=$(echo "${IPERF_RUN_RECV}" | grep SUM | grep receiver | awk '{ print $6 }')
			# if speed result is blank or bad (0.00), rerun, otherwise set counter to exit loop
			[[ -z $SPEED || "$SPEED" == "0.00" ]] && J=$(( J + 1 )) || J=11
		else
			# if iperf server is not responding, set counter to exit, otherwise increment, sleep, and rerun
			[[ "$IPERF_RUN_RECV" == *"unable to connect"* ]] && J=11 || J=$(( J + 1 )) && sleep 2
		fi
		echo -en "\r\033[0K"
	done

	# Run a latency test via ping -c1 command -> will return "xx.x ms"
	[[ -n $LOCAL_PING ]] && LATENCY_RUN="$(ping "$FLAGS" -c1 "$URL" 2>/dev/null | grep -o 'time=.*' | sed 's/time=//')"
	[[ -z $LATENCY_RUN ]] && LATENCY_RUN="--"

	# parse the resulting send and receive speed results
	IPERF_SENDRESULT="$(echo "${IPERF_RUN_SEND}" | grep SUM | grep receiver)"
	IPERF_RECVRESULT="$(echo "${IPERF_RUN_RECV}" | grep SUM | grep receiver)"
	LATENCY_RESULT="${LATENCY_RUN}"
}

# launch_iperf
# Purpose: This method is designed to facilitate the execution of iperf network speed tests to
#          each public iperf server in the iperf server locations array.
# Parameters:
#          1. MODE - indicates the type of iperf tests to run (IPv4 or IPv6)
function launch_iperf {
	MODE=$1
	[[ "$MODE" == *"IPv6"* ]] && IPERF_FLAGS="-6" || IPERF_FLAGS="-4"

	# print iperf3 network speed results as they are completed
	echo -e
	echo -e "iperf3 Network Speed Tests ($MODE):"
	echo -e "---------------------------------"
	printf "%-15s | %-25s | %-15s | %-15s | %-15s\n" "Provider" "Location (Link)" "Send Speed" "Recv Speed" "Ping"
	printf "%-15s | %-25s | %-15s | %-15s | %-15s\n" "-----" "-----" "----" "----" "----"

	# loop through iperf locations array to run iperf test using each public iperf server
	for (( i = 0; i < IPERF_LOCS_NUM; i++ )); do
		# test if the current iperf location supports the network mode being tested (IPv4/IPv6)
		if [[ "${IPERF_LOCS[i*5+4]}" == *"$MODE"* ]]; then
			# call the iperf_test function passing the required parameters
			iperf_test "${IPERF_LOCS[i*5]}" "${IPERF_LOCS[i*5+1]}" "${IPERF_LOCS[i*5+2]}" "$IPERF_FLAGS"
			# parse the send and receive speed results
			IPERF_SENDRESULT_VAL=$(echo "$IPERF_SENDRESULT" | awk '{ print $6 }')
			IPERF_SENDRESULT_UNIT=$(echo "$IPERF_SENDRESULT" | awk '{ print $7 }')
			IPERF_RECVRESULT_VAL=$(echo "$IPERF_RECVRESULT" | awk '{ print $6 }')
			IPERF_RECVRESULT_UNIT=$(echo "$IPERF_RECVRESULT" | awk '{ print $7 }')
			LATENCY_VAL="${LATENCY_RESULT}"
			# if the results are blank, then the server is "busy" and being overutilized
			[[ -z $IPERF_SENDRESULT_VAL || "$IPERF_SENDRESULT_VAL" == *"0.00"* ]] && IPERF_SENDRESULT_VAL="busy" && IPERF_SENDRESULT_UNIT=""
			[[ -z $IPERF_RECVRESULT_VAL || "$IPERF_RECVRESULT_VAL" == *"0.00"* ]] && IPERF_RECVRESULT_VAL="busy" && IPERF_RECVRESULT_UNIT=""
			# print the speed results for the iperf location currently being evaluated
			printf "%-15s | %-25s | %-15s | %-15s | %-15s\n" "${IPERF_LOCS[i*5+2]}" "${IPERF_LOCS[i*5+3]}" "$IPERF_SENDRESULT_VAL $IPERF_SENDRESULT_UNIT" "$IPERF_RECVRESULT_VAL $IPERF_RECVRESULT_UNIT" "$LATENCY_VAL"
			if [[ -n $JSON ]]; then
				JSON_RESULT+='{"mode":"'$MODE'","provider":"'${IPERF_LOCS[i*5+2]}'","loc":"'${IPERF_LOCS[i*5+3]}
				JSON_RESULT+='","send":"'$IPERF_SENDRESULT_VAL' '$IPERF_SENDRESULT_UNIT'","recv":"'$IPERF_RECVRESULT_VAL' '$IPERF_RECVRESULT_UNIT'","latency":"'$LATENCY_VAL'"},'
			fi
		fi
	done
}

# if the skip iperf flag was set, skip the network performance test, otherwise test network performance
if [ -z "$SKIP_IPERF" ]; then

	if [[ -z "$PREFER_BIN" && -n "$LOCAL_IPERF" ]]; then # local iperf has been detected, use instead of pre-compiled binary
		IPERF_CMD=iperf3
	else
		# create a temp directory to house the required iperf binary and library
		IPERF_PATH=$YABS_PATH/iperf
		mkdir -p "$IPERF_PATH"

		# download iperf3 binary
		if [[ -n $LOCAL_CURL ]]; then
			curl -s --connect-timeout 5 --retry 5 --retry-delay 0 https://raw.githubusercontent.com/masonr/yet-another-bench-script/master/bin/iperf/iperf3_$ARCH -o "$IPERF_PATH/iperf3"
		else
			wget -q -T 5 -t 5 -w 0 https://raw.githubusercontent.com/masonr/yet-another-bench-script/master/bin/iperf/iperf3_$ARCH -O "$IPERF_PATH/iperf3"
		fi

		if [ ! -f "$IPERF_PATH/iperf3" ]; then # ensure iperf3 binary downloaded successfully
			IPERF_DL_FAIL=True
		else
			chmod +x "$IPERF_PATH/iperf3"
			IPERF_CMD=$IPERF_PATH/iperf3
		fi
	fi

	# array containing all currently available iperf3 public servers to use for the network test
	# format: "1" "2" "3" "4" "5" \
	#   1. domain name of the iperf server
	#   2. range of ports that the iperf server is running on (lowest-highest)
	#   3. friendly name of the host/owner of the iperf server
	#   4. location and advertised speed link of the iperf server
	#   5. network modes supported by the iperf server (IPv4 = IPv4-only, IPv4|IPv6 = IPv4 + IPv6, etc.)
	IPERF_LOCS=( \
		"lon.speedtest.clouvider.net" "5200-5209" "Clouvider" "London, UK (10G)" "IPv4|IPv6" \
		"iperf-ams-nl.eranium.net" "5201-5210" "Eranium" "Amsterdam, NL (100G)" "IPv4|IPv6" \
		#"speedtest.extra.telia.fi" "5201-5208" "Telia" "Helsinki, FI (10G)" "IPv4"
		# AFR placeholder
		"speedtest.uztelecom.uz" "5200-5209" "Uztelecom" "Tashkent, UZ (10G)" "IPv4|IPv6" \
		"speedtest.sin1.sg.leaseweb.net" "5201-5210" "Leaseweb" "Singapore, SG (10G)" "IPv4|IPv6" \
		"la.speedtest.clouvider.net" "5200-5209" "Clouvider" "Los Angeles, CA, US (10G)" "IPv4|IPv6" \
		"speedtest.nyc1.us.leaseweb.net" "5201-5210" "Leaseweb" "NYC, NY, US (10G)" "IPv4|IPv6" \
		"speedtest.sao1.edgoo.net" "9204-9240" "Edgoo" "Sao Paulo, BR (1G)" "IPv4|IPv6"
	)

	# if the "REDUCE_NET" flag is activated, then do a shorter iperf test with only three locations
	# (Clouvider London, Clouvider NYC, and Online.net France)
	if [ -n "$REDUCE_NET" ]; then
		IPERF_LOCS=( \
			"lon.speedtest.clouvider.net" "5200-5209" "Clouvider" "London, UK (10G)" "IPv4|IPv6" \
			"speedtest.sin1.sg.leaseweb.net" "5201-5210" "Leaseweb" "Singapore, SG (10G)" "IPv4|IPv6" \
			"speedtest.nyc1.us.leaseweb.net" "5201-5210" "Leaseweb" "NYC, NY, US (10G)" "IPv4|IPv6" \
		)
	fi

	# if custom iperf servers are provided, use them instead of the default servers
	if [ -n "$IPERF_SERVERS" ]; then
		# clear the default iperf locations array
		IPERF_LOCS=()

		# parse the custom iperf servers and add them to the array
		IFS=',' read -ra CUSTOM_SERVERS <<< "$IPERF_SERVERS"
		for server in "${CUSTOM_SERVERS[@]}"; do
			# parse server definition: host:port_range:name:location:network_modes
			IFS=':' read -ra SERVER_PARTS <<< "$server"
			if [ ${#SERVER_PARTS[@]} -eq 5 ]; then
				IPERF_LOCS+=("${SERVER_PARTS[0]}" "${SERVER_PARTS[1]}" "${SERVER_PARTS[2]}" "${SERVER_PARTS[3]}" "${SERVER_PARTS[4]}")
			else
				echo -e "Invalid server format: $server (expected format: host:port_range:name:location:network_modes)"
			fi
		done
	fi

	# get the total number of iperf locations (total array size divided by 5 since each location has 5 elements)
	IPERF_LOCS_NUM=${#IPERF_LOCS[@]}
	IPERF_LOCS_NUM=$((IPERF_LOCS_NUM / 5))

	if [ -z "$IPERF_DL_FAIL" ]; then
		[[ -n $JSON ]] && JSON_RESULT+=',"iperf":['
		# check if the host has IPv4 connectivity, if so, run iperf3 IPv4 tests
		[ -n "$IPV4_CHECK" ] && launch_iperf "IPv4"
		# check if the host has IPv6 connectivity, if so, run iperf3 IPv6 tests
		[ -n "$IPV6_CHECK" ] && launch_iperf "IPv6"
		[[ -n $JSON ]] && JSON_RESULT=${JSON_RESULT::${#JSON_RESULT}-1} && JSON_RESULT+=']'
	else
		echo -e "\niperf3 binary download failed. Skipping iperf network tests..."
	fi
fi

# launch_geekbench
# Purpose: This method is designed to run the Primate Labs' Geekbench 4/5/6/7 Cross-Platform Benchmark utility
# Parameters:
#          1. VERSION - indicates which Geekbench version to run
function launch_geekbench {
	VERSION=$1

	# create a temp directory to house all geekbench files
	GEEKBENCH_PATH=$YABS_PATH/geekbench_$VERSION
	mkdir -p "$GEEKBENCH_PATH"

	GB_URL=""
	GB_CMD=""
	GB_RUN=""

	# check for curl vs wget
	[[ -n $LOCAL_CURL ]] && DL_CMD="curl -s" || DL_CMD="wget -qO-"

	if [[ $VERSION == *4* && ($ARCH = *aarch64* || $ARCH = *arm*) ]]; then
		echo -e "\nARM architecture not supported by Geekbench 4, use Geekbench 5 or 6."
	elif [[ $VERSION == *4* && $ARCH != *aarch64* && $ARCH != *arm* ]]; then # Geekbench v4
		GB_URL="https://cdn.geekbench.com/Geekbench-4.4.4-Linux.tar.gz"
		[[ "$ARCH" == *"x86"* ]] && GB_CMD="geekbench_x86_32" || GB_CMD="geekbench4"
		GB_RUN="True"
	elif [[ $VERSION == *5* || $VERSION == *6* || $VERSION == *7* ]]; then # Geekbench v5/6/7
		if [[ $ARCH = *x86* && $GEEKBENCH_4 == *False* ]]; then # don't run Geekbench 5/6/7 if on 32-bit arch
			echo -e "\nGeekbench $VERSION cannot run on 32-bit architectures. Re-run with -4 flag to use"
			echo -e "Geekbench 4, which can support 32-bit architectures. Skipping Geekbench $VERSION."
		elif [[ $ARCH = *x86* && $GEEKBENCH_4 == *True* ]]; then
			echo -e "\nGeekbench $VERSION cannot run on 32-bit architectures. Skipping test."
		else
			if [[ $VERSION == *5* ]]; then # Geekbench v5
				[[ $ARCH = *aarch64* || $ARCH = *arm* ]] && GB_URL="https://cdn.geekbench.com/Geekbench-5.5.1-LinuxARMPreview.tar.gz" \
					|| GB_URL="https://cdn.geekbench.com/Geekbench-5.5.1-Linux.tar.gz"
				GB_CMD="geekbench5"
			elif [[ $VERSION == *6* ]]; then # Geekbench v6
				[[ $ARCH = *aarch64* || $ARCH = *arm* ]] && GB_URL="https://cdn.geekbench.com/Geekbench-6.7.1-LinuxARMPreview.tar.gz" \
					|| GB_URL="https://cdn.geekbench.com/Geekbench-6.7.1-Linux.tar.gz"
				GB_CMD="geekbench6"
			else # Geekbench v7
				[[ $ARCH = *aarch64* || $ARCH = *arm* ]] && GB_URL="https://cdn.geekbench.com/Geekbench-7.0.0-LinuxARMPreview.tar.gz" \
					|| GB_URL="https://cdn.geekbench.com/Geekbench-7.0.0-Linux.tar.gz"
				GB_CMD="geekbench7"
			fi
			GB_RUN="True"
		fi
	fi

	if [[ $GB_RUN == *True* ]]; then # run GB test
		echo -en "\nRunning GB$VERSION benchmark test... *cue elevator music*"

		# check for local geekbench installed
		if command -v "$GB_CMD" &>/dev/null; then
			GEEKBENCH_PATH=$(dirname "$(command -v "$GB_CMD")")
		else
			# download the desired Geekbench tarball and extract to geekbench temp directory
			$DL_CMD $GB_URL | tar xz --strip-components=1 -C "$GEEKBENCH_PATH" &>/dev/null
		fi

		# unlock if license file detected
		test -f "geekbench.license" && "$GEEKBENCH_PATH/$GB_CMD" --unlock "$(cat geekbench.license)" > /dev/null 2>&1

		# run the Geekbench test and grep the test results URL given at the end of the test
		GEEKBENCH_TEST=$("$GEEKBENCH_PATH/$GB_CMD" --upload 2>/dev/null | grep "https://browser")

		# ensure the test ran successfully
		if [ -z "$GEEKBENCH_TEST" ]; then
			# detect if CentOS 7 and print a more helpful error message
			if grep -q "CentOS Linux 7" /etc/os-release; then
				echo -e "\r\033[0K CentOS 7 and Geekbench have known issues relating to glibc (see issue #71 for details)"
			fi
			if [[ -z "$IPV4_CHECK" ]]; then
				# Geekbench test failed to download because host lacks IPv4 (cdn.geekbench.com = IPv4 only)
				echo -e "\r\033[0KGeekbench releases can only be downloaded over IPv4. FTP the Geekbench files and run manually."
			elif [[ $VERSION != *4* && $TOTAL_RAM_RAW -le 1048576 ]]; then
				# Geekbench 5/6/7 test failed with low memory (<=1GB)
				echo -e "\r\033[0KGeekbench test failed and low memory was detected. Add at least 1GB of SWAP or use GB4 instead (higher compatibility with low memory systems)."
			elif [[ $ARCH != *x86* ]]; then
				# if the Geekbench test failed for any other reason, exit cleanly and print error message
				echo -e "\r\033[0KGeekbench $VERSION test failed. Run manually to determine cause."
			fi
		else
			# if the Geekbench test succeeded, parse the test results URL
			GEEKBENCH_URL=$(echo -e "$GEEKBENCH_TEST" | head -1 | awk '{ print $1 }')
			GEEKBENCH_URL_CLAIM=$(echo -e "$GEEKBENCH_TEST" | tail -1 | awk '{ print $1 }')
			# sleep a bit to wait for results to be made available on the geekbench website
			sleep 10
			# parse the public results page for the single and multi core geekbench scores
			[[ $VERSION == *4* ]] && GEEKBENCH_SCORES=$($DL_CMD "$GEEKBENCH_URL" | grep "span class='score'") || \
				GEEKBENCH_SCORES=$($DL_CMD "$GEEKBENCH_URL" | grep "div class='score'")

			GEEKBENCH_SCORES_SINGLE=$(echo "$GEEKBENCH_SCORES" | awk -v FS="(>|<)" '{ print $3 }' | head -n 1)
			GEEKBENCH_SCORES_MULTI=$(echo "$GEEKBENCH_SCORES" | awk -v FS="(>|<)" '{ print $3 }' | tail -n 1)

			# print the Geekbench results
			echo -en "\r\033[0K"
			echo -e "Geekbench $VERSION Benchmark Test:"
			echo -e "---------------------------------"
			printf "%-15s | %-30s\n" "Test" "Value"
			printf "%-15s | %-30s\n" "" ""
			printf "%-15s | %-30s\n" "Single Core" "$GEEKBENCH_SCORES_SINGLE"
			printf "%-15s | %-30s\n" "Multi Core" "$GEEKBENCH_SCORES_MULTI"
			printf "%-15s | %-30s\n" "Full Test" "$GEEKBENCH_URL"

			if [[ -n $JSON ]]; then
				JSON_RESULT+='{"version":'$VERSION',"single":'${GEEKBENCH_SCORES_SINGLE:-null}',"multi":'${GEEKBENCH_SCORES_MULTI:-null}
				JSON_RESULT+=',"url":"'$GEEKBENCH_URL'"},'
			fi

			# write the geekbench claim URL to a file so the user can add the results to their profile (if desired)
			[ -n "$GEEKBENCH_URL_CLAIM" ] && echo -e "$GEEKBENCH_URL_CLAIM" >> geekbench_claim.url 2> /dev/null
		fi
	fi
}

# if the skip geekbench flag was set, skip the system performance test, otherwise test system performance
if [ -z "$SKIP_GEEKBENCH" ]; then
	[[ -n $JSON ]] && JSON_RESULT+=",\"geekbench\":["
	if [[ $GEEKBENCH_4 == *True* ]]; then
		launch_geekbench 4
	fi

	if [[ $GEEKBENCH_5 == *True* ]]; then
		launch_geekbench 5
	fi

	if [[ $GEEKBENCH_6 == *True* ]]; then
		launch_geekbench 6
	fi

	if [[ $GEEKBENCH_7 == *True* ]]; then
		launch_geekbench 7
	fi
	[[ -n $JSON ]] && [[ "${JSON_RESULT: -1}" == ',' ]] && JSON_RESULT="${JSON_RESULT%,}"
	[[ -n $JSON ]] && JSON_RESULT+="]"
fi

# finished all tests, clean up all YABS files and exit
echo -e
rm -rf "$YABS_PATH"

YABS_END_TIME=$(date +%s)

# calculate_time_taken
# Purpose: This method is designed to find the time taken for the completion of a YABS run.
# Parameters:
#          1. YABS_END_TIME - time when GB has completed and all files are removed
#          2. YABS_START_TIME - time when YABS is started
function calculate_time_taken() {
	end_time=$1
	start_time=$2

	time_taken=$(( end_time - start_time ))
	if [ ${time_taken} -gt 60 ]; then
		min=$(( time_taken / 60 ))
		sec=$(( time_taken % 60 ))
		echo "YABS completed in ${min} min ${sec} sec"
	else
		echo "YABS completed in ${time_taken} sec"
	fi
	[[ -n $JSON ]] && JSON_RESULT+=",\"runtime\":{\"start\":$start_time,\"end\":$end_time,\"elapsed\":$time_taken}"
}

calculate_time_taken "$YABS_END_TIME" "$YABS_START_TIME"

if [[ -n $JSON ]]; then
	JSON_RESULT+="}"

	# write json results to file
	if [[ $JSON = *w* ]]; then
		echo "$JSON_RESULT" > "$JSON_FILE"
	fi

	# send json results
	if [[ $JSON = *s* ]]; then
		IFS=',' read -r -a JSON_SITES <<< "$JSON_SEND"
		for JSON_SITE in "${JSON_SITES[@]}"
		do
			if [[ -n $LOCAL_CURL ]]; then
				curl -s -H "Content-Type:application/json" -X POST --data ''"$JSON_RESULT"'' "$JSON_SITE"
			else
				wget -qO- --post-data=''"$JSON_RESULT"'' --header='Content-Type:application/json' "$JSON_SITE"
			fi
		done
	fi

	# print json result to screen
	if [[ $JSON = *j* ]]; then
		echo -e
		echo "$JSON_RESULT"
	fi
fi

# reset locale settings
unset LC_ALL
