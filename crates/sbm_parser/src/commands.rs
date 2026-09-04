//! Collection command manifest (single source of truth, see the shared-parser design)
//!
//! Commands, segment separator, and parsers evolve in lockstep. Both the app's
//! script generation and the monitor's local collection take commands from here.
//! Commands mirror flutter_server_box one by one
//! `lib/data/model/app/scripts/cmd_types.dart`。
//! Commands listed in [`EXTENDED`] are kept out of the fast status function
//! and emitted by the extended one instead; see that constant.

/// Output segment separator; scripts print `SrvBoxSep.<key>` before each segment
pub const SEPARATOR: &str = "SrvBoxSep";

// Command keys (matching the app's `ShellCmdType` enum names)
/// System-sign echo segment (`__linux` / `__bsd` / `__windows`), used by the app
/// to detect the remote OS from script output
pub const ECHO: &str = "echo";
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
/// Windows single-segment temperature (InstanceName + Celsius JSON)
pub const TEMP: &str = "temp";
pub const DISKIO: &str = "diskio";
pub const BATTERY: &str = "battery";
pub const SENSORS: &str = "sensors";
pub const DISK_SMART: &str = "diskSmart";
pub const NVIDIA: &str = "nvidia";
pub const AMD: &str = "amd";
/// The machine's own interface addresses, so a server reached at a private
/// address can still say where it is — see `common::parse_ips`
pub const IP: &str = "ip";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CommandSpec {
    pub key: &'static str,
    pub cmd: &'static str,
}

/// Commands excluded from the fast status function (`SbStatus`), emitted by
/// the extended one (`SbStatusExt`) instead.
///
/// Two reasons, both of which rule out the app's few-second status poll:
/// - `smartctl` reads are free in themselves, but reaching the disk at all
///   spins up / wakes one that is in standby. Polling it every few seconds
///   means a disk with spin-down configured never stays spun down, and every
///   wake costs a `Start_Stop_Count` / `Load_Cycle_Count` tick.
/// - `amd-smi`/`rocm-smi` fork through several tools per invocation.
///
/// - `IP` answers a question whose answer changes when a machine moves or its
///   lease does. Asking every few seconds spends a process spawn on a value
///   that is the same as it was ten thousand samples ago.
///
/// Both callers refresh these on a slow cadence instead: the app on a timer
/// (minutes), the monitor on its extended cycle.
pub const EXTENDED: &[&str] = &[DISK_SMART, AMD, IP];

impl CommandSpec {
    /// Whether this command belongs to the extended function rather than the
    /// fast status one — see [`EXTENDED`]
    pub fn is_extended(&self) -> bool {
        EXTENDED.contains(&self.key)
    }
}

// NOTE: table order is script wire format — the generated status script emits
// segments in this exact order, and it must match the Dart enum declaration
// order (`StatusCmdType` etc.) for byte-identical script generation.

