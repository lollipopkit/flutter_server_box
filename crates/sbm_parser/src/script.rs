//! Script generation shared by the app (via FFI) and the monitor.
//!
//! Literal port of the app's Dart script layer (`lib/data/model/app/scripts/`):
//! every template artifact (blank lines, tab prefixes, trailing trims) is
//! preserved so the output is byte-identical to the historical Dart builders.
//! The app uploads the generated script over SSH and calls it with a flag; the
//! monitor executes the same script locally.
//!
//! Status collection is split across two functions: `SbStatus` for the fast
//! poll and `SbStatusExt` for the commands in `commands::EXTENDED`, which both
//! callers run on a much slower cadence.

use crate::SystemType;
use crate::commands::{self, CommandSpec, SEPARATOR};
use std::collections::HashMap;

/// Custom-command segment separator (`SrvBoxCusCmdSep.b64.<name>`)
pub const CUSTOM_CMD_SEPARATOR: &str = "SrvBoxCusCmdSep";

/// Marks a segment marker's name as base64url-encoded.
///
/// Markers are ordinary lines in the same stream as command output, so a
/// command that prints `SrvBoxSep.cpu` would previously have opened a new
/// section. Encoding the name means a marker is only recognised as
/// `<sep>.b64.<base64url>`, and [`parse_script_output`] rejects anything else
/// as data. Custom commands run arbitrary user shell, which is where an
/// unencoded marker was realistically reachable.
const ENCODED_NAME_PREFIX: &str = "b64.";

/// Directory the per-command files live in.
///
/// Custom commands are files rather than lines spliced into the script, and
/// that is the difference between "a user's typo breaks their status page" and
/// "a user's typo breaks that one command". It also stops user configuration
/// from changing the script's bytes at all: the script is a function of the
/// manifest, and the commands are data it reads.
///
/// The path is fixed under the invoking user's home rather than beside the
/// script, because the script's directory defaults to a temp one and is
/// swapped at runtime when that turns out to be unwritable. This directory is
/// the only copy of something a user typed, so it must outlive a reboot and
/// must not move when the script does. It also means the app over SSH and a
/// monitor running as the same user read one set rather than two.
pub const CUSTOM_CMD_DIR_UNIX: &str = "$HOME/.config/server_box/custom_cmds";

/// The Windows form of [`CUSTOM_CMD_DIR_UNIX`], as a PowerShell expression.
pub const CUSTOM_CMD_DIR_WINDOWS: &str =
    "(Join-Path $env:USERPROFILE '.config\\server_box\\custom_cmds')";

/// First line of [`read_custom_cmds_script`]'s output when the directory
/// exists. Absent means it does not — which is not the same as an empty
/// directory, and the app's migration relies on telling those apart.
pub const CUSTOM_CMD_DIR_MARKER: &str = "SrvBoxCusCmdDir";
pub const CUSTOM_CMD_DIR_END_MARKER: &str = "SrvBoxCusCmdDirEnd";
pub const CUSTOM_CMD_DIR_MISSING_MARKER: &str = "SrvBoxCusCmdDirMissing";
const CUSTOM_CMD_OUTPUT_PREFIX: &str = "SrvBoxCusCmdOut.";

/// The custom-command directory for a platform, as an expression the platform's
/// shell expands.
pub fn custom_cmd_dir(system: SystemType) -> &'static str {
    match system {
        SystemType::Windows => CUSTOM_CMD_DIR_WINDOWS,
        SystemType::Linux | SystemType::Bsd => CUSTOM_CMD_DIR_UNIX,
    }
}

/// The same directory as a path on the machine this process is running on,
/// for the monitor, which reads and writes it directly rather than through a
/// shell it generated.
///
/// `None` when the process has no home directory in its environment, which is
/// how a service can be started: there is then no directory to speak of, and
/// the caller has to say so rather than invent one relative to the working
/// directory.
///
/// Kept here beside the shell expression it must agree with — `script_compat`
/// checks that they still name the same place.
pub fn custom_cmd_dir_path() -> Option<std::path::PathBuf> {
    #[cfg(windows)]
    let home = std::env::var_os("USERPROFILE").filter(|h| !h.is_empty())?;
    #[cfg(not(windows))]
    let home = std::env::var_os("HOME").filter(|h| !h.is_empty())?;
    Some(
        std::path::PathBuf::from(home)
            .join(".config")
            .join("server_box")
            .join(CUSTOM_CMD_DIR_LEAF),
    )
}

/// The last path component, shared by the expressions and the path above.
pub const CUSTOM_CMD_DIR_LEAF: &str = "custom_cmds";

/// Spacing between the order prefixes of adjacent commands.
///
/// Sparse on purpose: moving a command between two others is then a rename of
/// one file rather than a renumbering of all of them, which matters when the
/// files are on a server at the end of an SSH connection.
pub const CUSTOM_CMD_ORDER_STEP: u32 = 100;

/// Maximum stdout retained from one custom command.
pub const CUSTOM_CMD_MAX_OUTPUT_BYTES: usize = 64 * 1024;

/// The file a custom command is stored as: `NNNNN_<encoded name>`.
///
/// Zero-padded so that sorting the directory by name sorts it by order, which
/// is what the script does and what saves it from having to parse anything.
/// The name is base64url after the underscore, so a command may be called
/// whatever the user likes without any of it reaching a shell.
pub fn custom_cmd_file_name(order: u32, name: &str) -> String {
    format!("{order:05}_{}", encode_marker_name(name))
}

