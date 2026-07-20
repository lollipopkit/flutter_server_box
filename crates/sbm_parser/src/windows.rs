//! Windows PowerShell JSON parsing (Dart reference: windows_parser.dart +
//! WMI delta helpers from server_status_update_req.dart)

use crate::types::*;
use serde_json::Value;

fn as_list(v: Value) -> Vec<Value> {
    match v {
        Value::Array(list) => list,
        other => vec![other],
    }
}

fn decode(raw: &str) -> Option<Value> {
    if raw.is_empty()
        || raw == "null"
        || raw.contains("error")
        || raw.contains("Error")
        || raw.contains("Exception")
    {
        return None;
    }
    serde_json::from_str(raw).ok()
}

/// Win32_Processor JSON(Dart `WindowsParser.parseCpu`)。
/// Windows only exposes an instantaneous LoadPercentage; cumulative ticks are
/// simulated by accumulating onto the previous pseudo-counters. Pass the previous
/// parse result (with the "cpu" summary head) as `prev`; the first entry is the
/// summary, matching Linux
pub fn parse_cpu(raw: &str, prev: &[CpuCore]) -> Vec<CpuCore> {
    let Some(json) = decode(raw) else {
        return Vec::new();
    };
    let mut cores: Vec<CpuCore> = Vec::new();
    let mut offset = 0usize;

    for processor in as_list(json) {
        let load = processor["LoadPercentage"].as_u64().unwrap_or(0).min(100);
        let physical = processor["NumberOfCores"].as_u64().unwrap_or(1) as usize;
        let logical =
            processor["NumberOfLogicalProcessors"].as_u64().unwrap_or(physical as u64) as usize;
        let idle = 100 - load;

        for i in 0..logical {
            let core_id = offset + i;
            // prev[0] is the summary; per-core entries start at 1
            let prev_core = prev.get(core_id + 1);
            cores.push(CpuCore {
                id: format!("cpu{}", core_id),
                user: prev_core.map(|c| c.user).unwrap_or(0) + load,
                idle: prev_core.map(|c| c.idle).unwrap_or(0) + idle,
                sys: 0,
                nice: 0,
                iowait: 0,
                irq: 0,
                softirq: 0,
            });
        }
        offset += logical;
    }

    if !cores.is_empty() {
        let summary = CpuCore {
            id: "cpu".to_string(),
            user: cores.iter().map(|c| c.user).sum(),
            idle: cores.iter().map(|c| c.idle).sum(),
            sys: 0,
            nice: 0,
            iowait: 0,
            irq: 0,
            softirq: 0,
        };
        cores.insert(0, summary);
    }
    cores
}

/// Win32_OperatingSystem JSON (Dart `WindowsParser.parseMemory`); fields are already KiB
pub fn parse_mem(raw: &str) -> Option<Memory> {
    let json = decode(raw)?;
    let data = as_list(json).into_iter().next()?;
    let total = data["TotalVisibleMemorySize"].as_u64()?;
    let free = data["FreePhysicalMemory"].as_u64().unwrap_or(0);
    Some(Memory { total, free, avail: free })
}

/// Win32_LogicalDisk JSON (Dart `WindowsParser.parseDisks`), bytes → KiB;
/// disks missing required fields are skipped
pub fn parse_disks(raw: &str) -> Vec<Disk> {
    let Some(json) = decode(raw) else {
        return Vec::new();
    };
    as_list(json)
        .into_iter()
        .filter_map(|d| {
            let device_id = d["DeviceID"].as_str().unwrap_or("").to_string();
            let size = json_u64(&d["Size"])?;
            let free = json_u64(&d["FreeSpace"])?;
            let fs = d["FileSystem"].as_str().unwrap_or("").to_string();
            // free == 0 is a valid state (full volume); only records missing fields or with zero size are skipped
            if device_id.is_empty() || size == 0 || fs.is_empty() {
                return None;
            }
            let size_kb = size / 1024;
            let free_kb = free / 1024;
            let used_kb = size_kb - free_kb;
            Some(Disk {
                used_percent: (used_kb * 100 / size_kb).min(100) as u32,
                path: device_id.clone(),
                mount: device_id,
                fs_type: Some(fs),
                used: used_kb,
                size: size_kb,
                avail: free_kb,
                ..Disk::default()
            })
        })
        .collect()
}

