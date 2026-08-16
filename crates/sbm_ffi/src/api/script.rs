//! Script generation FFI (shared with the monitor via sbm_parser::script)
//!
//! The app resolves script paths/dirs and upload timing on the Dart side; the
//! script content, install/exec command strings, and output segment splitting
//! all come from here so app and monitor share one implementation.

use std::collections::HashMap;

use super::parser::parse_system_or_err;

/// Custom status command; a Vec preserves the Dart map's insertion order,
/// which affects script bytes
pub struct CustomCmd {
    pub name: String,
    pub cmd: String,
}

/// Shell functions of the generated script (mirrors sbm_parser::script::ShellFunc)
pub enum ShellFuncKind {
    Status,
    StatusExt,
    Process,
    Shutdown,
    Reboot,
    Suspend,
}

impl From<ShellFuncKind> for sbm_parser::script::ShellFunc {
    fn from(kind: ShellFuncKind) -> Self {
        use sbm_parser::script::ShellFunc as F;
        match kind {
            ShellFuncKind::Status => F::Status,
            ShellFuncKind::StatusExt => F::StatusExt,
            ShellFuncKind::Process => F::Process,
            ShellFuncKind::Shutdown => F::Shutdown,
            ShellFuncKind::Reboot => F::Reboot,
            ShellFuncKind::Suspend => F::Suspend,
        }
    }
}

/// Build the full script for a system ("linux" | "bsd" | "windows").
/// `disabled` uses the app's stored displayName format ("Linux.net", ...).
#[flutter_rust_bridge::frb(sync)]
pub fn build_script(
    system: String,
    disabled: Vec<String>,
    build_number: String,
) -> Result<String, String> {
    let system = parse_system_or_err(&system)?;
    let opts = sbm_parser::script::ScriptOptions { disabled, build_number };
    Ok(sbm_parser::script::build_script(system, &opts))
}

/// Script that replaces the custom-command directory beside the status script.
///
/// One round trip for the whole set, written aside and moved into place, and
/// the commands travel encoded — see `install_custom_cmds_script`.
#[flutter_rust_bridge::frb(sync)]
pub fn install_custom_cmds_command(
    system: String,
    script_dir: String,
    cmds: Vec<CustomCmd>,
) -> Result<String, String> {
    let system = parse_system_or_err(&system)?;
    let cmds: Vec<(u32, String, String)> = cmds
        .into_iter()
        .enumerate()
        .map(|(i, c)| {
            (
                // Position becomes order, spaced so one can be moved between
                // two others later without renumbering the rest.
                (i as u32 + 1) * sbm_parser::script::CUSTOM_CMD_ORDER_STEP,
                c.name,
                c.cmd,
            )
        })
        .collect();
    let script = sbm_parser::script::install_custom_cmds_script(system, &script_dir, &cmds);
    // Windows gets a complete command line, base64-wrapped, for the same
    // reason `install_command` does: the raw PowerShell would not survive a
    // host whose OpenSSH default shell is cmd.exe. Unix gets a script, to be
    // fed to `sh` on stdin so nothing has to survive quoting either.
    Ok(match system {
        sbm_parser::SystemType::Windows => {
            sbm_parser::script::encoded_powershell_command(&script)
        }
        _ => script,
    })
}

/// Command that installs the script on the target (content piped via stdin)
#[flutter_rust_bridge::frb(sync)]
pub fn install_command(
    system: String,
    script_dir: String,
    script_path: String,
) -> Result<String, String> {
    let system = parse_system_or_err(&system)?;
    Ok(sbm_parser::script::install_command(system, &script_dir, &script_path))
}

/// Command that runs one shell function of an installed script
#[flutter_rust_bridge::frb(sync)]
pub fn exec_command(
    system: String,
    script_path: String,
    func: ShellFuncKind,
) -> Result<String, String> {
    let system = parse_system_or_err(&system)?;
    Ok(sbm_parser::script::exec_command(system, &script_path, func.into()))
}

/// Command-line flag of a shell function ("s", "e", "p", "sd", "r", "sp");
/// wire format owned by sbm_parser::script
#[flutter_rust_bridge::frb(sync)]
pub fn shell_func_flag(func: ShellFuncKind) -> String {
    sbm_parser::script::ShellFunc::from(func).flag().to_string()
}

/// Split script output into a command key → output map.
/// Async: status output can be large; runs on the Rust thread pool
pub fn parse_script_output(raw: String) -> HashMap<String, String> {
    sbm_parser::script::parse_script_output(&raw)
}