/// The extension the file carries on a platform, empty where it needs none.
///
/// Windows names them `.ps1` because `&` will not run an extensionless file.
/// It is not part of the encoded name — see [`custom_cmd_name_from_file`].
pub fn custom_cmd_file_ext(system: SystemType) -> &'static str {
    match system {
        SystemType::Windows => ".ps1",
        SystemType::Linux | SystemType::Bsd => "",
    }
}

/// The name back out of a file name, or `None` if it is not one of ours.
pub fn custom_cmd_name_from_file(file_name: &str) -> Option<String> {
    let file_name = file_name.strip_suffix(".ps1").unwrap_or(file_name);
    let (order, encoded) = file_name.split_once('_')?;
    if order.is_empty() || !order.bytes().all(|b| b.is_ascii_digit()) {
        return None;
    }
    decode_marker_name(&format!("{ENCODED_NAME_PREFIX}{encoded}"))
}

fn custom_cmd_name_from_file_for(system: SystemType, file_name: &str) -> Option<String> {
    match system {
        SystemType::Windows => custom_cmd_name_from_file(file_name.strip_suffix(".ps1")?),
        SystemType::Linux | SystemType::Bsd if !file_name.ends_with(".ps1") => {
            custom_cmd_name_from_file(file_name)
        }
        _ => None,
    }
}

/// Validates one custom-command file for the platform this binary runs on.
pub fn custom_cmd_name_from_file_for_current_platform(file_name: &str) -> Option<String> {
    #[cfg(windows)]
    let system = SystemType::Windows;
    #[cfg(not(windows))]
    let system = SystemType::Linux;
    custom_cmd_name_from_file_for(system, file_name)
}

fn encode_marker_name(name: &str) -> String {
    use base64::Engine;
    base64::engine::general_purpose::URL_SAFE.encode(name)
}

fn decode_marker_name(encoded: &str) -> Option<String> {
    use base64::Engine;
    let bytes = base64::engine::general_purpose::URL_SAFE
        .decode(encoded.strip_prefix(ENCODED_NAME_PREFIX)?)
        .ok()?;
    String::from_utf8(bytes).ok()
}

/// Segment marker for a built-in command
pub fn cmd_marker(key: &str) -> String {
    format!(
        "{SEPARATOR}.{ENCODED_NAME_PREFIX}{}",
        encode_marker_name(key)
    )
}

/// Segment marker for a custom command
pub fn custom_cmd_marker(name: &str) -> String {
    format!(
        "{CUSTOM_CMD_SEPARATOR}.{ENCODED_NAME_PREFIX}{}",
        encode_marker_name(name)
    )
}

/// Key a custom command's output is filed under in [`parse_script_output`].
///
/// Namespaced rather than the bare name: custom command names come from the
/// user, and one called `cpu` or `disk` would otherwise overwrite the built-in
/// section of that name and take down the whole status page.
pub fn custom_result_key(name: &str) -> String {
    format!("{CUSTOM_CMD_SEPARATOR}.{name}")
}

/// The custom-command name encoded in a parsed result key.
///
/// Keeping this next to [`custom_result_key`] makes classification use the
/// same namespace that produced the key instead of mirroring its prefix in
/// every consumer.
pub fn custom_result_name(key: &str) -> Option<&str> {
    let name = key.strip_prefix(CUSTOM_CMD_SEPARATOR)?.strip_prefix('.')?;
    (!name.is_empty()).then_some(name)
}

/// Shell functions exposed by the generated script. Names and flags are wire
/// format: `sh script.sh -s` dispatches to `SbStatus`, etc.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ShellFunc {
    Status,
    /// The `commands::EXTENDED` subset, split out of [`ShellFunc::Status`] so
    /// callers can run it on a slower cadence than the status poll
    StatusExt,
    Process,
    Shutdown,
    Reboot,
    Suspend,
}

impl ShellFunc {
    pub const ALL: [ShellFunc; 6] = [
        ShellFunc::Status,
        ShellFunc::StatusExt,
        ShellFunc::Process,
        ShellFunc::Shutdown,
        ShellFunc::Reboot,
        ShellFunc::Suspend,
    ];

    pub fn name(self) -> &'static str {
        match self {
            ShellFunc::Status => "SbStatus",
            ShellFunc::StatusExt => "SbStatusExt",
            ShellFunc::Process => "SbProcess",
            ShellFunc::Shutdown => "SbShutdown",
            ShellFunc::Reboot => "SbReboot",
            ShellFunc::Suspend => "SbSuspend",
        }
    }

    pub fn flag(self) -> &'static str {
        match self {
            ShellFunc::Status => "s",
            ShellFunc::StatusExt => "e",
            ShellFunc::Process => "p",
            ShellFunc::Shutdown => "sd",
            ShellFunc::Reboot => "r",
            ShellFunc::Suspend => "sp",
        }
    }
}

/// Options controlling script generation
#[derive(Debug, Clone, Default)]
pub struct ScriptOptions {
    /// Disabled command keys in the app's stored displayName format
    /// ("Linux.net", "BSD.mem", "Windows.cpu"); compared case-insensitively
    pub disabled: Vec<String>,
    /// App build number embedded in the header comment ("v1.0.<build>")
    pub build_number: String,
}

