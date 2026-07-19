//! GPU parsing (Dart reference: nvdia.dart / amd.dart)

use crate::types::*;
use serde_json::Value;

/// Dart `_parseFirstInt`: parse the first space-separated segment as an integer, 0 on failure
fn parse_first_int(s: Option<&str>) -> i64 {
    s.and_then(|s| s.split(' ').next())
        .and_then(|s| s.parse().ok())
        .unwrap_or(0)
}

/// nvidia-smi -q -x output (Dart `NvidiaSmi.fromXml`).
/// GPUs missing name or temp are skipped; missing power yields "null / null", matching Dart
pub fn nvidia_from_xml(raw: &str) -> Vec<NvidiaSmiItem> {
    // roxmltree does not support DTDs; strip the DOCTYPE declaration from nvidia-smi output
    let cleaned: String = raw
        .lines()
        .filter(|l| !l.trim_start().starts_with("<!DOCTYPE"))
        .collect::<Vec<_>>()
        .join("\n");
    let Ok(doc) = roxmltree::Document::parse(cleaned.trim_start()) else {
        return Vec::new();
    };

    doc.descendants()
        .filter(|n| n.has_tag_name("gpu"))
        .filter_map(|gpu| {
            let child_text = |parent: roxmltree::Node, tag: &str| -> Option<String> {
                parent
                    .children()
                    .find(|c| c.has_tag_name(tag))
                    .map(|c| c.text().unwrap_or("").to_string())
            };
            let name = child_text(gpu, "product_name")?;
            let temp = gpu
                .children()
                .find(|c| c.has_tag_name("temperature"))
                .and_then(|t| child_text(t, "gpu_temp"))?;

            let power = gpu.children().find(|c| c.has_tag_name("gpu_power_readings"));
            let power_draw = power.and_then(|p| child_text(p, "power_draw"));
            let power_limit = power.and_then(|p| child_text(p, "current_power_limit"));

            let memory = gpu.children().find(|c| c.has_tag_name("fb_memory_usage"));
            let mem_used = memory.and_then(|m| child_text(m, "used"));
            let mem_total = memory.and_then(|m| child_text(m, "total"));

            let processes = gpu
                .children()
                .find(|c| c.has_tag_name("processes"))
                .map(|p| {
                    p.children()
                        .filter(|c| c.has_tag_name("process_info"))
                        .filter_map(|proc| {
                            let pid = child_text(proc, "pid")?;
                            let name = child_text(proc, "process_name")?;
                            let memory = child_text(proc, "used_memory")?;
                            Some(GpuMemProcess {
                                pid: pid.parse().unwrap_or(0),
                                name,
                                memory: parse_first_int(Some(&memory)),
                            })
                        })
                        .collect()
                })
                .unwrap_or_default();

            let percent = gpu
                .children()
                .find(|c| c.has_tag_name("utilization"))
                .and_then(|u| child_text(u, "gpu_util"));
            let fan_speed = child_text(gpu, "fan_speed");

            Some(NvidiaSmiItem {
                name,
                temp: parse_first_int(Some(&temp)),
                percent: parse_first_int(percent.as_deref()),
                power: format!(
                    "{} / {}",
                    power_draw.as_deref().unwrap_or("null"),
                    power_limit.as_deref().unwrap_or("null")
                ),
                memory: GpuMem {
                    total: parse_first_int(mem_total.as_deref()),
                    used: parse_first_int(mem_used.as_deref()),
                    unit: "MiB".to_string(),
                    processes,
                },
                fan_speed: parse_first_int(fan_speed.as_deref()),
            })
        })
        .collect()
}

/// amd-smi/rocm-smi JSON output (Dart `AmdSmi.fromJson`); non-array input yields empty
pub fn amd_from_json(raw: &str) -> Vec<AmdSmiItem> {
    let Ok(Value::Array(gpus)) = serde_json::from_str::<Value>(raw) else {
        return Vec::new();
    };
    gpus.iter().filter_map(parse_amd_gpu).collect()
}

fn parse_amd_gpu(gpu: &Value) -> Option<AmdSmiItem> {
    let pick = |keys: &[&str]| keys.iter().find_map(|k| gpu.get(*k)).cloned();
    let name = pick(&["name", "card_model", "device_name"])
        .and_then(|v| v.as_str().map(str::to_string))
        .unwrap_or_else(|| "Unknown AMD GPU".to_string());

    let temp = amd_int(pick(&["temperature", "temp", "gpu_temp"]).as_ref());
    let power_draw = amd_int(pick(&["power_draw", "current_power"]).as_ref());
    let power_cap = amd_int(pick(&["power_cap", "power_limit", "max_power"]).as_ref());
    let power = match (power_draw, power_cap) {
        (0, 0) => "N/A".to_string(),
        (d, 0) => format!("{}W", d),
        (d, c) => format!("{}W / {}W", d, c),
    };

    let mem = pick(&["memory", "vram"]).unwrap_or_else(|| Value::Object(Default::default()));
    let memory = GpuMem {
        total: amd_int(mem.get("total").or_else(|| mem.get("total_memory"))),
        used: amd_int(mem.get("used").or_else(|| mem.get("used_memory"))),
        unit: mem.get("unit").and_then(|v| v.as_str()).unwrap_or("MB").to_string(),
        processes: mem
            .get("processes")
            .and_then(|v| v.as_array())
            .map(|list| {
                list.iter()
                    .filter_map(|proc| {
                        let pid = amd_int(proc.get("pid"));
                        if pid == 0 {
                            return None;
                        }
                        Some(GpuMemProcess {
                            pid,
                            name: proc
                                .get("name")
                                .or_else(|| proc.get("process_name"))
                                .and_then(|v| v.as_str())
                                .unwrap_or("Unknown")
                                .to_string(),
                            memory: amd_int(proc.get("memory").or_else(|| proc.get("used_memory"))),
                        })
                    })
                    .collect()
            })
            .unwrap_or_default(),
    };

    Some(AmdSmiItem {
        name,
        temp,
        power,
        memory,
        utilization: amd_int(pick(&["utilization", "gpu_util", "activity"]).as_ref()),
        fan_speed: amd_int(pick(&["fan_speed", "fan_rpm"]).as_ref()),
        clock_speed: amd_int(pick(&["clock_speed", "gpu_clock", "sclk"]).as_ref()),
    })
}

/// Dart `AmdSmi._parseIntValue`: ints taken as-is; strings parsed after stripping non-digits ("45°C" → 45)
fn amd_int(value: Option<&Value>) -> i64 {
    match value {
        Some(Value::Number(n)) => n.as_i64().unwrap_or(0),
        Some(Value::String(s)) => {
            let digits: String = s.chars().filter(|c| c.is_ascii_digit()).collect();
            digits.parse().unwrap_or(0)
        }
        _ => 0,
    }
}
