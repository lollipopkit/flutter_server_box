//! Script generation FFI (shared with the monitor via sbm_parser::script)
//!
//! The app resolves script paths/dirs and upload timing on the Dart side; the
//! script content, install/exec command strings, and output segment splitting
//! all come from here so app and monitor share one implementation.

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

/// Script that replaces the custom-command directory.
///
/// One round trip for the whole set, written aside and moved into place, and
/// the commands travel encoded — see `install_custom_cmds_script`. The
/// directory is fixed under the user's home, so there is no path to pass.
#[flutter_rust_bridge::frb(sync)]
pub fn install_custom_cmds_command(
    system: String,
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
    let script = sbm_parser::script::install_custom_cmds_script(system, &cmds);
    Ok(wrap_for_default_shell(system, script))
}

/// Script that prints the custom-command directory back, for the editor to
/// load. Output goes to `parse_custom_cmds_listing`.
#[flutter_rust_bridge::frb(sync)]
pub fn read_custom_cmds_command(system: String) -> Result<String, String> {
    let system = parse_system_or_err(&system)?;
    Ok(wrap_for_default_shell(system, sbm_parser::script::read_custom_cmds_script(system)))
}

/// Windows gets a complete command line, base64-wrapped, for the same reason
/// `install_command` does: the raw PowerShell would not survive a host whose
/// OpenSSH default shell is cmd.exe. Unix gets a script, to be fed to `sh` on
/// stdin so nothing has to survive quoting either.
fn wrap_for_default_shell(system: sbm_parser::SystemType, script: String) -> String {
    match system {
        sbm_parser::SystemType::Windows => {
            sbm_parser::script::encoded_powershell_command(&script)
        }
        _ => script,
    }
}

/// The installed set, parsed from `read_custom_cmds_command`'s output.
///
/// `None` means the directory does not exist — distinct from `Some([])`, an
/// existing directory the user has emptied. The app seeds the first case from
/// what it still holds locally and must not touch the second.
#[flutter_rust_bridge::frb(sync)]
pub fn parse_custom_cmds_listing(raw: String) -> Option<Vec<CustomCmd>> {
    sbm_parser::script::parse_custom_cmds_listing(&raw).map(|cmds| {
        // Order is the position in this list: it arrives sorted, and the app
        // has no use for the numbers themselves — it reassigns them whenever
        // it writes the directory back.
        cmds.into_iter().map(|(_, name, cmd)| CustomCmd { name, cmd }).collect()
    })
}

/// Command that installs the script on the target (content piped via stdin,
/// as produced by [`install_payload`] — not the bare script)
#[flutter_rust_bridge::frb(sync)]
pub fn install_command(
    system: String,
    script_dir: String,
    script_path: String,
) -> Result<String, String> {
    let system = parse_system_or_err(&system)?;
    Ok(sbm_parser::script::install_command(system, &script_dir, &script_path))
}

/// What to write to [`install_command`]'s stdin for `content`.
///
/// The Windows command stops at a marker line rather than at end-of-input,
/// because Windows OpenSSH does not reliably deliver EOF to the child and
/// waiting for one hangs the install indefinitely. This adds that line, so no
/// caller has to know it exists; on Unix it returns `content` unchanged.
#[flutter_rust_bridge::frb(sync)]
pub fn install_payload(system: String, content: String) -> Result<String, String> {
    let system = parse_system_or_err(&system)?;
    Ok(sbm_parser::script::install_payload(system, &content))
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

/// One section of the script's output.
pub struct ScriptSegment {
    pub key: String,
    pub value: String,
}

/// Split script output into its sections, in the order the script printed
/// them — which for custom commands is the order the user arranged them in,
/// and the only place that order still exists by the time the app sees it.
///
/// Async: status output can be large; runs on the Rust thread pool
pub fn parse_script_segments(raw: String) -> Vec<ScriptSegment> {
    sbm_parser::script::parse_script_segments(&raw)
        .into_iter()
        .map(|(key, value)| ScriptSegment { key, value })
        .collect()
}

/// Whether output contains a valid encoded built-in or custom segment marker.
#[flutter_rust_bridge::frb(sync)]
pub fn contains_script_segment(raw: String) -> bool {
    sbm_parser::script::contains_script_segment(&raw)
}

/// Whether output contains a valid encoded built-in segment marker.
#[flutter_rust_bridge::frb(sync)]
pub fn contains_status_segment(raw: String) -> bool {
    sbm_parser::script::contains_status_segment(&raw)
}

/// Build the exact marker line used by the shared script protocol.
#[flutter_rust_bridge::frb(sync)]
pub fn script_segment_marker(key: String, custom: bool) -> String {
    if custom {
        sbm_parser::script::custom_cmd_marker(&key)
    } else {
        sbm_parser::script::cmd_marker(&key)
    }
}

/// Parsed-map key for one custom command's output.
#[flutter_rust_bridge::frb(sync)]
pub fn custom_result_key(name: String) -> String {
    sbm_parser::script::custom_result_key(&name)
}

/// Return the custom-command name when `key` is in the shared namespace.
#[flutter_rust_bridge::frb(sync)]
pub fn custom_result_name(key: String) -> Option<String> {
    sbm_parser::script::custom_result_name(&key).map(str::to_string)
}