fn json_u64(v: &Value) -> Option<u64> {
    v.as_u64().or_else(|| v.as_str()?.parse().ok())
}

/// MSAcpi_ThermalZoneTemperature JSON (already converted to Celsius in the command)
pub fn parse_temps(raw: &str) -> Temperatures {
    let mut temps = Temperatures::default();
    let Some(json) = decode(raw) else {
        return temps;
    };
    for item in as_list(json) {
        let name = item["InstanceName"].as_str().unwrap_or("Unknown").to_string();
        if let Some(t) = item["Temperature"].as_f64() {
            temps.0.insert(name, t);
        }
    }
    temps
}

/// WMI raw perf-counter two-sample delta (Dart `_parseWindowsWmiDelta`):
/// input JSON contains >= 2 sample groups; returns (name, rx_speed, tx_speed) in bytes/sec.
/// `_Total` and empty names are skipped; timestamps are in 100ns units
pub fn parse_net_speed(raw: &str) -> Vec<(String, f64, f64)> {
    parse_wmi_delta(raw, "BytesReceivedPersec", "BytesSentPersec")
}

/// Same WMI sampling as `parse_net_speed`, taking the raw cumulative counters of
/// the last group: the `*Persec` fields of Win32_PerfRawData are actually cumulative
/// byte counts. Produces NetIface cumulative counters consistent with Linux/BSD;
/// rates are derived by the caller via cross-sample deltas
pub fn parse_net(raw: &str) -> Vec<NetIface> {
    let Some(Value::Array(samples)) = decode(raw) else {
        return Vec::new();
    };
    let Some(last) = samples.last() else {
        return Vec::new();
    };
    let last = match last.get("value") {
        Some(inner) => inner.clone(),
        None => last.clone(),
    };
    let Value::Array(list) = last else {
        return Vec::new();
    };
    list.iter()
        .filter_map(|v| {
            let name = v["Name"].as_str().unwrap_or("");
            if name.is_empty() || name == "_Total" {
                return None;
            }
            Some(NetIface {
                device: name.to_string(),
                rx_bytes: json_u64(&v["BytesReceivedPersec"])?,
                tx_bytes: json_u64(&v["BytesSentPersec"])?,
            })
        })
        .collect()
}

fn parse_wmi_delta(raw: &str, field1: &str, field2: &str) -> Vec<(String, f64, f64)> {
    let Some(Value::Array(samples)) = decode(raw) else {
        return Vec::new();
    };
    if samples.len() < 2 {
        return Vec::new();
    }
    let unwrap_value = |v: &Value| -> Value {
        match v.get("value") {
            Some(inner) => inner.clone(),
            None => v.clone(),
        }
    };
    let (s1, s2) = (
        unwrap_value(&samples[samples.len() - 2]),
        unwrap_value(&samples[samples.len() - 1]),
    );
    let (Value::Array(list1), Value::Array(list2)) = (s1, s2) else {
        return Vec::new();
    };
    if list1.len() != list2.len() {
        return Vec::new();
    }

    let num = |v: &Value, key: &str| v[key].as_f64().unwrap_or(0.0);
    let mut result = Vec::new();
    for (a, b) in list1.iter().zip(list2.iter()) {
        let name = a["Name"].as_str().unwrap_or("");
        if name.is_empty() || name == "_Total" {
            continue;
        }
        let time_delta = (num(b, "Timestamp_Sys100NS") - num(a, "Timestamp_Sys100NS")) / 1e7;
        if time_delta <= 0.0 {
            continue;
        }
        let d1 = num(b, field1) - num(a, field1);
        let d2 = num(b, field2) - num(a, field2);
        if d1 < 0.0 || d2 < 0.0 {
            continue;
        }
        result.push((name.to_string(), d1 / time_delta, d2 / time_delta));
    }
    result
}

