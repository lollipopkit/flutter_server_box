//! Linux parsing (Dart reference: cpu.dart / memory.dart / disk.dart / net_speed.dart / temp.dart)

use std::collections::HashSet;

use crate::types::*;

/// cpu lines of /proc/stat (Dart `SingleCpuCore.parse`):
/// first line must be `cpu`/`cpuN`, stop at the first non-cpu line; skip lines with fewer than 8 fields
pub fn parse_cpu(raw: &str) -> Vec<CpuCore> {
    let mut cores = Vec::new();
    for line in raw.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let fields: Vec<&str> = line.split_whitespace().collect();
        let id = fields[0];
        if !id.starts_with("cpu") || !id[3..].chars().all(|c| c.is_ascii_digit()) {
            break;
        }
        if fields.len() < 8 {
            continue;
        }
        let parse = |i: usize| fields[i].parse::<u64>();
        // /proc/stat's column order is `user nice system idle iowait irq
        // softirq` — nice comes second. Reading field 2 as `sys` put nice time
        // under the `sys` label in the UI (near zero on most machines) and left
        // real system time displayed nowhere. `total()` sums every field, so
        // nothing that aggregates could notice.
        match (parse(1), parse(2), parse(3), parse(4), parse(5), parse(6), parse(7)) {
            (Ok(user), Ok(nice), Ok(sys), Ok(idle), Ok(iowait), Ok(irq), Ok(softirq)) => {
                cores.push(CpuCore {
                    id: id.to_string(),
                    user,
                    sys,
                    nice,
                    idle,
                    iowait,
                    irq,
                    softirq,
                });
            }
            _ => continue, // matches Dart: skip malformed lines
        }
    }
    cores
}

/// /proc/meminfo (Dart `Memory.parse`), in KiB
pub fn parse_mem(raw: &str) -> Option<Memory> {
    let get = |key: &str| meminfo_value(raw, key);
    let total = get("MemTotal:")?;
    Some(Memory {
        total,
        free: get("MemFree:").unwrap_or(0),
        avail: get("MemAvailable:").unwrap_or(0),
    })
}

/// Swap lines of /proc/meminfo (Dart `Swap.parse`), in KiB
pub fn parse_swap(raw: &str) -> Option<Swap> {
    Some(Swap {
        total: meminfo_value(raw, "SwapTotal:")?,
        free: meminfo_value(raw, "SwapFree:").unwrap_or(0),
        cached: meminfo_value(raw, "SwapCached:").unwrap_or(0),
    })
}

fn meminfo_value(raw: &str, key: &str) -> Option<u64> {
    raw.lines().find_map(|line| {
        let mut fields = line.split_whitespace();
        (fields.next() == Some(key)).then(|| fields.next()?.parse().ok())?
    })
}

/// What [commands::DISK] prints between its `lsblk` and its `df`.
pub const DISK_DF_MARKER: &str = "__SBM_DF__";

/// The `lsblk` arguments [commands::DISK] runs with, for a caller that runs it
/// without a shell (the monitor agent's sampler).
pub const LSBLK_ARGS: [&str; 4] = [
    "--bytes",
    "--json",
    "--output",
    "FSTYPE,PATH,NAME,KNAME,MOUNTPOINT,FSSIZE,FSUSED,FSAVAIL,FSUSE%,UUID,TYPE,MODEL,SIZE,TRAN",
];

/// Disk output: `lsblk` JSON, then [DISK_DF_MARKER], then the `df` table —
/// each source sees what the other cannot (see [merge_disks]). Either half may
/// be missing: `lsblk` is not on busybox, and the monitor agent's sampler
/// reads `df` alone. The older output, one or the other, is read as before.
pub fn parse_disk(raw: &str) -> Vec<Disk> {
    if let Some((_, df)) = raw.split_once(DISK_DF_MARKER) {
        let lsblk = lsblk_json(raw).map(|json| parse_lsblk(&json)).unwrap_or_default();
        return merge_disks(lsblk, parse_df(df));
    }
    let raw = raw.trim();
    if raw.is_empty() {
        return Vec::new();
    }
    if let Some(json) = lsblk_json(raw) {
        let disks = parse_lsblk(&json);
        if !disks.is_empty() {
            return disks;
        }
    }
    parse_df(raw)
}

