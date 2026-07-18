//! Windows PowerShell JSON 解析(对照 Dart:windows_parser.dart +
//! server_status_update_req.dart 的 WMI 差分助手)

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
/// Windows 只有瞬时 LoadPercentage,通过累加前次伪计数模拟累计 ticks;
/// `prev` 传上次解析结果(含 "cpu" 汇总头),首个为汇总项与 Linux 对齐
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
            // prev[0] 为汇总项,逐核从 1 起
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

/// Win32_OperatingSystem JSON(Dart `WindowsParser.parseMemory`),字段已是 KiB
pub fn parse_mem(raw: &str) -> Option<Memory> {
    let json = decode(raw)?;
    let data = as_list(json).into_iter().next()?;
    let total = data["TotalVisibleMemorySize"].as_u64()?;
    let free = data["FreePhysicalMemory"].as_u64().unwrap_or(0);
    Some(Memory { total, free, avail: free })
}

/// Win32_LogicalDisk JSON(Dart `WindowsParser.parseDisks`),字节 → KiB;
/// 缺少必要字段的盘跳过
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
            if device_id.is_empty() || size == 0 || free == 0 || fs.is_empty() {
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

/// MSAcpi_ThermalZoneTemperature JSON(已在命令中换算为摄氏度)
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

/// WMI 原始性能计数双采样差分(Dart `_parseWindowsWmiDelta`):
/// 输入含 ≥2 个采样组的 JSON,返回 (name, rx_speed, tx_speed) 字节/秒。
/// `_Total` 与空名跳过;时间戳为 100ns 单位
pub fn parse_net_speed(raw: &str) -> Vec<(String, f64, f64)> {
    parse_wmi_delta(raw, "BytesReceivedPersec", "BytesSentPersec")
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
/// BatteryStatus 6/7/8 视为充电中
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

/// WMI 磁盘 IO 双采样差分(Dart `_parseWindowsDiskIO`):
/// 速率换算为扇区数(512B),与 Linux diskstats 计数对齐
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