/// A script that replaces the custom-command directory with [`cmds`].
///
/// One round trip, not one per command: these files are at the end of an SSH
/// connection, and a user with a dozen commands should not pay a dozen
/// latencies for a change to one of them.
///
/// Written to a new directory and moved into place, so a status poll landing
/// mid-install sees the old set or the new one and never half of each. The old
/// directory goes with the move, which is also how a deleted command stops
/// running — there is nothing else to remember to remove.
///
/// Contents travel base64-encoded. A custom command is arbitrary text that a
/// user typed, and a heredoc carrying it verbatim would end wherever the text
/// happened to say so.
pub fn install_custom_cmds_script(system: SystemType, cmds: &[(u32, String, String)]) -> String {
    use base64::Engine;
    let b64 = base64::engine::general_purpose::STANDARD;

    match system {
        SystemType::Windows => {
            let mut out = format!(
                "$ErrorActionPreference = 'Stop'\n\
                 $dir = {CUSTOM_CMD_DIR_WINDOWS}\n\
                 $tmp = \"$dir.new\"\n\
                 if (Test-Path $tmp) {{ Remove-Item -Recurse -Force $tmp }}\n\
                 New-Item -ItemType Directory -Force -Path $tmp | Out-Null\n"
            );
            let ext = custom_cmd_file_ext(SystemType::Windows);
            for (order, name, cmd) in cmds {
                let file = custom_cmd_file_name(*order, name);
                out.push_str(&format!(
                    "[IO.File]::WriteAllBytes((Join-Path $tmp '{file}{ext}'),                      [Convert]::FromBase64String('{}'))\n",
                    b64.encode(cmd)
                ));
            }
            out.push_str(
                "$bak = \"$dir.bak\"\n\
                 if (Test-Path $bak) { Remove-Item -Recurse -Force $bak }\n\
                 if (Test-Path $dir) { Rename-Item $dir $bak -Force }\n\
                 try {\n\
                 \x20 Move-Item $tmp $dir -ErrorAction Stop\n\
                 } catch {\n\
                 \x20 if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }\n\
                 \x20 if (Test-Path $bak) { Rename-Item $bak $dir -Force }\n\
                 \x20 throw\n\
                 }\n\
                 if (Test-Path $bak) { Remove-Item -Recurse -Force $bak }\n",
            );
            out
        }
        SystemType::Linux | SystemType::Bsd => {
            let mut out = format!(
                "set -e\n\
                 d=\"{CUSTOM_CMD_DIR_UNIX}\"\n\
                 t=\"$d.new\"\n\
                 b=\"$d.bak\"\n\
                 rm -rf \"$t\" \"$b\"\n\
                 mkdir -p \"$t\"\n"
            );
            for (order, name, cmd) in cmds {
                let file = custom_cmd_file_name(*order, name);
                out.push_str(&format!(
                    "printf %s '{}' | base64 -d > \"$t/{file}\"\n",
                    b64.encode(cmd)
                ));
            }
            out.push_str(
                "if [ -e \"$d\" ]; then mv \"$d\" \"$b\"; fi\n\
                 if ! mv \"$t\" \"$d\"; then\n\
                 \x20 rm -rf \"$d\"\n\
                 \x20 if [ -e \"$b\" ]; then mv \"$b\" \"$d\"; fi\n\
                 \x20 exit 1\n\
                 fi\n\
                 rm -rf \"$b\"\n",
            );
            out
        }
    }
}

/// A script that prints the custom-command directory back, for an editor to
/// load. Output is [`parse_custom_cmds_listing`]'s input.
///
/// Each file becomes one line, `<file name> <base64 of its content>`. Encoded
/// for the same reason the installer encodes: the content is arbitrary text a
/// user typed, including newlines, and a line-oriented format that carried it
/// raw would be a format the content can forge.
///
/// Prints nothing at all when the directory does not exist, which the caller
/// must distinguish from a directory that exists and is empty — the first
/// means "never installed here", the second means "the user deleted them all".
pub fn read_custom_cmds_script(system: SystemType) -> String {
    match system {
        SystemType::Windows => format!(
            "$d = {CUSTOM_CMD_DIR_WINDOWS}\n\
             if (-not (Test-Path $d) -and (Test-Path \"$d.bak\")) {{ $d = \"$d.bak\" }}\n\
             if (Test-Path $d) {{\n\
             \x20 Write-Host '{CUSTOM_CMD_DIR_MARKER}'\n\
             \x20 Get-ChildItem -File $d | Sort-Object Name | ForEach-Object {{\n\
             \x20   if ($_.Name -match '^[0-9]{{5}}_[A-Za-z0-9_=-]+\\.ps1$') {{\n\
             \x20     Write-Host (\"{{0}} {{1}}\" -f $_.Name, [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName)))\n\
             \x20   }}\n\
             \x20 }}\n\
             \x20 Write-Host '{CUSTOM_CMD_DIR_END_MARKER}'\n\
             }} else {{\n\
             \x20 Write-Host '{CUSTOM_CMD_DIR_MISSING_MARKER}'\n\
             }}\n"
        ),
        SystemType::Linux | SystemType::Bsd => format!(
            "d=\"{CUSTOM_CMD_DIR_UNIX}\"\n\
             [ -d \"$d\" ] || d=\"$d.bak\"\n\
             if [ ! -d \"$d\" ]; then echo {CUSTOM_CMD_DIR_MISSING_MARKER}; exit 0; fi\n\
             echo {CUSTOM_CMD_DIR_MARKER}\n\
             for f in \"$d\"/*; do\n\
             \t[ -f \"$f\" ] || continue\n\
             \tn=${{f##*/}}\n\
             \to=${{n%%_*}}\n\
             \te=${{n#*_}}\n\
             \t[ ${{#o}} -eq 5 ] || continue\n\
             \tcase \"$o\" in *[!0-9]*) continue;; esac\n\
             \tcase \"$e\" in ''|*[!A-Za-z0-9_=-]*) continue;; esac\n\
             \tprintf '%s ' \"$n\"\n\
             \tbase64 < \"$f\" | tr -d '\\n'\n\
             \techo\n\
             done\n\
             echo {CUSTOM_CMD_DIR_END_MARKER}\n"
        ),
    }
}