/// The `lsblk` JSON of [`parse_disk`]'s input, in either of its shapes.
fn lsblk_json(raw: &str) -> Option<serde_json::Value> {
    let lsblk = match raw.split_once(DISK_DF_MARKER) {
        Some((lsblk, _)) => lsblk.trim(),
        None => {
            let raw = raw.trim();
            raw.find("\nLSBLK_SUCCESS").map_or(raw, |end| &raw[..end])
        }
    };
    if !lsblk.starts_with('{') {
        return None;
    }
    serde_json::from_str(lsblk).ok()
}

/// Every block device in [`parse_disk`]'s input, as `lsblk` nests them —
/// those nothing is mounted from and those with no filesystem included (#1829).
///
/// Loop and RAM devices are left out: a snap or an image file each make a
/// loop device, and a host has dozens of them that are not disks.
///
/// A device built on several others (an LVM thin pool on its `_tmeta` and
/// `_tdata`, an md array on each member) is listed by `lsblk` under each of
/// them; here only under the first, so every device appears once.
pub fn parse_block_devices(raw: &str) -> Vec<BlockDevice> {
    fn device(d: &serde_json::Value, top: bool, seen: &mut HashSet<String>) -> Option<BlockDevice> {
        let text = |key: &str| {
            d[key]
                .as_str()
                .map(str::trim)
                .filter(|s| !s.is_empty())
                .map(str::to_string)
        };
        let kind = text("type")?;
        if matches!(kind.as_str(), "loop" | "ram") {
            return None;
        }
        let name = text("name")?;
        let path = text("path").unwrap_or_default();
        if !seen.insert(if path.is_empty() { name.clone() } else { path.clone() }) {
            return None;
        }
        let size = &d["size"];
        Some(BlockDevice {
            name,
            path,
            kind,
            model: text("model"),
            size: size
                .as_u64()
                .or_else(|| size.as_str().and_then(|s| s.parse().ok()))
                .unwrap_or(0),
            // Newer `lsblk` repeats the disk's on each partition.
            tran: text("tran").filter(|_| top),
            fs_type: text("fstype"),
            mount: text("mountpoint"),
            children: list(&d["children"], false, seen),
        })
    }
    fn list(devices: &serde_json::Value, top: bool, seen: &mut HashSet<String>) -> Vec<BlockDevice> {
        devices
            .as_array()
            .map(|a| a.iter().filter_map(|d| device(d, top, seen)).collect())
            .unwrap_or_default()
    }
    lsblk_json(raw).map_or_else(Vec::new, |json| {
        list(&json["blockdevices"], true, &mut HashSet::new())
    })
}

/// One list of `lsblk`'s devices and `df`'s mounted filesystems.
///
/// `lsblk` is the tree: devices, how they nest (a disk, its partitions, the
/// LVM volumes on one), filesystem types and UUIDs, and devices nothing is
/// mounted from. `df` is what is mounted and how full it is — including what
/// `lsblk` cannot see (NFS and SMB, every ZFS dataset) and, in a container,
/// numbers `lsblk` leaves empty. A `df` row lands on the device it names, by
/// path or by mount point, and its numbers win: they are always current,
/// where the monitor agent's `lsblk` is refreshed less often. Whatever `df`
/// has that no device matches is added after the tree.
pub fn merge_disks(mut lsblk: Vec<Disk>, df: Vec<Disk>) -> Vec<Disk> {
    fn find<'a>(disks: &'a mut [Disk], row: &Disk) -> Option<&'a mut Disk> {
        for disk in disks {
            if disk.path == row.path || (!row.mount.is_empty() && disk.mount == row.mount) {
                return Some(disk);
            }
            if let Some(found) = find(&mut disk.children, row) {
                return Some(found);
            }
        }
        None
    }
    let mut extra = Vec::new();
    for row in df {
        match find(&mut lsblk, &row) {
            Some(disk) => {
                disk.size = row.size;
                disk.used = row.used;
                disk.avail = row.avail;
                disk.used_percent = row.used_percent;
                if disk.mount.is_empty() {
                    disk.mount = row.mount;
                }
                if disk.fs_type.is_none() {
                    disk.fs_type = row.fs_type;
                }
            }
            None => extra.push(row),
        }
    }
    lsblk.extend(extra);
    lsblk
}