/// Win32_Battery JSON(Dart `_parseWindowsBatteries`):
/// BatteryStatus 6/7/8 count as charging
pub fn parse_batteries(raw: &str) -> Vec<Battery> {
    let Some(json) = decode(raw) else {
        return Vec::new();
    };
    as_list(json)
        .into_iter()
        .map(|b| {
            let status = b["BatteryStatus"].as_i64().unwrap_or(0);
            Battery {
                name: Some("Battery".to_string()),
                percent: Some(b["EstimatedChargeRemaining"].as_i64().unwrap_or(0)),
                status: if matches!(status, 6..=8) {
                    BatteryStatus::Charging
                } else {
                    BatteryStatus::Discharging
                },
                cycle: None,
                tech: None,
            }
        })
        .collect()
}

/// WMI disk IO two-sample delta (Dart `_parseWindowsDiskIO`):
/// rates converted to sector counts (512B), aligned with Linux diskstats counters
pub fn parse_diskio(raw: &str) -> Vec<DiskIoPiece> {
    parse_wmi_delta(raw, "DiskReadBytesPersec", "DiskWriteBytesPersec")
        .into_iter()
        .map(|(name, read, write)| DiskIoPiece {
            dev: name,
            sectors_read: (read / 512.0).round() as i64,
            sectors_write: (write / 512.0).round() as i64,
        })
        .collect()
}

/// Win32_TemperatureProbe JSON. No Dart reference — this command has no
/// upstream app implementation (WMI temperature-probe support is spotty
/// across hardware; most machines report zero instances). `CurrentReading`
/// is tenths of Kelvin per the WMI spec; converted to Celsius here since,
/// unlike the ThermalZone command, the PowerShell side does no conversion.
pub fn parse_sensors(raw: &str) -> Vec<SensorItem> {
    let Some(json) = decode(raw) else {
        return Vec::new();
    };
    as_list(json)
        .into_iter()
        .filter_map(|p| {
            let reading = p["CurrentReading"].as_f64()?;
            let celsius = reading / 10.0 - 273.15;
            let name =
                p["Name"].as_str().filter(|s| !s.is_empty()).unwrap_or("Temperature Probe");
            Some(SensorItem {
                device: name.to_string(),
                adapter: "WMI".to_string(),
                details: vec![("temp1".to_string(), format!("{:.1}\u{b0}C", celsius))],
            })
        })
        .collect()
}

/// `Get-StorageReliabilityCounter` JSON. No Dart reference — this command has
/// no upstream app implementation. Only exposes device id/temperature/power-on
/// hours; unlike smartctl there's no direct pass/fail health flag, model, or
/// serial in this cmdlet's output, so those fields stay `None` rather than
/// guessing a health threshold from `Wear` with no documented semantics
pub fn parse_disk_smart(raw: &str) -> Vec<DiskSmart> {
    let Some(json) = decode(raw) else {
        return Vec::new();
    };
    as_list(json)
        .into_iter()
        .filter_map(|d| {
            let device_id = &d["DeviceId"];
            let device = device_id
                .as_str()
                .map(str::to_string)
                .or_else(|| device_id.as_i64().map(|n| n.to_string()))?;
            Some(DiskSmart {
                device,
                healthy: None,
                temperature: d["Temperature"].as_f64(),
                model: None,
                serial: None,
                power_on_hours: d["PowerOnHours"].as_i64(),
                power_cycle_count: None,
                raw_data: d.clone(),
                smart_attributes: Default::default(),
            })
        })
        .collect()
}

/// Brand info from Win32_Processor JSON: Name → physical core count
/// (Dart Windows branch: brand[brandName] = sum of NumberOfCores)
pub fn parse_cpu_brand(raw: &str) -> Vec<(String, u32)> {
    let Some(json) = decode(raw) else {
        return Vec::new();
    };
    let mut brands: Vec<(String, u32)> = Vec::new();
    for processor in as_list(json) {
        let Some(name) = processor["Name"].as_str().map(str::trim) else {
            continue;
        };
        if name.is_empty() {
            continue;
        }
        let cores = processor["NumberOfCores"].as_u64().unwrap_or(1) as u32;
        match brands.iter_mut().find(|(n, _)| n == name) {
            Some((_, count)) => *count += cores,
            None => brands.push((name.to_string(), cores)),
        }
    }
    brands
}
