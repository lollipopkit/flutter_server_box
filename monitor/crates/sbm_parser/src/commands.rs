//! 采集命令清单(单一事实来源,见 ADR 0001)
//!
//! 命令、分段符、解析器同版本演进。App 端脚本生成与 monitor 端本机采集
//! 都从这里取命令。命令逐条对照 flutter_server_box
//! `lib/data/model/app/scripts/cmd_types.dart`(App 专属的 GPU/SMART/
//! battery/sensors 等后置,见 ADR「解析覆盖补全」)。

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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CommandSpec {
    pub key: &'static str,
    pub cmd: &'static str,
}

/// Linux(App `StatusCmdType`)
pub const LINUX: &[CommandSpec] = &[
    CommandSpec { key: TIME, cmd: "date +%s" },
    CommandSpec { key: NET, cmd: "cat /proc/net/dev" },
    CommandSpec { key: SYS, cmd: "cat /etc/*-release | grep ^PRETTY_NAME" },
    CommandSpec { key: CPU, cmd: "cat /proc/stat | grep cpu" },
    CommandSpec { key: UPTIME, cmd: "uptime" },
    CommandSpec { key: CONN, cmd: "cat /proc/net/snmp" },
    CommandSpec {
        key: DISK,
        cmd: r#"(lsblk --bytes --json --output FSTYPE,PATH,NAME,KNAME,MOUNTPOINT,FSSIZE,FSUSED,FSAVAIL,FSUSE%,UUID 2>/dev/null && echo "LSBLK_SUCCESS") || df -k"#,
    },
    CommandSpec { key: MEM, cmd: "cat /proc/meminfo | grep -E 'Mem|Swap'" },
    CommandSpec { key: TEMP_TYPE, cmd: "cat /sys/class/thermal/thermal_zone*/type" },
    CommandSpec { key: TEMP_VAL, cmd: "cat /sys/class/thermal/thermal_zone*/temp" },
    CommandSpec { key: HOST, cmd: "cat /etc/hostname" },
    CommandSpec { key: CPU_BRAND, cmd: r#"cat /proc/cpuinfo | grep "model name""# },
];

/// BSD/macOS(App `BSDStatusCmdType`)
pub const BSD: &[CommandSpec] = &[
    CommandSpec { key: TIME, cmd: "date +%s" },
    CommandSpec { key: NET, cmd: "netstat -ibn" },
    CommandSpec { key: SYS, cmd: "uname -or" },
    CommandSpec { key: CPU, cmd: r#"top -l 1 | grep "CPU usage""# },
    CommandSpec { key: UPTIME, cmd: "uptime" },
    CommandSpec { key: DISK, cmd: "df -k" },
    CommandSpec { key: MEM, cmd: "top -l 1 | grep PhysMem" },
    CommandSpec { key: HOST, cmd: "hostname" },
    CommandSpec { key: CPU_BRAND, cmd: "sysctl -n machdep.cpu.brand_string" },
];

/// Windows PowerShell(App `WindowsStatusCmdType`)
pub const WINDOWS: &[CommandSpec] = &[
    CommandSpec { key: TIME, cmd: "[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()" },
    CommandSpec {
        key: NET,
        cmd: r#"$s1 = @(Get-WmiObject Win32_PerfRawData_Tcpip_NetworkInterface | Select-Object Name, BytesReceivedPersec, BytesSentPersec, Timestamp_Sys100NS); Start-Sleep -Seconds 1; $s2 = @(Get-WmiObject Win32_PerfRawData_Tcpip_NetworkInterface | Select-Object Name, BytesReceivedPersec, BytesSentPersec, Timestamp_Sys100NS); @($s1, $s2) | ConvertTo-Json -Depth 5"#,
    },
    CommandSpec { key: SYS, cmd: "(Get-ComputerInfo).OsName" },
    CommandSpec {
        key: CPU,
        cmd: "Get-WmiObject -Class Win32_Processor | Select-Object Name, LoadPercentage, NumberOfCores, NumberOfLogicalProcessors | ConvertTo-Json",
    },
    CommandSpec {
        key: UPTIME,
        cmd: r#"$up = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime; if ($up.Days -gt 0) { "$($up.Days) days, $($up.Hours):$($up.Minutes.ToString('00'))" } else { "$($up.Hours):$($up.Minutes.ToString('00'))" }"#,
    },
    CommandSpec { key: CONN, cmd: "(netstat -an | findstr ESTABLISHED | Measure-Object -Line).Count" },
    CommandSpec {
        key: DISK,
        cmd: "Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, Size, FreeSpace, FileSystem | ConvertTo-Json",
    },
    CommandSpec {
        key: MEM,
        cmd: "Get-WmiObject -Class Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory | ConvertTo-Json",
    },
    CommandSpec {
        key: TEMP,
        cmd: r#"Get-CimInstance -ClassName MSAcpi_ThermalZoneTemperature -Namespace root/wmi -ErrorAction SilentlyContinue | Select-Object InstanceName, @{Name='Temperature';Expression={[math]::Round(($_.CurrentTemperature - 2732) / 10, 1)}} | ConvertTo-Json"#,
    },
    CommandSpec { key: HOST, cmd: r#"Write-Output $env:COMPUTERNAME"# },
    CommandSpec { key: CPU_BRAND, cmd: "(Get-WmiObject -Class Win32_Processor).Name" },
];

pub fn commands(system: crate::SystemType) -> &'static [CommandSpec] {
    match system {
        crate::SystemType::Linux => LINUX,
        crate::SystemType::Bsd => BSD,
        crate::SystemType::Windows => WINDOWS,
    }
}