/// The directory [`read_custom_cmds_script`] printed, as `(order, name, cmd)`
/// in file-name order.
///
/// `None` when the directory does not exist. Files that are not ours — a name
/// without an order prefix, content that is not valid base64 — are skipped
/// rather than failing the whole listing: the directory is on someone's
/// server, and a stray file in it should not cost them the editor.
pub fn parse_custom_cmds_listing(raw: &str) -> Option<Vec<(u32, String, String)>> {
    use base64::Engine;
    let b64 = base64::engine::general_purpose::STANDARD;

    let lines: Vec<_> = raw
        .split('\n')
        .map(|line| line.strip_suffix('\r').unwrap_or(line))
        .collect();
    let last_end = lines
        .iter()
        .rposition(|line| line.trim() == CUSTOM_CMD_DIR_END_MARKER);
    let last_missing = lines
        .iter()
        .rposition(|line| line.trim() == CUSTOM_CMD_DIR_MISSING_MARKER);
    if last_missing.is_some_and(|missing| last_end.is_none_or(|end| missing > end)) {
        return None;
    }
    let end = last_end?;
    let start = lines[..end]
        .iter()
        .rposition(|line| line.trim() == CUSTOM_CMD_DIR_MARKER)?;
    let mut out = Vec::new();
    for line in &lines[start + 1..end] {
        let Some((file, encoded)) = line.split_once(' ') else {
            continue;
        };
        let Some(name) = custom_cmd_name_from_file(file) else {
            continue;
        };
        let Some(order) = file
            .split_once('_')
            .and_then(|(o, _)| o.parse::<u32>().ok())
        else {
            continue;
        };
        let Ok(bytes) = b64.decode(encoded.trim()) else {
            continue;
        };
        let Ok(cmd) = String::from_utf8(bytes) else {
            continue;
        };
        out.push((order, name, cmd));
    }
    Some(out)
}

/// Build the full script. Linux and Bsd produce the identical Unix script
/// (the script self-detects the OS at runtime); Windows produces PowerShell.
pub fn build_script(system: SystemType, opts: &ScriptOptions) -> String {
    match system {
        SystemType::Windows => build_windows_script(opts),
        SystemType::Linux | SystemType::Bsd => build_unix_script(opts),
    }
}

/// Wrap a PowerShell snippet as `powershell -EncodedCommand ...` so it runs
/// unmodified from any Windows default shell (cmd.exe or PowerShell) with no
/// quoting/expansion ambiguity; stdin stays available to the snippet
pub fn encoded_powershell_command(ps: &str) -> String {
    use base64::Engine;
    let utf16le: Vec<u8> = ps.encode_utf16().flat_map(u16::to_le_bytes).collect();
    format!(
        "powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand {}",
        base64::engine::general_purpose::STANDARD.encode(utf16le)
    )
}

/// The line that ends the piped script content on Windows.
///
/// Not a delimiter anyone picked for taste: the Windows install command cannot
/// read to end-of-input, so the end has to be *in* the input. Carries the
/// `SrvBoxSep` prefix the rest of this module uses for its markers, so a line
/// of a generated script can no more collide with it than with a segment
/// separator.
pub const WINDOWS_INSTALL_EOF: &str = "SrvBoxSep.__install_eof__";

/// Command that installs the script on the target (script content is piped via
/// stdin, terminated by [`install_payload`]). The Windows variant is
/// base64-encoded: the raw PowerShell syntax would fail on hosts whose OpenSSH
/// default shell is cmd.exe
///
/// # Why Windows reads lines instead of reading to the end
///
/// It used to be `[System.Console]::In.ReadToEnd()`, which waits for EOF on
/// stdin, and Windows OpenSSH does not reliably deliver the channel's EOF to
/// the child process. PowerShell then waits for input that will not arrive
/// while sshd waits for the command to exit — the install never returns, and
/// nothing times out, because both ends believe the other owes them something.
///
/// It is not deterministic and it is not rare. Measured against a Windows 11
/// host, one install per attempt: at ~4.5 KiB, the size of the real script, the
/// app's own client hung in 4 of 5 attempts, and the system `ssh` behaved the
/// same. The successful attempts finished in ~165ms, so the two outcomes are
/// "instant" and "forever" — there is no slow case to wait out. Larger input
/// makes it more likely (256 KiB hung in every attempt), which is what led to
/// the pipe rather than to PowerShell.
///
/// Reading lines until [`WINDOWS_INSTALL_EOF`] needs no EOF: the same 256 KiB
/// that never once got through goes in every time, in about a second.
///
/// `test/windows_install_ssh_e2e_test.dart` is the regression test, over the
/// same client the app uses.
fn shell_quote_unix(s: &str) -> String {
    format!("'{}'", s.replace('\'', "'\\''"))
}
fn shell_quote_ps(s: &str) -> String {
    format!("'{}'", s.replace('\'', "''"))
}

