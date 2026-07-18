//! Windows 实机探针:以与 monitor `execute_commands` 完全相同的方式
//! (`powershell -Command <cmd>`)执行命令清单并解析,输出结果摘要。
//! 用法:交叉编译后放到 Windows 机器上直接运行。

use sbm_parser::{commands, SystemType};
use std::collections::HashMap;
use std::process::Command;

fn main() {
    let system = SystemType::Windows;
    let mut raw = HashMap::new();

    for spec in commands::commands(system) {
        let output = Command::new("powershell")
            .arg("-Command")
            .arg(spec.cmd)
            .output();
        match output {
            Ok(out) if out.status.success() => {
                let text = String::from_utf8_lossy(&out.stdout).into_owned();
                println!("[exec] {}: OK ({} bytes)", spec.key, text.len());
                raw.insert(spec.key.to_string(), text);
            }
            Ok(out) => println!(
                "[exec] {}: FAILED status={:?} stderr={}",
                spec.key,
                out.status.code(),
                String::from_utf8_lossy(&out.stderr).chars().take(200).collect::<String>()
            ),
            Err(e) => println!("[exec] {}: ERROR {}", spec.key, e),
        }
    }

    let status = sbm_parser::parse_status(system, &raw);
    println!("\n[parse] cpu cores: {}", status.cpu.len());
    if let Some(summary) = status.cpu.first() {
        let total = summary.total();
        let usage = if total == 0 { 0.0 } else { (total - summary.idle) as f64 / total as f64 * 100.0 };
        println!("[parse] cpu usage: {:.1}%", usage);
    }
    println!("[parse] mem: {:?}", status.mem);
    println!("[parse] disks: {:?}", status.disks);
    println!("[parse] temps: {:?}", status.temps);

    let net = raw.get(commands::NET).map(String::as_str).unwrap_or("");
    println!("[parse] net speeds: {:?}", sbm_parser::windows::parse_net_speed(net));
}