/// lsblk --bytes --json(Dart `_processTopLevelDevice`)
fn parse_lsblk(json: &serde_json::Value) -> Vec<Disk> {
    let mut list = Vec::new();
    let Some(devices) = json["blockdevices"].as_array() else {
        return list;
    };
    for device in devices {
        let fstype = device["fstype"].as_str();
        let mount = device["mountpoint"].as_str().unwrap_or("");
        let children = device["children"].as_array().map(Vec::as_slice).unwrap_or(&[]);
        let (size, used, avail, _) = lsblk_fs_fields(device);
        let has_stats = size != 0 || used != 0 || avail != 0;
        let has_own_fs = fstype.is_some_and(|fs| disk_type_should_calc(fs, mount));

        // Container devices without their own filesystem: only expand children
        if !has_stats && !has_own_fs && !children.is_empty() {
            for child in children {
                if let Some(disk) = lsblk_device(child) {
                    list.push(disk);
                }
            }
            continue;
        }

        if let Some(disk) = lsblk_device(device) {
            list.push(disk);
        }
        // btrfs RAID partitions appended directly (same as Dart)
        for child in children {
            if child["fstype"].as_str() == Some("btrfs")
                && child["path"].as_str().is_some_and(|p| !p.is_empty())
                && let Some(disk) = lsblk_single_device(child)
            {
                list.push(disk);
            }
        }
    }
    list
}

/// Recursively process a device and its children (Dart `_processDiskDevice`)
fn lsblk_device(device: &serde_json::Value) -> Option<Disk> {
    let fstype = device["fstype"].as_str();
    let mount = device["mountpoint"].as_str().unwrap_or("");
    let children: Vec<Disk> = device["children"]
        .as_array()
        .map(Vec::as_slice)
        .unwrap_or(&[])
        .iter()
        .filter_map(lsblk_device)
        .collect();

    if fstype.is_some_and(|fs| disk_type_should_calc(fs, mount)) || !children.is_empty() {
        Some(lsblk_build(device, children))
    } else {
        None
    }
}

/// Single device, no recursion (Dart `_processSingleDevice`)
fn lsblk_single_device(device: &serde_json::Value) -> Option<Disk> {
    let fstype = device["fstype"].as_str();
    let mount = device["mountpoint"].as_str().unwrap_or("");
    let path = device["path"].as_str().unwrap_or("");
    if path.is_empty() || (fstype.is_none() && mount.is_empty()) {
        return None;
    }
    if !disk_type_should_calc(fstype.unwrap_or(""), mount) {
        return None;
    }
    Some(lsblk_build(device, Vec::new()))
}

fn lsblk_build(device: &serde_json::Value, children: Vec<Disk>) -> Disk {
    let (size, used, avail, used_percent) = lsblk_fs_fields(device);
    let str_field = |key: &str| device[key].as_str().map(str::to_string);
    Disk {
        path: device["path"].as_str().unwrap_or("").to_string(),
        fs_type: str_field("fstype"),
        mount: device["mountpoint"].as_str().unwrap_or("").to_string(),
        used_percent,
        used,
        size,
        avail,
        name: str_field("name"),
        kname: str_field("kname"),
        uuid: str_field("uuid"),
        children,
    }
}

/// lsblk filesystem fields: --bytes output is bytes → KiB (Dart `_parseFilesystemFields`)
fn lsblk_fs_fields(device: &serde_json::Value) -> (u64, u64, u64, u32) {
    let size = |key: &str| -> u64 {
        let v = &device[key];
        v.as_u64()
            .or_else(|| v.as_str().and_then(|s| s.parse().ok()))
            .unwrap_or(0)
            / 1024
    };
    let percent = device["fsuse%"]
        .as_str()
        .and_then(|s| s.trim_end_matches('%').parse().ok())
        .unwrap_or(0);
    (size("fssize"), size("fsused"), size("fsavail"), percent)
}

