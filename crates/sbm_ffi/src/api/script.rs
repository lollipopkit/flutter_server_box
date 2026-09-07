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
    /// The user's custom commands. Its own function so it can run on its own
    /// cadence instead of on every status poll.
    Custom,
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
            ShellFuncKind::Custom => F::Custom,
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
///
/// `expect` is the `fingerprint` of the [`CustomCmdsListing`] this set was
/// edited from. The whole set is written at once, so without it a second app
/// editing the same server would silently discard the first's edits; with it
/// the second save is refused and reports [`custom_cmds_conflict`]. `None`
/// only for a caller that never read the directory.
#[flutter_rust_bridge::frb(sync)]
pub fn install_custom_cmds_command(
    system: String,
    cmds: Vec<CustomCmd>,
    expect: Option<String>,
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
    let script =
        sbm_parser::script::install_custom_cmds_script(system, &cmds, expect.as_deref());
    Ok(wrap_for_default_shell(system, script))
}

/// One command a plugin wants run, and the name its output is filed under.
pub struct PluginCmd {
    /// `<plugin id>:<contribution id>`, which is what the app files the
    /// readings under too.
    pub name: String,
    pub cmd: String,
}

/// A single command that runs every plugin's status command and prints each
/// one's output under its own name. PLUGINS.md 9.1.
///
/// One round trip rather than one per plugin, and nothing left on the server:
/// a plugin's command is not the user's data, and it changes whenever the
/// plugin or its configuration does. Each is bounded exactly as a custom
/// command is — a timeout, a size cap, and its output through a file rather
/// than the pipe this answer comes back on.
///
/// Fed to `customCmdsEntry`'s shell on Unix, and already a complete command
/// line on Windows, for the same reasons the custom-command scripts are.
#[flutter_rust_bridge::frb(sync)]
pub fn plugin_cmds_command(system: String, cmds: Vec<PluginCmd>) -> Result<String, String> {
    let system = parse_system_or_err(&system)?;
    let cmds: Vec<(String, String)> = cmds.into_iter().map(|c| (c.name, c.cmd)).collect();
    Ok(sbm_parser::script::inline_cmds_script(system, &cmds))
}

/// The plugin-command name in a parsed result key, or `None` when the section
/// came from somewhere else.
#[flutter_rust_bridge::frb(sync)]
pub fn plugin_result_name(key: String) -> Option<String> {
    sbm_parser::script::plugin_result_name(&key).map(str::to_string)
}

/// Whether an install refused to run because the directory had changed under
/// the caller.
#[flutter_rust_bridge::frb(sync)]
pub fn custom_cmds_conflict(output: String) -> bool {
    sbm_parser::script::custom_cmds_conflict(&output)
}

/// The fingerprint a successful install printed, for the caller's next save.
///
/// Saves reading the directory back, and closes the window in which somebody
/// else's save would land between the write and that read.
#[flutter_rust_bridge::frb(sync)]
pub fn parse_custom_cmds_fingerprint(output: String) -> Option<String> {
    sbm_parser::script::parse_custom_cmds_fingerprint(&output)
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

/// One reading of the custom-command directory.
pub struct CustomCmdsListing {
    /// Hand back to `install_custom_cmds_command` so a save that would discard
    /// another client's edits is refused. Empty, or `?`, on a host that cannot
    /// produce one — both compare equal to anything.
    pub fingerprint: String,
    pub cmds: Vec<CustomCmd>,
}

/// The installed set, parsed from `read_custom_cmds_command`'s output.
///
/// `None` means the directory does not exist — distinct from an empty `cmds`,
/// an existing directory the user has emptied. The app seeds the first case
/// from what it still holds locally and must not touch the second.
#[flutter_rust_bridge::frb(sync)]
pub fn parse_custom_cmds_listing(raw: String) -> Option<CustomCmdsListing> {
    sbm_parser::script::parse_custom_cmds_listing(&raw).map(|listing| CustomCmdsListing {
        fingerprint: listing.fingerprint,
        // Order is the position in this list: it arrives sorted, and the app
        // has no use for the numbers themselves — it reassigns them whenever
        // it writes the directory back.
        cmds: listing
            .cmds
            .into_iter()
            .map(|(_, name, cmd)| CustomCmd { name, cmd })
            .collect(),
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