pub fn install_command(system: SystemType, script_dir: &str, script_path: &str) -> String {
    match system {
        SystemType::Windows => {
            let qdir = shell_quote_ps(script_dir);
            let qpath = shell_quote_ps(script_path);
            encoded_powershell_command(&format!(
                "New-Item -ItemType Directory -Force -Path {qdir} | Out-Null; \
$sb = New-Object System.Text.StringBuilder; \
while (($line = [System.Console]::In.ReadLine()) -ne $null) {{ \
if ($line -eq '{WINDOWS_INSTALL_EOF}') {{ break }}; \
[void]$sb.AppendLine($line) \
}}; \
Set-Content -Path {qpath} -Value $sb.ToString() -Encoding UTF8"
            ))
        }
        _ => format!(
            "mkdir -p {}\ncat > {}\nchmod 755 {}\n",
            shell_quote_unix(script_dir),
            shell_quote_unix(script_path),
            shell_quote_unix(script_path)
        ),
    }
}

/// What to write to the install command's stdin for `content`.
///
/// Exists so that no caller has to know that Windows needs a terminator, or
/// which one — the app writes this and closes the stream exactly as before, and
/// on Unix it is `content` unchanged.
pub fn install_payload(system: SystemType, content: &str) -> String {
    match system {
        // A trailing newline before the marker whether or not the script ends
        // with one: the marker has to be a line by itself to be recognised
        SystemType::Windows => {
            let sep = if content.ends_with('\n') { "" } else { "\n" };
            format!("{content}{sep}{WINDOWS_INSTALL_EOF}\n")
        }
        _ => content.to_owned(),
    }
}

/// Command that runs one shell function of an installed script
pub fn exec_command(system: SystemType, script_path: &str, func: ShellFunc) -> String {
    match system {
        SystemType::Windows => encoded_powershell_command(&format!(
            "& {} -{}",
            shell_quote_ps(script_path),
            func.flag()
        )),
        _ => format!("sh {} -{}", shell_quote_unix(script_path), func.flag()),
    }
}

/// Split script output into a command key → output map.
///
/// Built-in sections are keyed by the command key; custom commands by
/// [`custom_result_key`].
///
/// Only the encoded marker form is recognised (see [`ENCODED_NAME_PREFIX`]);
/// a line that merely starts with `SrvBoxSep.` is command output and is
/// buffered as such.
///
/// A trailing `\r` is stripped from each line before matching, so CRLF output
/// (monitor running PowerShell locally) parses identically to LF output.
pub fn parse_script_output(raw: &str) -> HashMap<String, String> {
    let mut map = HashMap::new();
    for (k, v) in parse_script_segments(raw) {
        // Keep first value for duplicate keys: a custom command that prints
        // a fake `SrvBoxSep.b64.<built-in>` marker must not overwrite the
        // real built-in segment that preceded it.
        map.entry(k).or_insert(v);
    }
    map
}

/// [`parse_script_output`], but in the order the script printed the sections.
///
/// Custom commands are ordered by the user, and that order is the order of
/// the files, which is the order they run in, which is this. A map loses it —
/// so the app reads this and keeps the order all the way to the status page,
/// while callers that only look sections up by key can take the map.
pub fn parse_script_segments(raw: &str) -> Vec<(String, String)> {
    let mut result = Vec::new();
    if raw.is_empty() {
        return result;
    }

    let sep_prefix = format!("{SEPARATOR}.");
    let custom_prefix = format!("{CUSTOM_CMD_SEPARATOR}.");
    let mut current: Option<String> = None;
    let mut buf = String::new();

    let flush =
        |current: &mut Option<String>, buf: &mut String, result: &mut Vec<(String, String)>| {
            if let Some(key) = current.take() {
                // Preserve custom command output losslessly; only the final
                // trailing newline added by the loop is removed. Previous
                // `trim()` stripped leading/trailing blank lines.
                let mut out = buf.clone();
                if out.ends_with('\n') {
                    out.pop();
                }
                if out.ends_with('\r') {
                    out.pop();
                }
                if custom_result_name(&key).is_some()
                    && let Some(encoded) = out.strip_prefix(CUSTOM_CMD_OUTPUT_PREFIX)
                {
                    use base64::Engine;
                    if let Ok(bytes) = base64::engine::general_purpose::STANDARD.decode(encoded) {
                        out = String::from_utf8_lossy(&bytes).into_owned();
                    }
                }
                result.push((key, out));
                buf.clear();
            }
        };

    for line in raw.split_terminator('\n') {
        let line = line.strip_suffix('\r').unwrap_or(line);
        let allow_builtin = current.as_deref().and_then(custom_result_name).is_none();
        let marker = marker_key(line, &sep_prefix, &custom_prefix, allow_builtin);
        match marker {
            Some(key) => {
                flush(&mut current, &mut buf, &mut result);
                current = Some(key);
            }
            None if current.is_some() => {
                buf.push_str(line);
                buf.push('\n');
            }
            None => {}
        }
    }
    flush(&mut current, &mut buf, &mut result);

    result
}

fn marker_key(
    line: &str,
    sep_prefix: &str,
    custom_prefix: &str,
    allow_builtin: bool,
) -> Option<String> {
    let builtin = allow_builtin
        .then(|| line.strip_prefix(sep_prefix).and_then(decode_marker_name))
        .flatten();
    builtin.or_else(|| {
        line.strip_prefix(custom_prefix)
            .and_then(decode_marker_name)
            .map(|name| custom_result_key(&name))
    })
}

