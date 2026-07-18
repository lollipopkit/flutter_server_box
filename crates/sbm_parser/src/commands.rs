//! 采集命令清单(单一事实来源,见 ADR 0001)
//!
//! 命令、分段符、解析器同版本演进。App 端脚本生成与 monitor 端本机采集
//! 都从这里取命令。命令逐条对照 flutter_server_box
//! `lib/data/model/app/scripts/cmd_types.dart`。
//! `core = false` 的命令开销较大(smartctl/GPU 等),monitor 周期采集
//! 只执行 core 子集,App 按需全量执行。

/// 输出分段符,脚本中每段前输出 `SrvBoxSep.<key>`
pub const SEPARATOR: &str = "SrvBoxSep";

// 命令 key(与 App `ShellCmdType` 枚举名一致)
pub const TIME: &str = "time";
pub const NET: &str = "net";
pub const SYS: &str = "sys";
pub const HOST: &str = "host";
pub const CPU: &str = "cpu";
pub const CPU_BRAND: &str = "cpuBrand";
pub const UPTIME: &str = "uptime";
pub const CONN: &str = "conn";
pub const DISK: &str = "disk";
pub const MEM: &str = "mem";
pub const TEMP_TYPE: &str = "tempType";
pub const TEMP_VAL: &str = "tempVal";
/// Windows 单段温度(InstanceName + 摄氏度 JSON)
pub const TEMP: &str = "temp";
pub const DISKIO: &str = "diskio";
pub const BATTERY: &str = "battery";
pub const SENSORS: &str = "sensors";
pub const DISK_SMART: &str = "diskSmart";
pub const NVIDIA: &str = "nvidia";
pub const AMD: &str = "amd";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CommandSpec {
    pub key: &'static str,
    pub cmd: &'static str,
    /// monitor 周期采集是否执行(高开销命令为 false)
    pub core: bool,
}

