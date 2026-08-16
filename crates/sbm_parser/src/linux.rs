//! Linux parsing (Dart reference: cpu.dart / memory.dart / disk.dart / net_speed.dart / temp.dart)

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
        match (parse(1), parse(2), parse(3), parse(4), parse(5), parse(6), parse(7)) {
            (Ok(user), Ok(sys), Ok(nice), Ok(idle), Ok(iowait), Ok(irq), Ok(softirq)) => {
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

/// Disk output (Dart `Disk.parse`): prefer lsblk JSON (tagged `LSBLK_SUCCESS`),
/// fall back to the df table
pub fn parse_disk(raw: &str) -> Vec<Disk> {
    let raw = raw.trim();
    if raw.is_empty() {
        return Vec::new();
    }
    if raw.starts_with('{') {
        let json_part = match raw.find("\nLSBLK_SUCCESS") {
            Some(end) => &raw[..end],
            None => raw,
        };
        if let Ok(json) = serde_json::from_str::<serde_json::Value>(json_part) {
            let disks = parse_lsblk(&json);
            if !disks.is_empty() {
                return disks;
            }
        }
    }
    if raw.contains("Filesystem") && raw.contains("Mounted on") {
        return parse_df(raw);
    }
    Vec::new()
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
        let has_own_fs = fstype.is_some_and(|fs| disk_should_calc(fs, mount));

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

    if fstype.is_some_and(|fs| disk_should_calc(fs, mount)) || !children.is_empty() {
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
    if !disk_should_calc(fstype.unwrap_or(""), mount) {
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

/// df table fallback (Dart `_parseWithOldMethod`), in KiB.
/// Handles wrapped lines caused by overlong filesystem names (a single-field line
/// is buffered onto the next), filtered by [`disk_should_calc`].
/// On top of the Dart semantics (df -k plain numbers), also accepts df -h K/M/G/T suffixes
fn parse_df(raw: &str) -> Vec<Disk> {
    let mut disks = Vec::new();
    let mut lines = raw.trim().split('\n');
    lines.next(); // header
    let mut path_cache = String::new();

    for line in lines {
        if line.is_empty() {
            continue;
        }
        let mut fields: Vec<&str> = line.split_whitespace().collect();
        if fields.len() == 1 {
            path_cache = fields[0].to_string();
            continue;
        }
        if !path_cache.is_empty() && !fields.is_empty() {
            fields[0] = &path_cache;
        }
        let parsed = (|| -> Option<Disk> {
            let fs = fields.first()?.to_string();
            // Mount point is the LAST column: Linux df has 6 columns, macOS
            // df -k has 9 (iused/ifree/%iused between Capacity and Mounted on)
            let mount = (fields.len() >= 6).then(|| fields.last())??.to_string();
            if !disk_should_calc(&fs, &mount) {
                return None;
            }
            Some(Disk {
                used_percent: fields.get(4)?.trim_end_matches('%').parse().ok()?,
                used: df_size_kib(fields.get(2)?)?,
                size: df_size_kib(fields.get(1)?)?,
                avail: df_size_kib(fields.get(3)?)?,
                path: fs,
                mount,
                ..Disk::default()
            })
        })();
        path_cache.clear();
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

/// df size column → KiB: plain numbers are KiB (df -k), K/M/G/T suffixes converted base-1024 (df -h)
fn df_size_kib(s: &str) -> Option<u64> {
    if let Ok(v) = s.parse::<u64>() {
        return Some(v);
    }
    let (num, unit) = s.split_at(s.len().checked_sub(1)?);
    let multiplier: f64 = match unit {
        "K" | "k" => 1.0,
        "M" | "m" => 1024.0,
        "G" | "g" => 1024.0 * 1024.0,
        "T" | "t" => 1024.0 * 1024.0 * 1024.0,
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
pub fn parse_temps(types_raw: &str, values_raw: &str, divisor: f64) -> Temperatures {
    let mut temps = Temperatures::default();
    let types: Vec<&str> = types_raw.split('\n').collect();
    let values: Vec<&str> = values_raw.split('\n').collect();
    for (t, v) in types.iter().zip(values.iter()) {
        if t.is_empty() || v.is_empty() {
            continue;
        }
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
        .filter(|lines| lines.len() >= 3)
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

/// model name lines of /proc/cpuinfo (Dart `CpuBrand.parse`): model → occurrence
/// count, keeping first-seen order
pub fn parse_cpu_brand(raw: &str) -> Vec<(String, u32)> {
    let mut brands: Vec<(String, u32)> = Vec::new();
    for line in raw.lines() {
        if !line.contains("model name") {
            continue;
        }
        let model = line.split(':').next_back().unwrap_or("").trim().to_string();
        match brands.iter_mut().find(|(name, _)| *name == model) {
            Some((_, count)) => *count += 1,
            None => brands.push((model, 1)),
        }
    }
    brands
}