/// df table, in KiB: `df -k`, or `df -kT` with its type column.
/// Handles wrapped lines caused by overlong filesystem names (a single-field line
/// is buffered onto the next), filtered by [`disk_should_calc`] and, with a
/// type, by what [`Disk::is_storage`] asks of one.
/// Also accepts df -h K/M/G/T suffixes
///
/// Whether there is a type column is read from an English header. `df`
/// translates it (`文件系统 类型 … 挂载点`), and under such a header each row
/// answers for itself: see [`df_row_typed`].
fn parse_df(raw: &str) -> Vec<Disk> {
    let mut disks = Vec::new();
    let mut rows: Vec<Vec<&str>> = Vec::new();
    let mut path_cache: Option<&str> = None;

    let mut lines = raw.trim().split('\n');
    let header: Vec<&str> = lines.next().unwrap_or_default().split_whitespace().collect();
    let header_typed = (header.first() == Some(&"Filesystem")).then(|| header.get(1) == Some(&"Type"));

    for line in lines {
        let mut fields: Vec<&str> = line.split_whitespace().collect();
        if fields.is_empty() {
            continue;
        }
        if fields.len() == 1 {
            path_cache = Some(fields[0]);
            continue;
        }
        // The buffered name belongs *in front of* this line's columns, which
        // start at the size. Overwriting field 0 destroyed the size column and
        // left five fields, which the `>= 6` check below then dropped — so a
        // stock Ubuntu LVM install ("/dev/mapper/ubuntu--vg-ubuntu--lv", long
        // enough that df wraps it) reported no root filesystem at all.
        if let Some(path) = path_cache.take() {
            fields.insert(0, path);
        }
        rows.push(fields);
    }

    for mut fields in rows {
        let typed = header_typed.unwrap_or_else(|| df_row_typed(&fields));
        let fs_type = typed.then(|| fields.get(1).map(|t| t.to_string())).flatten();
        if typed && fields.len() > 1 {
            fields.remove(1);
        }
        let parsed = (|| -> Option<Disk> {
            let fs = fields.first()?.to_string();
            // Mount point is the LAST column: Linux df has 6 columns, macOS
            // df -k has 9 (iused/ifree/%iused between Capacity and Mounted on)
            let mount = (fields.len() >= 6).then(|| fields.last())??.to_string();
            let disk = Disk {
                used_percent: fields.get(4)?.trim_end_matches('%').parse().ok()?,
                used: df_size_kib(fields.get(2)?)?,
                size: df_size_kib(fields.get(1)?)?,
                avail: df_size_kib(fields.get(3)?)?,
                path: fs,
                mount,
                fs_type,
                ..Disk::default()
            };
            disk.is_storage().then_some(disk)
        })();
        if let Some(disk) = parsed {
            disks.push(disk);
        }
    }

    // Bind mounts and container volumes republish one filesystem under many
    // paths: a host running containers reports the same device a dozen times,
    // every row carrying identical numbers. Same source and same numbers is
    // the same filesystem, and the first mount `df` lists — `/` before the
    // volumes under it — is the one worth naming.
    let mut seen = std::collections::HashSet::new();
    disks.retain(|d| seen.insert((d.path.clone(), d.size, d.used)));
    disks
}

/// Whether a row under a translated header has a type column: a word where the
/// size would be, followed by the size.
///
/// Only asked where the header cannot answer, which is Linux under a
/// non-English locale: its `df` escapes a space in a source as `\040`. macOS
/// names some filesystems with one (`map auto_home`), which would read as a
/// type here — under its English header it is never asked.
fn df_row_typed(fields: &[&str]) -> bool {
    fields.get(1).is_some_and(|f| df_size_kib(f).is_none())
        && fields.get(2).is_some_and(|f| df_size_kib(f).is_some())
}

/// df size column → KiB: plain numbers are KiB (df -k), K/M/G/T suffixes converted base-1024 (df -h)
fn df_size_kib(s: &str) -> Option<u64> {
    if let Ok(v) = s.parse::<u64>() {
        return Some(v);
    }
    // By character, not by byte: `s` is whatever the remote host's `df` wrote,
    // and splitting one byte from the end lands inside a multi-byte character
    // and panics — which, over FFI, takes the app's process with it.
    let mut chars = s.chars();
    let unit = chars.next_back()?;
    let num = chars.as_str();
    let multiplier: f64 = match unit {
        'K' | 'k' => 1.0,
        'M' | 'm' => 1024.0,
        'G' | 'g' => 1024.0 * 1024.0,
        'T' | 't' => 1024.0 * 1024.0 * 1024.0,
        _ => return None,
    };
    Some((num.parse::<f64>().ok()? * multiplier) as u64)
}

/// /proc/net/dev (Dart `NetSpeed.parse`): skip two header lines, `iface: rx ... tx ...`
pub fn parse_net(raw: &str) -> Vec<NetIface> {
    let lines: Vec<&str> = raw.split('\n').collect();
    if lines.len() < 4 {
        return Vec::new();
    }
    let mut result = Vec::new();
    for line in &lines[2..] {
        let Some((device, rest)) = line.trim().split_once(':') else {
            continue;
        };
        let fields: Vec<&str> = rest.split_whitespace().collect();
        let (Some(Ok(rx)), Some(Ok(tx))) = (
            fields.first().map(|s| s.parse::<u64>()),
            fields.get(8).map(|s| s.parse::<u64>()),
        ) else {
            continue;
        };
        result.push(NetIface {
            device: device.to_string(),
            rx_bytes: rx,
            tx_bytes: tx,
        });
    }
    result
}