/// Linux(App `StatusCmdType`)
pub const LINUX: &[CommandSpec] = &[
    CommandSpec { core: true, key: TIME, cmd: "date +%s" },
    CommandSpec { core: true, key: NET, cmd: "cat /proc/net/dev" },
    CommandSpec { core: true, key: SYS, cmd: "cat /etc/*-release | grep ^PRETTY_NAME" },
    CommandSpec { core: true, key: CPU, cmd: "cat /proc/stat | grep cpu" },
    CommandSpec { core: true, key: UPTIME, cmd: "uptime" },
    CommandSpec { core: true, key: CONN, cmd: "cat /proc/net/snmp" },
    CommandSpec {
        core: true,
        key: DISK,
        cmd: r#"(lsblk --bytes --json --output FSTYPE,PATH,NAME,KNAME,MOUNTPOINT,FSSIZE,FSUSED,FSAVAIL,FSUSE%,UUID 2>/dev/null && echo "LSBLK_SUCCESS") || df -k"#,
    },
    CommandSpec { core: true, key: MEM, cmd: "cat /proc/meminfo | grep -E 'Mem|Swap'" },
    CommandSpec { core: true, key: TEMP_TYPE, cmd: "cat /sys/class/thermal/thermal_zone*/type" },
    CommandSpec { core: true, key: TEMP_VAL, cmd: "cat /sys/class/thermal/thermal_zone*/temp" },
    CommandSpec { core: true, key: HOST, cmd: "cat /etc/hostname" },
    CommandSpec { core: true, key: CPU_BRAND, cmd: r#"cat /proc/cpuinfo | grep "model name""# },
    CommandSpec { core: true, key: DISKIO, cmd: "cat /proc/diskstats" },
    CommandSpec {
        core: false,
        key: BATTERY,
        cmd: r#"for f in /sys/class/power_supply/*/uevent; do cat "$f"; echo; done"#,
    },
    CommandSpec { core: false, key: NVIDIA, cmd: "nvidia-smi -q -x" },
    CommandSpec {
        core: false,
        key: AMD,
        cmd: "if command -v amd-smi >/dev/null 2>&1; then amd-smi list --json && amd-smi metric --json; elif command -v rocm-smi >/dev/null 2>&1; then rocm-smi --json || rocm-smi --showunique --showuse --showtemp --showfan --showclocks --showmemuse --showpower; elif command -v radeontop >/dev/null 2>&1; then timeout 2s radeontop -d - -l 1 | tail -n +2; else echo \"No AMD GPU monitoring tools found\"; fi",
    },
    CommandSpec { core: false, key: SENSORS, cmd: "sensors" },
    CommandSpec {
        core: false,
        key: DISK_SMART,
        cmd: r#"for d in $(lsblk -dn -o KNAME); do smartctl -a -j /dev/$d; echo; done"#,
    },
];

/// BSD/macOS(App `BSDStatusCmdType`)
pub const BSD: &[CommandSpec] = &[
    CommandSpec { core: true, key: TIME, cmd: "date +%s" },
    CommandSpec { core: true, key: NET, cmd: "netstat -ibn" },
    CommandSpec { core: true, key: SYS, cmd: "uname -or" },
    CommandSpec { core: true, key: CPU, cmd: r#"top -l 1 | grep "CPU usage""# },
    CommandSpec { core: true, key: UPTIME, cmd: "uptime" },
    CommandSpec { core: true, key: DISK, cmd: "df -k" },
    CommandSpec { core: true, key: MEM, cmd: "top -l 1 | grep PhysMem" },
    CommandSpec { core: true, key: HOST, cmd: "hostname" },
    CommandSpec { core: true, key: CPU_BRAND, cmd: "sysctl -n machdep.cpu.brand_string" },
];

/// Windows PowerShell(App `WindowsStatusCmdType`)
pub const WINDOWS: &[CommandSpec] = &[
    CommandSpec { core: true, key: TIME, cmd: "[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()" },
    CommandSpec {
        core: true,
        key: NET,
        cmd: r#"$s1 = @(Get-WmiObject Win32_PerfRawData_Tcpip_NetworkInterface | Select-Object Name, BytesReceivedPersec, BytesSentPersec, Timestamp_Sys100NS); Start-Sleep -Seconds 1; $s2 = @(Get-WmiObject Win32_PerfRawData_Tcpip_NetworkInterface | Select-Object Name, BytesReceivedPersec, BytesSentPersec, Timestamp_Sys100NS); @($s1, $s2) | ConvertTo-Json -Depth 5"#,
    },
    CommandSpec { core: true, key: SYS, cmd: "(Get-ComputerInfo).OsName" },
    CommandSpec {
        core: true,
        key: CPU,
        cmd: "Get-WmiObject -Class Win32_Processor | Select-Object Name, LoadPercentage, NumberOfCores, NumberOfLogicalProcessors | ConvertTo-Json",
    },
    CommandSpec {
        core: true,
        key: UPTIME,
        cmd: r#"$up = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime; if ($up.Days -gt 0) { "$($up.Days) days, $($up.Hours):$($up.Minutes.ToString('00'))" } else { "$($up.Hours):$($up.Minutes.ToString('00'))" }"#,
    },
    CommandSpec { core: true, key: CONN, cmd: "(netstat -an | findstr ESTABLISHED | Measure-Object -Line).Count" },
    CommandSpec {
        core: true,
        key: DISK,
        cmd: "Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, Size, FreeSpace, FileSystem | ConvertTo-Json",
    },
    CommandSpec {
        core: true,
        key: MEM,
        cmd: "Get-WmiObject -Class Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory | ConvertTo-Json",
    },
    CommandSpec {
        core: true,
        key: TEMP,
        cmd: r#"Get-CimInstance -ClassName MSAcpi_ThermalZoneTemperature -Namespace root/wmi -ErrorAction SilentlyContinue | Select-Object InstanceName, @{Name='Temperature';Expression={[math]::Round(($_.CurrentTemperature - 2732) / 10, 1)}} | ConvertTo-Json"#,
    },
    CommandSpec { core: true, key: HOST, cmd: r#"Write-Output $env:COMPUTERNAME"# },
    CommandSpec { core: true, key: CPU_BRAND, cmd: "(Get-WmiObject -Class Win32_Processor).Name" },
    CommandSpec {
        core: false,
        key: DISKIO,
        cmd: r#"$s1 = @(Get-WmiObject Win32_PerfRawData_PerfDisk_PhysicalDisk | Select-Object Name, DiskReadBytesPersec, DiskWriteBytesPersec, Timestamp_Sys100NS); Start-Sleep -Seconds 1; $s2 = @(Get-WmiObject Win32_PerfRawData_PerfDisk_PhysicalDisk | Select-Object Name, DiskReadBytesPersec, DiskWriteBytesPersec, Timestamp_Sys100NS); @($s1, $s2) | ConvertTo-Json -Depth 5"#,
    },
    CommandSpec {
        core: false,
        key: BATTERY,
        cmd: "Get-WmiObject -Class Win32_Battery | Select-Object EstimatedChargeRemaining, BatteryStatus | ConvertTo-Json",
    },
    CommandSpec {
        core: false,
        key: NVIDIA,
        cmd: r#"if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) { nvidia-smi -q -x } else { echo "NVIDIA driver not found" }"#,
    },
    CommandSpec {
        core: false,
        key: AMD,
        cmd: r#"if (Get-Command amd-smi -ErrorAction SilentlyContinue) { amd-smi list --json } else { echo "AMD driver not found" }"#,
    },
    CommandSpec {
        core: false,
        key: SENSORS,
        cmd: "Get-CimInstance -ClassName Win32_TemperatureProbe -ErrorAction SilentlyContinue | Select-Object Name, CurrentReading | ConvertTo-Json",
    },
    CommandSpec {
        core: false,
        key: DISK_SMART,
        cmd: "Get-PhysicalDisk | Get-StorageReliabilityCounter | Select-Object DeviceId, Temperature, TemperatureMax, Wear, PowerOnHours | ConvertTo-Json",
    },
];

pub fn commands(system: crate::SystemType) -> &'static [CommandSpec] {
    match system {
        crate::SystemType::Linux => LINUX,
        crate::SystemType::Bsd => BSD,
        crate::SystemType::Windows => WINDOWS,
    }
}