/// Whether output contains at least one valid built-in or custom segment.
///
/// Only encoded marker lines count, matching [`parse_script_segments`]. A
/// command is free to print text such as `SrvBoxSep.cpu` without turning an
/// otherwise invalid response into a status sample.
pub fn contains_script_segment(raw: &str) -> bool {
    let sep_prefix = format!("{SEPARATOR}.");
    let custom_prefix = format!("{CUSTOM_CMD_SEPARATOR}.");
    raw.split('\n').any(|line| {
        let line = line.strip_suffix('\r').unwrap_or(line);
        marker_key(line, &sep_prefix, &custom_prefix, true).is_some()
    })
}

/// Whether output contains at least one valid built-in segment marker.
///
/// The extended-status cache uses this stricter form because custom commands
/// belong to the ordinary status function and must not replace cached SMART
/// or AMD output on their own.
pub fn contains_status_segment(raw: &str) -> bool {
    parse_script_segments(raw)
        .iter()
        .any(|(key, _)| custom_result_name(key).is_none())
}

// ---------- internal: shared filtering ----------

/// Whether the user disabled this command for `scope`, the displayName prefix
/// used by the app ("Linux"/"BSD"/"Windows").
fn enabled(spec: &CommandSpec, scope: &str, opts: &ScriptOptions) -> bool {
    let display_name = format!("{scope}.{}", spec.key);
    !opts
        .disabled
        .iter()
        .any(|d| d.eq_ignore_ascii_case(&display_name))
}

/// `divider + cmd` segments joined and right-trimmed (Dart `_get*StatusCommand`),
/// limited to the half of the manifest `extended` selects
fn segment_list(
    specs: &[CommandSpec],
    scope: &str,
    opts: &ScriptOptions,
    extended: bool,
    divider: impl Fn(&str) -> String,
) -> String {
    let joined: String = specs
        .iter()
        .filter(|s| s.is_extended() == extended && enabled(s, scope, opts))
        .map(|s| format!("{}{}", divider(s.key), s.cmd))
        .collect();
    joined.trim_end().to_string()
}

// ---------- internal: Unix ----------

