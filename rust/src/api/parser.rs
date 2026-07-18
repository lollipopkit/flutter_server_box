//! 共享解析库 FFI(ADR 0001 Phase 2)
//!
//! 边界约定:输入为「命令 key → 原始输出」映射,输出为 `sbm_parser`
//! 的 serde JSON。Dart 侧据此构造既有模型类,迁移期间可与 Dart 解析
//! 双跑比对。解析为纯函数,FFI 不持有状态。

use std::collections::HashMap;

/// 采集命令,与 App 脚本生成共用的单一事实来源
pub struct CommandSpec {
    pub key: String,
    pub cmd: String,
}

fn parse_system(system: &str) -> Option<sbm_parser::SystemType> {
    match system {
        "linux" => Some(sbm_parser::SystemType::Linux),
        "bsd" => Some(sbm_parser::SystemType::Bsd),
        "windows" => Some(sbm_parser::SystemType::Windows),
        _ => None,
    }
}

/// 解析一次采集的全部输出,返回 `ServerStatus` 的 JSON。
/// `system`: "linux" | "bsd" | "windows";`temp_divisor` 见 `ParseOptions`。
/// 异步:在 Rust 线程池执行,不阻塞 UI isolate
pub fn parse_status_json(
    system: String,
    raw: HashMap<String, String>,
    temp_divisor: f64,
) -> Result<String, String> {
    let system = parse_system(&system).ok_or_else(|| format!("unknown system: {}", system))?;
    let status = sbm_parser::parse_status_opts(
        system,
        &raw,
        sbm_parser::ParseOptions { temp_divisor },
    );
    serde_json::to_string(&status).map_err(|e| e.to_string())
}

/// Windows WMI 双采样网速差分,返回 `[{name, rx, tx}]` JSON(字节/秒)
#[flutter_rust_bridge::frb(sync)]
pub fn parse_windows_net_speed_json(raw: String) -> String {
    let speeds: Vec<_> = sbm_parser::windows::parse_net_speed(&raw)
        .into_iter()
        .map(|(name, rx, tx)| serde_json::json!({ "name": name, "rx": rx, "tx": tx }))
        .collect();
    serde_json::Value::Array(speeds).to_string()
}

/// 平台采集命令清单(App 脚本生成据此产出,与解析器同版本)
#[flutter_rust_bridge::frb(sync)]
pub fn command_specs(system: String) -> Result<Vec<CommandSpec>, String> {
    let system = parse_system(&system).ok_or_else(|| format!("unknown system: {}", system))?;
    Ok(sbm_parser::commands::commands(system)
        .iter()
        .map(|spec| CommandSpec { key: spec.key.to_string(), cmd: spec.cmd.to_string() })
        .collect())
}

/// 输出分段符(`SrvBoxSep`)
#[flutter_rust_bridge::frb(sync)]
pub fn separator() -> String {
    sbm_parser::commands::SEPARATOR.to_string()
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
