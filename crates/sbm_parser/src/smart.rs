//! SMART 磁盘健康解析(对照 Dart disk_smart.dart)
//!
//! 输入为 `smartctl -a -j` 的多段 JSON(空行分隔)

use crate::types::*;
use serde_json::Value;
use std::collections::BTreeMap;

/// 物理磁盘设备名模式(Dart `_physicalDiskPatterns`)
fn is_physical_disk(device: &str) -> bool {
    let rest = |prefix: &str| device.strip_prefix(prefix);
    // /dev/sd[a-z] /dev/hd[a-z] /dev/vd[a-z] /dev/xvd[a-z]
    for prefix in ["/dev/sd", "/dev/hd", "/dev/vd", "/dev/xvd"] {
        if let Some(r) = rest(prefix)
            && r.len() == 1
            && r.chars().all(|c| c.is_ascii_lowercase())
        {
            return true;
        }
    }
    // /dev/nvme\d+n\d+
    if let Some(r) = rest("/dev/nvme")
        && let Some((a, b)) = r.split_once('n')
        && !a.is_empty()
        && !b.is_empty()
        && a.chars().all(|c| c.is_ascii_digit())
        && b.chars().all(|c| c.is_ascii_digit())
    {
        return true;
    }
    // /dev/mmcblk\d+
    if let Some(r) = rest("/dev/mmcblk")
        && !r.is_empty()
        && r.chars().all(|c| c.is_ascii_digit())
    {
        return true;
    }
    false
}

pub fn parse(raw: &str) -> Vec<DiskSmart> {
    raw.split("\n\n")
        .filter(|s| !s.trim().is_empty())
        .filter_map(|block| parse_block(block.trim()))
        .collect()
}

fn parse_block(block: &str) -> Option<DiskSmart> {
    let data: Value = serde_json::from_str(block).ok()?;
    let device = data["device"]["name"].as_str().unwrap_or("").to_string();
    if !is_physical_disk(&device) {
        return None;
    }

    let attributes = parse_attributes(&data);
    let str_of = |v: &Value| v.as_str().map(str::to_string);

    Some(DiskSmart {
        healthy: parse_health(&data),
        temperature: extract_temperature(&data, &attributes),
        model: str_of(&data["model_name"])
            .or_else(|| str_of(&data["model_family"]))
            .or_else(|| str_of(&data["device"]["model_name"])),
        serial: str_of(&data["serial_number"])
            .or_else(|| str_of(&data["device"]["serial_number"])),
        power_on_hours: data["power_on_time"]["hours"]
            .as_i64()
            .or_else(|| attributes.get("Power_On_Hours")?.raw_value.as_i64()),
        power_cycle_count: data["power_cycle_count"]
            .as_i64()
            .or_else(|| attributes.get("Power_Cycle_Count")?.raw_value.as_i64()),
        smart_attributes: attributes,
        raw_data: data,
        device,
    })
}

/// Dart `_parseHealthStatus`
fn parse_health(data: &Value) -> Option<bool> {
    let smart_status = &data["smart_status"];
    if let Some(passed) = smart_status["passed"].as_bool() {
        return Some(passed);
    }
    if let Some(status) = smart_status["status"].as_str() {
        let status = status.to_lowercase();
        if status.contains("pass") || status.contains("ok") {
            return Some(true);
        }
        if status.contains("fail") {
            return Some(false);
        }
    }
    if let Some(status) = smart_status.as_str() {
        let status = status.to_lowercase();
        if status.contains("pass") || status.contains("ok") {
            return Some(true);
        }
        if status.contains("fail") {
            return Some(false);
        }
    }

    const CRITICAL_ATTRS: [&str; 5] = [
        "Reallocated_Sector_Ct",
        "Reallocated_Event_Count",
        "Current_Pending_Sector",
        "Offline_Uncorrectable",
        "UDMA_CRC_Error_Count",
    ];
    let table = data["ata_smart_attributes"]["table"].as_array();
    if let Some(table) = table {
        for attr in table {
            if let Some(when_failed) = attr["when_failed"].as_str()
                && !when_failed.is_empty()
                && when_failed != "never"
            {
                return Some(false);
            }
            if let (Some(name), Some(value), Some(thresh)) = (
                attr["name"].as_str(),
                attr["value"].as_i64(),
                attr["thresh"].as_i64(),
            ) && thresh > 0
                && CRITICAL_ATTRS.contains(&name)
                && value < thresh
            {
                return Some(false);
            }
        }
        if !table.is_empty() {
            return Some(true);
        }
    }
    // 状态不明,视为健康(Dart 同)
    Some(true)
}

fn parse_attributes(data: &Value) -> BTreeMap<String, SmartAttribute> {
    let mut attributes = BTreeMap::new();
    let Some(table) = data["ata_smart_attributes"]["table"].as_array() else {
        return attributes;
    };
    for attr in table {
        let Some(name) = attr["name"].as_str() else {
            continue;
        };
        let flags = &attr["flags"];
        attributes.insert(
            name.to_string(),
            SmartAttribute {
                id: attr["id"].as_i64(),
                name: name.to_string(),
                value: attr["value"].as_i64(),
                worst: attr["worst"].as_i64(),
                thresh: attr["thresh"].as_i64(),
                when_failed: attr["when_failed"].as_str().map(str::to_string),
                raw_value: attr["raw"]["value"].clone(),
                raw_string: attr["raw"]["string"].as_str().map(str::to_string),
                flags: SmartAttributeFlags {
                    value: flags["value"].as_i64(),
                    string: flags["string"].as_str().map(str::to_string),
                    prefailure: flags["prefailure"].as_bool().unwrap_or(false),
                    updated_online: flags["updated_online"].as_bool().unwrap_or(false),
                    performance: flags["performance"].as_bool().unwrap_or(false),
                    error_rate: flags["error_rate"].as_bool().unwrap_or(false),
                    event_count: flags["event_count"].as_bool().unwrap_or(false),
                    auto_keep: flags["auto_keep"].as_bool().unwrap_or(false),
                },
            },
        );
    }
    attributes
}

/// Dart `_extractTemperature`:优先 temperature.current,
/// 其次 Temperature_Celsius 属性的 raw_string 前缀数字或 raw_value(< 150)
fn extract_temperature(data: &Value, attrs: &BTreeMap<String, SmartAttribute>) -> Option<f64> {
    if let Some(t) = data["temperature"]["current"].as_f64() {
        return Some(t);
    }
    let attr = attrs.get("Temperature_Celsius")?;
    if let Some(raw) = &attr.raw_string {
        let leading: String = raw
            .chars()
            .take_while(|c| c.is_ascii_digit() || *c == '.')
            .collect();
        if let Ok(t) = leading.parse() {
            return Some(t);
        }
    }
    if let Some(v) = attr.raw_value.as_f64()
        && v < 150.0
    {
        return Some(v);
    }
    None
}