fn unix_header(build_number: &str) -> String {
    format!(
        "#!/bin/sh
# Script for ServerBox app v1.0.{build_number}
# DO NOT delete this file while app is running

export LANG=en_US.UTF-8

# If macSign & bsdSign are both empty, then it's linux
macSign=$(uname -a 2>&1 | grep \"Darwin\")
bsdSign=$(uname -a 2>&1 | grep \"BSD\")

# Link /bin/sh to busybox?
isBusybox=$(ls -l /bin/sh | grep \"busybox\")

userId=$(id -u)

exec 2>/dev/null

"
    )
}

fn build_unix_script(opts: &ScriptOptions) -> String {
    let mut out = unix_header(&opts.build_number);

    for func in ShellFunc::ALL {
        let body = unix_command(func, opts);
        // Every line of the body gets a tab prefix (including empty lines)
        let tabbed: String = body
            .split('\n')
            .map(|l| format!("\t{l}"))
            .collect::<Vec<_>>()
            .join("\n");
        let custom = unix_custom_cmds(func);
        // Trailing no-op: without it the function's exit status is whatever the
        // last probe returned, so a `grep` that matched nothing (`model name` is
        // absent from /proc/cpuinfo on arm64) makes a healthy run look failed.
        // Reaching the end is the signal callers actually want.
        out.push_str(&format!(
            "{}() {{\n{tabbed}\n{custom}\n\t:\n}}\n\n",
            func.name()
        ));
    }

    out.push_str("case $1 in\n");
    for func in ShellFunc::ALL {
        out.push_str(&format!(
            "  '-{}')\n    {}\n    ;;\n",
            func.flag(),
            func.name()
        ));
    }
    out.push_str("  *)\n    echo \"Invalid argument $1\"\n    ;;\nesac");
    out
}

/// Custom commands are only injected into the status function
fn unix_custom_cmds(func: ShellFunc) -> String {
    if func != ShellFunc::Status {
        return String::new();
    }
    // Read, not baked in. The directory's files sort by the order prefix in
    // their names, and the marker is that name — so a command's text never
    // touches this script and a broken one breaks only itself.
    //
    // `sh "$f"` rather than executing the file: no execute bit to set, and it
    // works on a `noexec` mount. Output goes through a size-limited file so a
    // child that survives its shell cannot keep the status pipe open.
    let file_blocks = CUSTOM_CMD_MAX_OUTPUT_BYTES.div_ceil(512);
    format!(
        "\nd=\"{CUSTOM_CMD_DIR_UNIX}\"\n\
         [ -d \"$d\" ] || d=\"$d.bak\"\n\
         for f in \"$d\"/*; do\n\
         \t[ -f \"$f\" ] || continue\n\
         \tn=${{f##*/}}\n\
         \to_prefix=${{n%%_*}}\n\
         \tencoded=${{n#*_}}\n\
         \t[ ${{#o_prefix}} -eq 5 ] || continue\n\
         \tcase \"$o_prefix\" in *[!0-9]*) continue;; esac\n\
         \tcase \"$encoded\" in ''|*[!A-Za-z0-9_=-]*) continue;; esac\n\
         \tprintf '%s\\n' \"{CUSTOM_CMD_SEPARATOR}.{ENCODED_NAME_PREFIX}${{n#*_}}\"\n\
         \tif command -v mktemp >/dev/null 2>&1; then\n\
         \t\to=$(mktemp \"${{TMPDIR:-/tmp}}/server_box_custom.XXXXXX\" 2>/dev/null) || continue\n\
         \telse\n\
         \t\to=\"${{TMPDIR:-/tmp}}/server_box_custom_$$\"\n\
         \t\t(umask 077; set -C; : > \"$o\") 2>/dev/null || continue\n\
         \tfi\n\
         \t(ulimit -f {file_blocks} 2>/dev/null || :; if command -v timeout >/dev/null 2>&1; then timeout 5 sh \"$f\"; else kill_tree() {{ for c in $(ps -eo pid=,ppid= 2>/dev/null | awk -v p=\"$1\" '$2 == p {{ print $1 }}'); do kill_tree \"$c\"; done; kill \"$1\" 2>/dev/null; }}; grouped=0; if command -v setsid >/dev/null 2>&1; then setsid sh \"$f\" & p=$!; grouped=1; else sh \"$f\" & p=$!; fi; (sleep 5; if [ \"$grouped\" -eq 1 ]; then kill -TERM -\"$p\" 2>/dev/null; else kill_tree \"$p\"; fi; sleep 1; if [ \"$grouped\" -eq 1 ]; then kill -KILL -\"$p\" 2>/dev/null; else kill_tree \"$p\"; fi) & w=$!; wait \"$p\" 2>/dev/null; kill \"$w\" 2>/dev/null; wait \"$w\" 2>/dev/null; fi) > \"$o\"\n\
         \tprintf '%s' '{CUSTOM_CMD_OUTPUT_PREFIX}'\n\
         \tif command -v head >/dev/null 2>&1; then head -c {CUSTOM_CMD_MAX_OUTPUT_BYTES} \"$o\" 2>/dev/null | base64 | tr -d '\\n'; else dd if=\"$o\" bs=1 count={CUSTOM_CMD_MAX_OUTPUT_BYTES} 2>/dev/null | base64 | tr -d '\\n'; fi\n\
         \trm -f \"$o\"\n\
         \tprintf '\\n'\n\
         done\n"
    )
}

/// A branch with no enabled commands left in it would make the generated
/// script a shell syntax error (`if ...; then\nelse`), which the user can
/// reach by disabling every command of one half of the manifest
fn or_noop(segments: String) -> String {
    if segments.is_empty() {
        ":".to_string()
    } else {
        segments
    }
}

fn unix_command(func: ShellFunc, opts: &ScriptOptions) -> String {
    match func {
        ShellFunc::Status | ShellFunc::StatusExt => {
            let extended = func == ShellFunc::StatusExt;
            let divider = |key: &str| format!("\necho {}\n\t", cmd_marker(key));
            let linux = or_noop(segment_list(commands::LINUX, "Linux", opts, extended, divider));
            let bsd = or_noop(segment_list(commands::BSD, "BSD", opts, extended, divider));
            format!(
                "if [ \"$macSign\" = \"\" ] && [ \"$bsdSign\" = \"\" ]; then\n\t{linux}\nelse\n\t{bsd}\nfi"
            )
        }
        ShellFunc::Process => "if [ \"$macSign\" = \"\" ] && [ \"$bsdSign\" = \"\" ]; then
\tif [ \"$isBusybox\" != \"\" ]; then
\t\tps w
\telse
\t\tprintf 'PID USER %%CPU %%MEM VSZ RSS TTY STAT TIME READ_BYTES WRITE_BYTES COMMAND\\n'
\t\tps -axo pid=,user=,%cpu=,%mem=,vsz=,rss=,tty=,stat=,time=,args= | while IFS= read -r line; do
\t\t\tset -f
\t\t\tset -- $line
\t\t\tset +f
\t\t\tpid=$1; user=$2; cpu=$3; mem=$4; vsz=$5; rss=$6; tty=$7; stat=$8; time=$9
\t\t\tshift 9
\t\t\tcmd=$*
\t\t\tread_bytes='-'
\t\t\twrite_bytes='-'
\t\t\tif [ -r \"/proc/$pid/io\" ]; then
\t\t\t\tread_bytes=$(awk '/^read_bytes:/ {print $2}' \"/proc/$pid/io\")
\t\t\t\twrite_bytes=$(awk '/^write_bytes:/ {print $2}' \"/proc/$pid/io\")
\t\t\tfi
\t\t\tprintf '%s %s %s %s %s %s %s %s %s %s %s %s\\n' \"$pid\" \"$user\" \"$cpu\" \"$mem\" \"$vsz\" \"$rss\" \"$tty\" \"$stat\" \"$time\" \"$read_bytes\" \"$write_bytes\" \"$cmd\"
\t\tdone
\tfi
else
\tps -ax
fi"
        .to_string(),
        ShellFunc::Shutdown => {
            "if [ \"$userId\" = \"0\" ]; then\n\tshutdown -h now\nelse\n\tsudo -S shutdown -h now\nfi"
                .to_string()
        }
        ShellFunc::Reboot => {
            "if [ \"$userId\" = \"0\" ]; then\n\treboot\nelse\n\tsudo -S reboot\nfi".to_string()
        }
        ShellFunc::Suspend => {
            "if [ \"$userId\" = \"0\" ]; then\n\tsystemctl suspend\nelse\n\tsudo -S systemctl suspend\nfi"
                .to_string()
        }
    }
}

// ---------- internal: Windows ----------

fn windows_header(build_number: &str) -> String {
    format!(
        "# PowerShell script for ServerBox app v1.0.{build_number}
# DO NOT delete this file while app is running

$ErrorActionPreference = \"SilentlyContinue\"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

"
    )
}

fn build_windows_script(opts: &ScriptOptions) -> String {
    let mut out = windows_header(&opts.build_number);

    for func in ShellFunc::ALL {
        let body = windows_command(func, opts);
        // Non-empty lines get a 4-space prefix; the template adds 4 more to the
        // first line (Dart artifact, kept for byte parity)
        let indented: String = body
            .split('\n')
            .map(|l| {
                if l.is_empty() {
                    String::new()
                } else {
                    format!("    {l}")
                }
            })
            .collect::<Vec<_>>()
            .join("\n");
        let custom = windows_custom_cmds(func);
        out.push_str(&format!(
            "function {} {{\n    {indented}{custom}\n}}\n\n",
            func.name()
        ));
    }

    out.push_str("switch ($args[0]) {\n");
    for func in ShellFunc::ALL {
        out.push_str(&format!("    \"-{}\" {{ {} }}\n", func.flag(), func.name()));
    }
    out.push_str("    default { Write-Host \"Invalid argument $($args[0])\" }\n}\n");
    out
}

fn windows_custom_cmds(func: ShellFunc) -> String {
    if func != ShellFunc::Status {
        return String::new();
    }
    // The same shape as the Unix half: sorted by file name, the marker taken
    // from that name, and the file run rather than its text spliced in here.
    //
    // `BaseName`, not `Name`: these files carry a `.ps1` extension because
    // `&` will not run an extensionless one, and the extension is not part of
    // the encoded name — leaving it on produced a marker that decodes to
    // nothing, so the command's output was swallowed by the section above it.
    format!(
        "\n    $d = {CUSTOM_CMD_DIR_WINDOWS}\n\
         \x20   if (-not (Test-Path $d) -and (Test-Path \"$d.bak\")) {{ $d = \"$d.bak\" }}\n\
         \x20   if (Test-Path $d) {{\n\
         \x20     Get-ChildItem -File $d | Sort-Object Name | ForEach-Object {{\n\
         \x20       if ($_.Name -notmatch '^[0-9]{{5}}_[A-Za-z0-9_=-]+\\.ps1$') {{ return }}\n\
         \x20       Write-Host \"{CUSTOM_CMD_SEPARATOR}.{ENCODED_NAME_PREFIX}$($_.BaseName -replace '^[0-9]+_','')\"\n\
         \x20       $o = Join-Path ([IO.Path]::GetTempPath()) (\"server_box_custom_{{0}}.out\" -f $PID)\n\
         \x20       $e = \"$o.err\"\n\
         \x20       Remove-Item -Force $o,$e -ErrorAction SilentlyContinue\n\
         \x20       $q = '\"' + $_.FullName + '\"'\n\
         \x20       $p = Start-Process powershell -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$q) -RedirectStandardOutput $o -RedirectStandardError $e -PassThru\n\
         \x20       $deadline = [DateTime]::UtcNow.AddSeconds(5)\n\
         \x20       while (-not $p.HasExited -and [DateTime]::UtcNow -lt $deadline -and (-not (Test-Path $o) -or (Get-Item $o).Length -le {CUSTOM_CMD_MAX_OUTPUT_BYTES})) {{ Start-Sleep -Milliseconds 50 }}\n\
         \x20       if (-not $p.HasExited) {{ taskkill /PID $p.Id /T /F | Out-Null; $p.WaitForExit() }}\n\
         \x20       [Console]::Out.Write('{CUSTOM_CMD_OUTPUT_PREFIX}')\n\
         \x20       if (Test-Path $o) {{\n\
         \x20         $s = [IO.File]::OpenRead($o)\n\
         \x20         try {{ $b = New-Object byte[] {CUSTOM_CMD_MAX_OUTPUT_BYTES}; $c = $s.Read($b, 0, $b.Length); [Console]::Out.Write([Convert]::ToBase64String($b, 0, $c)) }} finally {{ $s.Dispose() }}\n\
         \x20       }}\n\
         \x20       Remove-Item -Force $o,$e -ErrorAction SilentlyContinue\n\
         \x20       Write-Host ''\n\
         \x20     }}\n\
         \x20   }}\n"
    )
}

fn windows_command(func: ShellFunc, opts: &ScriptOptions) -> String {
    match func {
        ShellFunc::Status | ShellFunc::StatusExt => segment_list(
            commands::WINDOWS,
            "Windows",
            opts,
            func == ShellFunc::StatusExt,
            |key| format!("\n    Write-Host \"{}\"\n    ", cmd_marker(key)),
        ),
        ShellFunc::Process => "Get-Process | Select-Object ProcessName, Id, CPU, WorkingSet,
    @{Name='IOReadBytes';Expression={$_.IOReadBytes}},
    @{Name='IOWriteBytes';Expression={$_.IOWriteBytes}} | ConvertTo-Json"
            .to_string(),
        ShellFunc::Shutdown => "Stop-Computer -Force".to_string(),
        ShellFunc::Reboot => "Restart-Computer -Force".to_string(),
        ShellFunc::Suspend => {
            "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Application]::SetSuspendState('Suspend', $false, $false)"
                .to_string()
        }
    }
}
