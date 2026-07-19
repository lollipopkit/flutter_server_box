//! Script generation shared by the app (via FFI) and the monitor.
//!
//! Literal port of the app's Dart script layer (`lib/data/model/app/scripts/`):
//! every template artifact (blank lines, tab prefixes, trailing trims) is
//! preserved so the output is byte-identical to the historical Dart builders.
//! The app uploads the generated script over SSH and calls it with a flag; the
//! monitor executes the same script locally with a core-only command subset.

use crate::commands::{self, CommandSpec, SEPARATOR};
use crate::SystemType;
use std::collections::HashMap;

/// Custom-command segment separator (`SrvBoxCusCmdSep.<name>`)
pub const CUSTOM_CMD_SEPARATOR: &str = "SrvBoxCusCmdSep";

/// Shell functions exposed by the generated script. Names and flags are wire
/// format: `sh script.sh -s` dispatches to `SbStatus`, etc.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ShellFunc {
    Status,
    Process,
    Shutdown,
    Reboot,
    Suspend,
}

impl ShellFunc {
    pub const ALL: [ShellFunc; 5] = [
        ShellFunc::Status,
        ShellFunc::Process,
        ShellFunc::Shutdown,
        ShellFunc::Reboot,
        ShellFunc::Suspend,
    ];

    pub fn name(self) -> &'static str {
        match self {
            ShellFunc::Status => "SbStatus",
            ShellFunc::Process => "SbProcess",
            ShellFunc::Shutdown => "SbShutdown",
            ShellFunc::Reboot => "SbReboot",
            ShellFunc::Suspend => "SbSuspend",
        }
    }

    pub fn flag(self) -> &'static str {
        match self {
            ShellFunc::Status => "s",
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
    /// Custom status commands in insertion order (order affects script bytes).
    /// Names and values are injected verbatim.
    // TODO: escaping hardening after migration (values are injected unquoted,
    // matching the historical Dart behavior)
    pub custom_cmds: Vec<(String, String)>,
    /// Disabled command keys in the app's stored displayName format
    /// ("Linux.net", "BSD.mem", "Windows.cpu"); compared case-insensitively
    pub disabled: Vec<String>,
    /// Monitor mode: only `core` commands in the status function
    pub core_only: bool,
    /// App build number embedded in the header comment ("v1.0.<build>")
    pub build_number: String,
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

/// Command that installs the script on the target (script content is piped via
/// stdin). The Windows variant is base64-encoded: the raw PowerShell syntax
/// would fail on hosts whose OpenSSH default shell is cmd.exe
pub fn install_command(system: SystemType, script_dir: &str, script_path: &str) -> String {
    match system {
        SystemType::Windows => encoded_powershell_command(&format!(
            "New-Item -ItemType Directory -Force -Path '{script_dir}' | Out-Null; \
$content = [System.Console]::In.ReadToEnd(); \
Set-Content -Path '{script_path}' -Value $content -Encoding UTF8"
        )),
        _ => format!("mkdir -p {script_dir}\ncat > {script_path}\nchmod 755 {script_path}\n"),
    }
}

/// Command that runs one shell function of an installed script
pub fn exec_command(system: SystemType, script_path: &str, func: ShellFunc) -> String {
    match system {
        SystemType::Windows => format!(
            "powershell -ExecutionPolicy Bypass -File \"{script_path}\" -{}",
            func.flag()
        ),
        _ => format!("sh {script_path} -{}", func.flag()),
    }
}

/// Split script output into a command key → output map
/// (port of Dart `ScriptConstants.parseScriptOutput`).
///
/// Deliberate deviation from Dart: a trailing `\r` is stripped from each line
/// before matching, so CRLF output (monitor running PowerShell locally) parses
/// identically to LF output. Strictly more tolerant than the Dart original.
pub fn parse_script_output(raw: &str) -> HashMap<String, String> {
    let mut result = HashMap::new();
    if raw.is_empty() {
        return result;
    }

    let sep_prefix = format!("{SEPARATOR}.");
    let custom_prefix = format!("{CUSTOM_CMD_SEPARATOR}.");
    let mut current: Option<String> = None;
    let mut buf = String::new();

    let flush = |current: &mut Option<String>, buf: &mut String, result: &mut HashMap<String, String>| {
        if let Some(key) = current.take() {
            result.insert(key, buf.trim().to_string());
            buf.clear();
        }
    };

    for line in raw.split('\n') {
        let line = line.strip_suffix('\r').unwrap_or(line);
        if let Some(key) = line.strip_prefix(&sep_prefix) {
            flush(&mut current, &mut buf, &mut result);
            current = Some(key.to_string());
        } else if let Some(key) = line.strip_prefix(&custom_prefix) {
            flush(&mut current, &mut buf, &mut result);
            current = Some(key.to_string());
        } else if current.is_some() {
            buf.push_str(line);
            buf.push('\n');
        }
    }
    flush(&mut current, &mut buf, &mut result);

    result
}

// ---------- internal: shared filtering ----------

/// Whether a command is included in the status function.
/// `scope` is the displayName prefix used by the app ("Linux"/"BSD"/"Windows").
fn enabled(spec: &CommandSpec, scope: &str, opts: &ScriptOptions) -> bool {
    if opts.core_only && !spec.core {
        return false;
    }
    let display_name = format!("{scope}.{}", spec.key);
    !opts
        .disabled
        .iter()
        .any(|d| d.eq_ignore_ascii_case(&display_name))
}

/// `divider + cmd` segments joined and right-trimmed (Dart `_get*StatusCommand`)
fn segment_list(
    specs: &[CommandSpec],
    scope: &str,
    opts: &ScriptOptions,
    divider: impl Fn(&str) -> String,
) -> String {
    let joined: String = specs
        .iter()
        .filter(|s| enabled(s, scope, opts))
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
        let custom = unix_custom_cmds(func, opts);
        out.push_str(&format!("{}() {{\n{tabbed}\n{custom}\n}}\n\n", func.name()));
    }

    out.push_str("case $1 in\n");
    for func in ShellFunc::ALL {
        out.push_str(&format!("  '-{}')\n    {}\n    ;;\n", func.flag(), func.name()));
    }
    out.push_str("  *)\n    echo \"Invalid argument $1\"\n    ;;\nesac");
    out
}