/// Linux(App `StatusCmdType`)
pub const LINUX: &[CommandSpec] = &[
    CommandSpec { key: ECHO, cmd: "echo __linux" },
    CommandSpec { key: TIME, cmd: "date +%s" },
    CommandSpec { key: NET, cmd: "cat /proc/net/dev" },
    CommandSpec {
        key: SYS,
        // Three keys, not one. `PRETTY_NAME` is prose written for a person and
        // is what the status page shows; `ID` is os-release's machine-readable
        // identifier and is what picks the distribution's mark, which used to
        // be guessed by looking for substrings in the prose. `ID_LIKE` names
        // the base a derivative nothing recognises is built on.
        //
        // Both files are read, in the order os-release specifies — a system
        // that has only `/usr/lib/os-release` is answered, and one where
        // `/etc/os-release` is the usual symlink to it just prints each key
        // twice, which the parser resolves by taking the first.
        //
        // The old `/etc/*-release` glob stays as the fallback for a remote
        // with no os-release at all (CentOS 6 and older, some appliances);
        // there it finds only a `PRETTY_NAME`, and the mark falls back to
        // matching the prose exactly as before.
        cmd: "cat /etc/os-release /usr/lib/os-release 2>/dev/null | grep -E '^(ID|ID_LIKE|PRETTY_NAME)=' || cat /etc/*-release 2>/dev/null | grep ^PRETTY_NAME",
    },
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
    CommandSpec { key: DISKIO, cmd: "cat /proc/diskstats" },
    CommandSpec {
        key: BATTERY,
        cmd: r#"for f in /sys/class/power_supply/*/uevent; do cat "$f"; echo; done"#,
    },
    CommandSpec {
        key: NVIDIA,
        // WSL exposes the Windows driver's nvidia-smi under /usr/lib/wsl/lib,
        // which is absent from non-interactive PATH — fall back explicitly
        cmd: "if command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi -q -x; elif [ -x /usr/lib/wsl/lib/nvidia-smi ]; then /usr/lib/wsl/lib/nvidia-smi -q -x; fi",
    },
    CommandSpec {
        key: AMD,
        cmd: "if command -v amd-smi >/dev/null 2>&1; then amd-smi list --json && amd-smi metric --json; elif command -v rocm-smi >/dev/null 2>&1; then rocm-smi --json || rocm-smi --showunique --showuse --showtemp --showfan --showclocks --showmemuse --showpower; elif command -v radeontop >/dev/null 2>&1; then timeout 2s radeontop -d - -l 1 | tail -n +2; else echo \"No AMD GPU monitoring tools found\"; fi",
    },
    CommandSpec { key: SENSORS, cmd: "sensors" },
    CommandSpec {
        key: DISK_SMART,
        // Most distros restrict raw ATA/NVMe ioctls to root, and this runs
        // as an unprivileged service user — check readability first (a
        // cheap stat, not a wasted smartctl invocation) and only add
        // `sudo -n` (non-interactive) when actually needed. This tries
        // passwordless elevation if the operator has configured a narrow
        // `NOPASSWD: /usr/sbin/smartctl` sudoers rule; otherwise it fails in
        // well under a second (no hang, no password prompt) and this
        // cycle's disk_smart is just empty, same as before this existed.
        // Deliberately not just `smartctl ... || sudo -n smartctl ...`:
        // smartctl often exits non-zero even on a *successful* read (e.g.
        // a benign warning), which would double-invoke and duplicate output.
        //
        // `TYPE == disk` drops loop/rom/lvm/raid devices, which have no SMART
        // data and would each still cost a process spawn (a snap-heavy Ubuntu
        // easily has 20+ loop devices); zram reports `disk` but is RAM.
        //
        // `-n standby` returns early (exit 2, no data) instead of waking a
        // disk that has spun down. Not a full guarantee: device type
        // autodetection can still spin one up, which `-d` would avoid but
        // only if the type were known per device.
        cmd: r#"for d in $(lsblk -dn -o KNAME,TYPE 2>/dev/null | awk '$2 == "disk" && $1 !~ /^zram/ { print $1 }'); do if [ -r "/dev/$d" ]; then smartctl -n standby -a -j "/dev/$d" 2>/dev/null; else sudo -n smartctl -n standby -a -j "/dev/$d" 2>/dev/null; fi; echo; done"#,
    },
    CommandSpec { key: CPU_BRAND, cmd: r#"cat /proc/cpuinfo | grep "model name""# },
    CommandSpec {
        key: IP,
        // Three commands because the first is not everywhere: `ip` is iproute2
        // and Linux-only, `ifconfig` is missing from minimal containers, and
        // `hostname -I` is a last resort that prints addresses and nothing
        // else. `||` rather than `;` so a box with all three runs one.
        //
        // `scope global` drops loopback and link-local at the source. The
        // parser does not rely on it — it discards anything not public — but
        // asking for less output is free.
        cmd: "ip -o addr show scope global 2>/dev/null || ifconfig 2>/dev/null || hostname -I 2>/dev/null",
    },
];

/// BSD/macOS(App `BSDStatusCmdType`)
pub const BSD: &[CommandSpec] = &[
    CommandSpec { key: ECHO, cmd: "echo __bsd" },
    CommandSpec { key: TIME, cmd: "date +%s" },
    CommandSpec { key: NET, cmd: "netstat -ibn" },
    CommandSpec { key: SYS, cmd: "uname -or" },
    // `-l` (single-shot sample count) is macOS-only; FreeBSD's top has no
    // such flag and instead needs `-b -d 1 -P` for a one-shot per-core batch
    // read. One SystemType::Bsd manifest entry must work on either real OS,
    // so branch at runtime on `uname`. macOS still gets only an aggregate
    // reading (no per-core breakdown without extra tooling), with the real
    // logical core count appended via `sysctl -n hw.ncpu` so the aggregate is
    // replicated across that many pseudo-cores (see bsd::parse_cpu); FreeBSD
    // gets genuine per-core lines from `top -P`.
    CommandSpec {
        key: CPU,
        cmd: r#"if [ "$(uname)" = "Darwin" ]; then top -l 1 | grep "CPU usage"; sysctl -n hw.ncpu; else top -b -d 1 -P | grep "^CPU"; fi"#,
    },
    CommandSpec { key: UPTIME, cmd: "uptime" },
    CommandSpec { key: DISK, cmd: "df -k" },
    // Darwin: vm_stat supplies page-level data so "used" can exclude
    // cache/inactive (top's PhysMem "used" counts cached files); parser
    // tolerates its absence. FreeBSD has neither `top -l` nor vm_stat, so
    // without the branch its memory section came back empty.
    CommandSpec {
        key: MEM,
        cmd: r#"if [ "$(uname)" = "Darwin" ]; then top -l 1 | grep PhysMem; vm_stat; else top -b -d 1 | grep "^Mem:"; fi"#,
    },
    CommandSpec { key: HOST, cmd: "hostname" },
    CommandSpec {
        key: DISK_SMART,
        // `diskutil list` labels each device's role; only "internal,
        // physical"/"external, physical" are real hardware — APFS
        // synthesized containers and mounted disk images (both very common:
        // every APFS volume group has one) are not, and querying smartctl
        // against them is both pointless (no real SMART data) and wasted
        // work every extended cycle. `smartctl -a /dev/diskN` needs no sudo
        // on macOS (unlike Linux), confirmed against real hardware.
        // `-n standby` keeps a spun-down disk (external HDDs, FreeBSD ATA)
        // from being woken by the read; accepted and ignored for NVMe.
        cmd: r#"for d in $(diskutil list 2>/dev/null | awk '/\(internal, physical\)|\(external, physical\)/{print $1}'); do smartctl -n standby -a -j "$d" 2>/dev/null; echo; done"#,
    },
    // Real logical core count appended (see the CPU command's comment) so
    // parse_cpu_brand can report it alongside the single global brand string
    // sysctl returns (BSD has no per-model breakdown the way Linux's
    // per-logical-CPU /proc/cpuinfo does)
    CommandSpec {
        key: CPU_BRAND,
        cmd: "sysctl -n machdep.cpu.brand_string; sysctl -n hw.ncpu",
    },
    // No `ip` here: iproute2 is Linux-only, and `ifconfig` is the one command
    // both Darwin and FreeBSD have. Its output carries netmasks and MAC
    // addresses too, which the parser is written to discard.
    CommandSpec { key: IP, cmd: "ifconfig 2>/dev/null" },
];

/// Windows PowerShell(App `WindowsStatusCmdType`)
pub const WINDOWS: &[CommandSpec] = &[
    CommandSpec { key: ECHO, cmd: "echo __windows" },
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
    CommandSpec {
        key: DISKIO,
        cmd: r#"$s1 = @(Get-WmiObject Win32_PerfRawData_PerfDisk_PhysicalDisk | Select-Object Name, DiskReadBytesPersec, DiskWriteBytesPersec, Timestamp_Sys100NS); Start-Sleep -Seconds 1; $s2 = @(Get-WmiObject Win32_PerfRawData_PerfDisk_PhysicalDisk | Select-Object Name, DiskReadBytesPersec, DiskWriteBytesPersec, Timestamp_Sys100NS); @($s1, $s2) | ConvertTo-Json -Depth 5"#,
    },
    CommandSpec {
        key: BATTERY,
        cmd: "Get-WmiObject -Class Win32_Battery | Select-Object EstimatedChargeRemaining, BatteryStatus | ConvertTo-Json",
    },
    CommandSpec {
        key: NVIDIA,
        cmd: r#"if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) { nvidia-smi -q -x } else { echo "NVIDIA driver not found" }"#,
    },
    CommandSpec {
        key: AMD,
        cmd: r#"if (Get-Command amd-smi -ErrorAction SilentlyContinue) { amd-smi list --json } else { echo "AMD driver not found" }"#,
    },
    CommandSpec {
        key: SENSORS,
        cmd: "Get-CimInstance -ClassName Win32_TemperatureProbe -ErrorAction SilentlyContinue | Select-Object Name, CurrentReading | ConvertTo-Json",
    },
    CommandSpec {
        key: DISK_SMART,
        cmd: "Get-PhysicalDisk | Get-StorageReliabilityCounter | Select-Object DeviceId, Temperature, TemperatureMax, Wear, PowerOnHours | ConvertTo-Json",
    },
    CommandSpec { key: CPU_BRAND, cmd: "(Get-WmiObject -Class Win32_Processor).Name" },
    // `-ExpandProperty`, so what comes back is one address per line rather
    // than a table the parser would have to un-format.
    CommandSpec {
        key: IP,
        cmd: "Get-NetIPAddress | Select-Object -ExpandProperty IPAddress",
    },
];

pub fn commands(system: crate::SystemType) -> &'static [CommandSpec] {
    match system {
        crate::SystemType::Linux => LINUX,
        crate::SystemType::Bsd => BSD,
        crate::SystemType::Windows => WINDOWS,
    }
}