/// thermal_zone type/temp segments (Dart `Temperatures.parse`):
/// paired line by line, name is the last path segment, value divided by divisor
/// (Linux reports millidegree Celsius → 1000)
///
/// The two sides come from two independent `cat` globs, so the pairing is
/// positional and only sound while both listed the same zones. A zone whose
/// `temp` cannot be read contributes a line to one side and not the other,
/// which shifts every later reading onto the preceding zone's name — a
/// plausible-looking wrong answer. Counts that disagree are therefore reported
/// as no temperatures at all. Pairing them at the source (one line per zone)
/// is a change to the command manifest, which every installed status script
/// would have to be reissued for.
pub fn parse_temps(types_raw: &str, values_raw: &str, divisor: f64) -> Temperatures {
    let mut temps = Temperatures::default();
    let types: Vec<&str> = types_raw.lines().filter(|l| !l.trim().is_empty()).collect();
    let values: Vec<&str> = values_raw.lines().filter(|l| !l.trim().is_empty()).collect();
    if types.len() != values.len() {
        return temps;
    }
    for (t, v) in types.iter().zip(values.iter()) {
        let name = t.rsplit('/').next().unwrap_or(t);
        if let Ok(temp) = v.trim().parse::<f64>() {
            temps.0.insert(name.to_string(), temp / divisor);
        }
    }
    temps
}

/// Tcp lines of /proc/net/snmp (Dart `Conn.parse`):
/// take the last `Tcp:` line; MaxConn is column 4, AttemptFails column 7
pub fn parse_conn(raw: &str) -> Option<Conn> {
    let line = raw.split('\n').rfind(|l| l.starts_with("Tcp:"))?;
    let fields: Vec<&str> = line.split_whitespace().collect();
    if fields.len() <= 7 {
        return None;
    }
    Some(Conn {
        max_conn: fields[4].parse().ok()?,
        fail: fields[7].parse().ok()?,
    })
}

/// /proc/diskstats (Dart `DiskIO.parse`): dev at column 3, read/write sectors at
/// columns 6/10; skip loop devices and malformed lines
pub fn parse_diskio(raw: &str) -> Vec<DiskIoPiece> {
    raw.split('\n')
        .filter_map(|line| {
            let fields: Vec<&str> = line.split_whitespace().collect();
            if fields.len() < 10 {
                return None;
            }
            let dev = fields[2];
            if dev.starts_with("loop") {
                return None;
            }
            Some(DiskIoPiece {
                dev: dev.to_string(),
                sectors_read: fields[5].parse().ok()?,
                sectors_write: fields[9].parse().ok()?,
            })
        })
        .collect()
}

/// Multi-block power_supply uevent output (Dart `Batteries.parse`): blocks separated
/// by blank lines, each block a KEY=VALUE list
pub fn parse_batteries(raw: &str, only_li_poly: bool) -> Vec<Battery> {
    let mut batteries = Vec::new();
    let mut block: Vec<&str> = Vec::new();
    for line in raw.lines() {
        if !line.is_empty() {
            block.push(line);
            continue;
        }
        if let Some(battery) = parse_battery_block(&block)
            && (!only_li_poly || battery.is_li_poly())
        {
            batteries.push(battery);
        }
        block.clear();
    }
    if let Some(battery) = parse_battery_block(&block)
        && (!only_li_poly || battery.is_li_poly())
    {
        batteries.push(battery);
    }
    batteries
}

fn parse_battery_block(lines: &[&str]) -> Option<Battery> {
    if lines.is_empty() {
        return None;
    }
    let mut map = std::collections::HashMap::new();
    for line in lines {
        let parts: Vec<&str> = line.split('=').collect();
        if parts.len() == 2 {
            map.insert(parts[0], parts[1]);
        }
    }
    Some(Battery {
        percent: map.get("POWER_SUPPLY_CAPACITY").and_then(|v| v.parse().ok()),
        status: BatteryStatus::parse(map.get("POWER_SUPPLY_STATUS").copied()),
        name: map
            .get("POWER_SUPPLY_MODEL_NAME")
            .or_else(|| map.get("POWER_SUPPLY_NAME"))
            .map(|s| s.to_string()),
        cycle: map.get("POWER_SUPPLY_CYCLE_COUNT").and_then(|v| v.parse().ok()),
        tech: map.get("POWER_SUPPLY_TECHNOLOGY").map(|s| s.to_string()),
    })
}