/// Custom commands are only injected into the status function
fn unix_custom_cmds(func: ShellFunc, opts: &ScriptOptions) -> String {
    if func != ShellFunc::Status || opts.custom_cmds.is_empty() {
        return String::new();
    }
    let mut s = String::from("\n");
    for (name, cmd) in &opts.custom_cmds {
        s.push_str(&format!("echo \"{CUSTOM_CMD_SEPARATOR}.{name}\"\n{cmd}\n"));
    }
    s
}

fn unix_command(func: ShellFunc, opts: &ScriptOptions) -> String {
    match func {
        ShellFunc::Status => {
            let linux = segment_list(commands::LINUX, "Linux", opts, |key| {
                format!("\necho {SEPARATOR}.{key}\n\t")
            });
            let bsd = segment_list(commands::BSD, "BSD", opts, |key| {
                format!("\necho {SEPARATOR}.{key}\n\t")
            });
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
            .map(|l| if l.is_empty() { String::new() } else { format!("    {l}") })
            .collect::<Vec<_>>()
            .join("\n");
        let custom = windows_custom_cmds(func, opts);
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

fn windows_custom_cmds(func: ShellFunc, opts: &ScriptOptions) -> String {
    if func != ShellFunc::Status || opts.custom_cmds.is_empty() {
        return String::new();
    }
    let mut s = String::from("\n");
    for (name, cmd) in &opts.custom_cmds {
        s.push_str(&format!(
            "    Write-Host \"{CUSTOM_CMD_SEPARATOR}.{name}\"\n    {cmd}\n"
        ));
    }
    s
}

fn windows_command(func: ShellFunc, opts: &ScriptOptions) -> String {
    match func {
        ShellFunc::Status => segment_list(commands::WINDOWS, "Windows", opts, |key| {
            format!("\n    Write-Host \"{SEPARATOR}.{key}\"\n    ")
        }),
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
