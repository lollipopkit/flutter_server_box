//! GPU parsing (Dart reference: nvdia.dart / amd.dart)

use crate::types::*;
use serde_json::Value;
use std::collections::HashMap;

/// Dart `_parseFirstInt`: parse the first space-separated segment as an integer.
/// Missing or malformed telemetry stays absent; a textual zero remains `Some(0)`.
fn parse_first_int(s: Option<&str>) -> Option<i64> {
    s.and_then(|s| s.split(' ').next())
        .and_then(|s| s.parse().ok())
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
                                pid: pid.parse().ok()?,
                                name,
                                memory: parse_first_int(Some(&memory))?,
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
                power: match (power_draw, power_limit) {
                    (None, None) => None,
                    (draw, limit) => Some(format!(
                        "{} / {}",
                        draw.as_deref().unwrap_or("null"),
                        limit.as_deref().unwrap_or("null")
                    )),
                },
                memory: match (
                    parse_first_int(mem_total.as_deref()),
                    parse_first_int(mem_used.as_deref()),
                ) {
                    (Some(total), Some(used)) => Some(GpuMem {
                        total,
                        used,
                        unit: "MiB".to_string(),
                        processes,
                    }),
                    _ => None,
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
        (None, None) => None,
        (Some(d), None) => Some(format!("{}W", d)),
        (draw, cap) => Some(format!(
            "{}W / {}W",
            draw.map_or_else(|| "N/A".to_string(), |value| value.to_string()),
            cap.map_or_else(|| "N/A".to_string(), |value| value.to_string()),
        )),
    };

    let mem = pick(&["memory", "vram"]).unwrap_or_else(|| Value::Object(Default::default()));
    let memory = match (
        amd_int(mem.get("total").or_else(|| mem.get("total_memory"))),
        amd_int(mem.get("used").or_else(|| mem.get("used_memory"))),
    ) {
        (Some(total), Some(used)) => Some(GpuMem {
            total,
            used,
            unit: mem.get("unit").and_then(|v| v.as_str()).unwrap_or("MB").to_string(),
            processes: mem
                .get("processes")
                .and_then(|v| v.as_array())
                .map(|list| {
                    list.iter()
                        .filter_map(|proc| {
                            let pid = amd_int(proc.get("pid"))?;
                            let memory = amd_int(
                                proc.get("memory").or_else(|| proc.get("used_memory")),
                            )?;
                            Some(GpuMemProcess {
                                pid,
                                name: proc
                                    .get("name")
                                    .or_else(|| proc.get("process_name"))
                                    .and_then(|v| v.as_str())
                                    .unwrap_or("Unknown")
                                    .to_string(),
                                memory,
                            })
                        })
                        .collect()
                })
                .unwrap_or_default(),
        }),
        _ => None,
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

/// Dart `AmdSmi._parseIntValue`: ints taken as-is; strings parsed after stripping non-digits
/// ("45°C" → 45). Invalid or absent values stay absent, while "0" remains `Some(0)`.
fn amd_int(value: Option<&Value>) -> Option<i64> {
    match value {
        Some(Value::Number(n)) => n.as_i64().or_else(|| n.as_f64().map(|value| value as i64)),
        Some(Value::String(s)) => {
            let digits: String = s.chars().filter(|c| c.is_ascii_digit()).collect();
            (!digits.is_empty()).then(|| digits.parse().ok()).flatten()
        }
        _ => None,
    }
}

/// Parse the marker-delimited output of the Linux DRM GPU probe.
///
/// AMD blocks contain cheap sysfs key/value readings. Intel blocks carry the
/// raw JSON emitted by `intel_gpu_top`; the last sample is used because its
/// first PMU sample is frequently an initialization spike.
pub fn linux_drm_from_output(raw: &str) -> Vec<GpuItem> {
    raw.split("__SBM_GPU_BEGIN__")
        .skip(1)
        .filter_map(|block| block.split("__SBM_GPU_END__").next())
        .filter_map(parse_drm_block)
        .collect()
}

fn parse_drm_block(block: &str) -> Option<GpuItem> {
    let mut fields = HashMap::new();
    let mut payload = Vec::new();
    let mut in_payload = false;
    for line in block.lines().map(str::trim).filter(|line| !line.is_empty()) {
        if !in_payload {
            if line.starts_with('[') || line.starts_with('{') {
                in_payload = true;
            } else if let Some((key, value)) = line.split_once('=') {
                fields.insert(key, value);
                continue;
            }
        }
        if in_payload {
            payload.push(line);
        }
    }

    let vendor = fields.get("vendor")?.to_string();
    let id = fields.get("id").copied().unwrap_or("unknown").to_string();
    let name = fields
        .get("name")
        .copied()
        .filter(|name| !name.is_empty())
        .unwrap_or("Unknown GPU")
        .to_string();

    match vendor.as_str() {
        "amd" => Some(GpuItem {
            id,
            vendor,
            name,
            utilization: fields.get("usage").and_then(|v| v.parse().ok()),
            temperature: fields
                .get("temperature_millidegrees")
                .and_then(|v| v.parse::<i64>().ok())
                .map(|v| v / 1000),
            power: fields
                .get("power_microwatts")
                .and_then(|v| v.parse::<f64>().ok())
                .map(|v| format!("{:.2} W", v / 1_000_000.0)),
            memory: drm_memory(&fields),
            fan_speed: fields.get("fan_rpm").and_then(|v| v.parse().ok()),
            clock_speed: None,
        }),
        "intel" => {
            let sample = last_intel_sample(&payload.join("\n"));
            let utilization = sample
                .as_ref()
                .and_then(|sample| sample.get("engines"))
                .and_then(Value::as_object)
                .and_then(|engines| {
                    engines
                        .values()
                        .filter_map(|engine| engine.get("busy").and_then(Value::as_f64))
                        .reduce(f64::max)
                });
            let power = sample
                .as_ref()
                .and_then(|sample| sample.get("power"))
                .and_then(|v| v.get("GPU"))
                .and_then(Value::as_f64)
                .map(|v| format!("{v:.2} W"));
            let clock_speed = sample
                .as_ref()
                .and_then(|sample| sample.get("frequency"))
                .and_then(|v| v.get("actual"))
                .and_then(Value::as_f64)
                .map(|v| v.round() as i64);
            Some(GpuItem {
                id,
                vendor,
                name,
                utilization,
                temperature: None,
                power,
                memory: None,
                fan_speed: None,
                clock_speed,
            })
        }
        _ => None,
    }
}

fn drm_memory(fields: &HashMap<&str, &str>) -> Option<GpuMem> {
    let used = fields
        .get("memory_used_bytes")
        .and_then(|v| v.parse::<i64>().ok());
    let total = fields
        .get("memory_total_bytes")
        .and_then(|v| v.parse::<i64>().ok());
    let (Some(used), Some(total)) = (used, total) else {
        return None;
    };
    Some(GpuMem {
        used: used / 1_048_576,
        total: total / 1_048_576,
        unit: "MiB".to_string(),
        processes: Vec::new(),
    })
}

fn last_intel_sample(raw: &str) -> Option<Value> {
    if let Ok(value) = serde_json::from_str::<Value>(raw) {
        return match value {
            Value::Array(values) => values.into_iter().rev().find(Value::is_object),
            Value::Object(_) => Some(value),
            _ => None,
        };
    }

    json_objects(raw)
        .into_iter()
        .filter_map(|object| serde_json::from_str::<Value>(object).ok())
        .last()
}

/// `timeout` can stop older intel_gpu_top builds after they emitted complete
/// samples but before closing the surrounding JSON array. Extract balanced
/// objects without being confused by braces inside strings.
fn json_objects(raw: &str) -> Vec<&str> {
    let mut result = Vec::new();
    let mut start = None;
    let mut depth = 0usize;
    let mut in_string = false;
    let mut escaped = false;
    for (index, ch) in raw.char_indices() {
        if in_string {
            if escaped {
                escaped = false;
            } else if ch == '\\' {
                escaped = true;
            } else if ch == '"' {
                in_string = false;
            }
            continue;
        }
        if ch == '"' {
            in_string = true;
            continue;
        }
        match ch {
            '{' => {
                if depth == 0 {
                    start = Some(index);
                }
                depth += 1;
            }
            '}' if depth > 0 => {
                depth -= 1;
                if depth == 0 {
                    if let Some(start) = start.take() {
                        result.push(&raw[start..=index]);
                    }
                }
            }
            _ => {}
        }
    }
    result
}

pub fn nvidia_as_gpu(items: &[NvidiaSmiItem]) -> Vec<GpuItem> {
    items
        .iter()
        .enumerate()
        .map(|(index, item)| GpuItem {
            id: format!("nvidia:{index}"),
            vendor: "nvidia".to_string(),
            name: item.name.clone(),
            utilization: item.percent.map(|value| value as f64),
            temperature: item.temp,
            power: item.power.clone(),
            memory: item.memory.clone(),
            fan_speed: item.fan_speed,
            clock_speed: None,
        })
        .collect()
}

pub fn amd_as_gpu(items: &[AmdSmiItem]) -> Vec<GpuItem> {
    items
        .iter()
        .enumerate()
        .map(|(index, item)| GpuItem {
            id: format!("amd:{index}"),
            vendor: "amd".to_string(),
            name: item.name.clone(),
            utilization: item.utilization.map(|value| value as f64),
            temperature: item.temp,
            power: item.power.clone(),
            memory: item.memory.clone(),
            fan_speed: item.fan_speed,
            clock_speed: item.clock_speed,
        })
        .collect()
}