/// `sensors` output (Dart `SensorItem.parse`): blocks separated by blank lines,
/// each block at least 3 lines [device, adapter, detail...]
pub fn parse_sensors(raw: &str) -> Vec<SensorItem> {
    let mut groups: Vec<Vec<&str>> = vec![Vec::new()];
    for line in raw.lines() {
        if line.is_empty() {
            groups.push(Vec::new());
        } else {
            groups.last_mut().unwrap().push(line);
        }
    }

    groups
        .into_iter()
        // A chip is its name, then `Adapter: …`, then its readings. The
        // script carries `sensors`' stderr too, and a host without chips
        // prints three lines there ("No sensors found!" and two hints):
        // not a device.
        .filter(|lines| lines.len() >= 3 && lines[1].trim_start().starts_with("Adapter:"))
        .map(|lines| {
            let adapter = lines[1].split(':').next_back().unwrap_or("").trim().to_string();
            let details = lines[2..]
                .iter()
                .filter_map(|line| {
                    let parts: Vec<&str> = line.split(':').collect();
                    if parts.len() < 2 {
                        return None;
                    }
                    Some((parts[0].trim().to_string(), parts[1].trim().to_string()))
                })
                .collect();
            SensorItem {
                device: lines[0].to_string(),
                adapter,
                details,
            }
        })
        .collect()
}

/// /proc/cpuinfo, whole or the lines [commands::CPU_BRAND] keeps: core name →
/// how many cores have it, in first-seen order.
///
/// A core is named by its `model name` when that names it, by its `CPU
/// implementer` and `CPU part` otherwise (see [crate::arm]): arm64 prints no
/// `model name`, and ARM's own is the same `ARMv8 Processor rev N` for every
/// kind of core in a big.LITTLE CPU.
pub fn parse_cpu_brand(raw: &str) -> Vec<(String, u32)> {
    #[derive(Default)]
    struct Core {
        model: Option<String>,
        implementer: Option<u32>,
        part: Option<u32>,
    }
    impl Core {
        fn is_empty(&self) -> bool {
            self.model.is_none() && self.implementer.is_none() && self.part.is_none()
        }
        fn name(self) -> Option<String> {
            let decoded = match (self.implementer, self.part) {
                (Some(i), Some(p)) => Some(crate::arm::core_name(i, p)),
                _ => None,
            };
            match self.model {
                Some(model) if !is_generic_arm_model(&model) => Some(model),
                model => decoded.or(model),
            }
        }
    }
    fn hex(value: &str) -> Option<u32> {
        u32::from_str_radix(value.strip_prefix("0x")?, 16).ok()
    }

    let mut cores: Vec<Core> = Vec::new();
    let mut core = Core::default();
    for line in raw.lines() {
        let Some((key, value)) = line.split_once(':') else {
            continue;
        };
        let value = value.trim();
        // A field seen twice is the next core's: the lines of the command's
        // older form are `model name` alone, one per core.
        match key.trim() {
            "processor" => {
                if !core.is_empty() {
                    cores.push(std::mem::take(&mut core));
                }
            }
            "model name" => {
                if core.model.is_some() {
                    cores.push(std::mem::take(&mut core));
                }
                core.model = Some(value.to_string()).filter(|v| !v.is_empty());
            }
            "CPU implementer" => {
                if core.implementer.is_some() {
                    cores.push(std::mem::take(&mut core));
                }
                core.implementer = hex(value);
            }
            "CPU part" => {
                if core.part.is_some() {
                    cores.push(std::mem::take(&mut core));
                }
                core.part = hex(value);
            }
            _ => {}
        }
    }
    if !core.is_empty() {
        cores.push(core);
    }

    let mut brands: Vec<(String, u32)> = Vec::new();
    for name in cores.into_iter().filter_map(Core::name) {
        match brands.iter_mut().find(|(n, _)| *n == name) {
            Some((_, count)) => *count += 1,
            None => brands.push((name, 1)),
        }
    }
    brands
}

/// The `model name` an ARM kernel makes up when it has none to give:
/// `ARMv7 Processor rev 4 (v7l)`, `AArch64 Processor rev 4 (aarch64)`.
fn is_generic_arm_model(model: &str) -> bool {
    let Some((arch, rest)) = model.split_once(' ') else {
        return false;
    };
    rest.starts_with("Processor")
        && (arch == "AArch64"
            || arch
                .strip_prefix("ARMv")
                .is_some_and(|v| v.starts_with(|c: char| c.is_ascii_digit())))
}
