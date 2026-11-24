//! Linux backend: reads the same procfs/sysfs paths the shared script's
//! `cat` commands read (see `sbm_parser::commands::LINUX`), directly via
//! `std::fs::read_to_string`, and feeds the output into
//! `sbm_parser::linux::parse_*`/`sbm_parser::common::parse_*` unmodified —
//! those functions are pure text-in/struct-out and don't care whether the
//! text came from a shell pipeline or a direct file read. Zero extra
//! dependencies.
//!
//! Two fields still shell out to a single, targeted command instead of
//! reading a file: `uptime` (no simple procfs equivalent that already
//! matches `common::parse_uptime`'s expected shape — `/proc/uptime` is a raw
//! seconds count, not the `uptime` command's structured text) and `disks`
//! (filesystem usage isn't in one clean procfs file — `df -kT` each sample,
//! merged with the `lsblk` tree `block_devices` reads on the slower cycle, as
//! the app's `commands::DISK` output is).
//! These are still a big win over the old approach: one direct process
//! spawn per field instead of building/writing/executing a whole generated
//! multi-command script and splitting its output by `SrvBoxSep` markers.
//!
//! `batteries`/`sensors`/`nvidia`/`amd`/`disk_smart` are intentionally left
//! empty here — those stay on the shared script path (see monitor's
//! extended-cycle collection), which is the only source for them.

use sbm_parser::types::{BlockDevice, Disk};
use sbm_parser::{ServerStatus, common, linux};
use std::fs;
use std::fs::OpenOptions;
use std::os::unix::fs::OpenOptionsExt;
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

/// `df` can block on an unavailable network filesystem. Native sampling runs
/// on the monitor loop, so an optional command may never hold it indefinitely.
const COMMAND_TIMEOUT: Duration = Duration::from_secs(10);
const MAX_COMMAND_OUTPUT_BYTES: u64 = 1024 * 1024;
const MAX_REAPING_CHILDREN: usize = 4;

/// Children that survived a kill attempt. A process in uninterruptible I/O can
/// outlive SIGKILL, so waiting for it would stall the monitor loop.
#[derive(Default)]
struct ChildReaper {
    children: Vec<Child>,
    reserved_slots: usize,
}

impl ChildReaper {
    fn reap(&mut self) {
        self.children.retain_mut(|child| match child.try_wait() {
            Ok(Some(_)) => false,
            Ok(None) | Err(_) => true,
        });
    }

    /// Reserve capacity before spawning, so a killed child can always be
    /// retained without an unbounded collection or detached waiting thread.
    fn reserve(&mut self) -> bool {
        self.reap();
        if self.children.len() + self.reserved_slots >= MAX_REAPING_CHILDREN {
            return false;
        }
        self.reserved_slots += 1;
        true
    }

    fn release(&mut self) {
        self.reserved_slots = self.reserved_slots.saturating_sub(1);
    }

    fn retain(&mut self, child: Child) {
        debug_assert!(self.reserved_slots > 0);
        self.reserved_slots = self.reserved_slots.saturating_sub(1);
        self.children.push(child);
    }
}

fn child_reaper() -> &'static Mutex<ChildReaper> {
    static REAPER: OnceLock<Mutex<ChildReaper>> = OnceLock::new();
    REAPER.get_or_init(|| Mutex::new(ChildReaper::default()))
}

fn with_child_reaper<T>(f: impl FnOnce(&mut ChildReaper) -> T) -> T {
    let mut reaper = child_reaper()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    f(&mut reaper)
}

fn read(path: &str) -> String {
    fs::read_to_string(path).unwrap_or_default()
}

/// Run one targeted command and return stdout, empty on any failure —
/// matching the shared script's tolerance (a failed segment parses to empty)
fn run(cmd: &str, args: &[&str]) -> String {
    run_command(command(cmd, args))
}

/// [`run`], keeping stdout whatever the exit status — for a command that
/// reports a partial failure in its status and still prints the rest: GNU
/// `df` exits 1 when any one mount is unreadable. The timeout and output limit
/// hold all the same.
fn run_lenient(cmd: &str, args: &[&str]) -> String {
    run_command_with_timeout(command(cmd, args), COMMAND_TIMEOUT, true)
}

const NATIVE_LOCALE: &str = "C.UTF-8";

/// `LC_ALL` is fixed because the parsers read English output (`df`'s header,
/// `uptime`'s load average) and a service inherits the machine's language.
/// `C.UTF-8` rather than `C`, so a mount path outside ASCII is printed as is;
/// where it is not installed, the C library falls back to `C`.
fn command(cmd: &str, args: &[&str]) -> Command {
    let mut command = Command::new(cmd);
    command
        .args(args)
        .env("LC_ALL", NATIVE_LOCALE)
        .stdin(Stdio::null())
        .stderr(Stdio::null());
    command
}

fn run_command(command: Command) -> String {
    run_command_with_timeout(command, COMMAND_TIMEOUT, false)
}

fn run_command_with_timeout(
    mut command: Command,
    command_timeout: Duration,
    keep_failed_output: bool,
) -> String {
    if !with_child_reaper(ChildReaper::reserve) {
        return String::new();
    }
    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        // Keep descendants in one group so a timed-out tool cannot continue
        // behind its direct process after the monitor has moved on.
        command.process_group(0);
        // Limit writes in the child rather than reading an unbounded pipe into
        // the monitor process. The parent below terminates the whole group as
        // soon as the file reaches that hard limit.
        // SAFETY: `limit_output_size` only invokes async-signal-safe `setrlimit`.
        unsafe { command.pre_exec(limit_output_size) };
    }
    let Some((output, file)) = output_file() else {
        with_child_reaper(ChildReaper::release);
        return String::new();
    };
    command.stdout(Stdio::from(output));
    let Ok(mut child) = command.spawn() else {
        with_child_reaper(ChildReaper::release);
        let _ = fs::remove_file(file);
        return String::new();
    };
    let deadline = Instant::now() + command_timeout;
    loop {
        match child.try_wait() {
            Ok(Some(status)) => {
                with_child_reaper(ChildReaper::release);
                let stdout = fs::read(&file).unwrap_or_default();
                let _ = fs::remove_file(file);
                return if status.success() || keep_failed_output {
                    String::from_utf8_lossy(&stdout).into_owned()
                } else {
                    String::new()
                };
            }
            Ok(None)
                if fs::metadata(&file)
                    .is_ok_and(|metadata| metadata.len() >= MAX_COMMAND_OUTPUT_BYTES) =>
            {
                terminate(&mut child);
                with_child_reaper(|reaper| reaper.retain(child));
                let _ = fs::remove_file(file);
                return String::new();
            }
            Ok(None) if Instant::now() < deadline => std::thread::sleep(Duration::from_millis(10)),
            Ok(None) | Err(_) => {
                terminate(&mut child);
                with_child_reaper(|reaper| reaper.retain(child));
                let _ = fs::remove_file(file);
                return String::new();
            }
        }
    }
}

fn limit_output_size() -> std::io::Result<()> {
    let limit = libc::rlimit {
        rlim_cur: MAX_COMMAND_OUTPUT_BYTES as libc::rlim_t,
        rlim_max: MAX_COMMAND_OUTPUT_BYTES as libc::rlim_t,
    };
    // This runs only in the child after fork and before exec, so lowering its
    // file-size limit cannot affect the monitor process.
    // SAFETY: `limit` is a valid initialized `libc::rlimit` struct; `setrlimit` is
    // async-signal-safe and runs only in the forked child before `exec`.
    if unsafe { libc::setrlimit(libc::RLIMIT_FSIZE, &limit) } == 0 {
        Ok(())
    } else {
        Err(std::io::Error::last_os_error())
    }
}

/// File-backed output means a short-lived shell cannot leave this synchronous
/// sampler blocked on an inherited stdout pipe held by one of its descendants.
fn output_file() -> Option<(std::fs::File, PathBuf)> {
    let base = std::env::temp_dir().join(format!("sbm-native-{}", std::process::id()));
    for attempt in 0..16 {
        let path = base.with_extension(format!(
            "{}-{attempt}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .ok()?
                .as_nanos(),
        ));
        if let Ok(file) = OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(&path)
        {
            return Some((file, path));
        }
    }
    None
}

fn terminate(child: &mut std::process::Child) {
    #[cfg(unix)]
    // SAFETY: sending SIGKILL to the negative PID targets this child's process group.
    if unsafe { kill_process_group(-(child.id() as i32), 9) } == 0 {
        return;
    }
    let _ = child.kill();
}

#[cfg(unix)]
unsafe extern "C" {
    #[link_name = "kill"]
    fn kill_process_group(pid: i32, signal: i32) -> i32;
}

/// What the shared script's `sys` command prints — see `commands::LINUX`.
///
/// `/etc/os-release` then `/usr/lib/os-release`, in that order because that is
/// the precedence os-release specifies and `common::os_release_value` resolves
/// a duplicated key by taking the first. The `/etc/*-release` glob is the same
/// fallback the script has, for a system old enough to have no os-release.
///
/// Not filtered to one key: `parse_sys_version`, `parse_os_id` and
/// `parse_os_id_like` each pick their own line out of this block.
///
/// The glob's output *is* filtered, to `PRETTY_NAME` alone, because the script
/// pipes it through `grep ^PRETTY_NAME` and the two have to agree. Without
/// that, a host with no os-release but an `/etc/<vendor>-release` carrying an
/// `ID=` line reported a distribution here that the SSH path could not see —
/// the same machine identified two ways depending on which was asked.
fn os_release_block() -> String {
    let mut all = String::new();
    for path in ["/etc/os-release", "/usr/lib/os-release"] {
        for line in read(path).lines() {
            if line.starts_with("ID=")
                || line.starts_with("ID_LIKE=")
                || line.starts_with("PRETTY_NAME=")
            {
                all.push_str(line);
                all.push('\n');
            }
        }
    }
    // On what the filter kept, not on whether the files existed. The script is
    // `grep … || cat /etc/*-release | grep ^PRETTY_NAME`, so it falls back
    // whenever the first grep printed nothing — including for an appliance
    // whose `/etc/os-release` exists and holds none of these three keys, where
    // stopping at "the file was there" reported no system at all.
    if !all.is_empty() {
        return all;
    }

    let Ok(entries) = fs::read_dir("/etc") else {
        return all;
    };
    for entry in entries.flatten() {
        let name = entry.file_name();
        if !name.to_string_lossy().ends_with("-release") {
            continue;
        }
        for line in read(&entry.path().to_string_lossy()).lines() {
            if line.starts_with("PRETTY_NAME") {
                all.push_str(line);
                all.push('\n');
            }
        }
    }
    all
}

/// `/sys/class/thermal/thermal_zone*/{type,temp}` then
/// `/sys/class/hwmon/hwmon*/{name,temp1_input}`, each sorted by directory
/// name (matches shell glob order). The hwmon half is where a CPU's own
/// sensor lives on AMD (k10temp) and some Intel (coretemp) — many of those
/// machines expose a static `acpitz` zone and nothing else (#1957).
/// Returns line-parallel (types, values) blocks as `linux::parse_temps`
/// expects — a device without both of its readings is skipped whole, so
/// neither stream gets a stray line.
fn thermal_zones() -> (String, String) {
    thermal_zones_under("/sys/class/thermal", "/sys/class/hwmon")
}

/// [`thermal_zones`] reading under [thermal] and [hwmon] instead, so a test
/// can build them.
fn thermal_zones_under(thermal: &str, hwmon: &str) -> (String, String) {
    let mut pairs = Vec::new();
    for zone in sorted_dirs(thermal, "thermal_zone") {
        let ty = read(&zone.join("type").to_string_lossy()).trim().to_string();
        let temp = read(&zone.join("temp").to_string_lossy()).trim().to_string();
        if !ty.is_empty() && !temp.is_empty() {
            pairs.push((ty, temp));
        }
    }
    for hwmon in sorted_dirs(hwmon, "hwmon") {
        let name = read(&hwmon.join("name").to_string_lossy()).trim().to_string();
        let temp = read(&hwmon.join("temp1_input").to_string_lossy()).trim().to_string();
        if !name.is_empty() && !temp.is_empty() {
            pairs.push((name, temp));
        }
    }

    let mut types = String::new();
    let mut values = String::new();
    for (ty, temp) in pairs {
        types.push_str(&ty);
        types.push('\n');
        values.push_str(&temp);
        values.push('\n');
    }
    (types, values)
}

/// [root]'s directories named [prefix]*, sorted by name, as a glob expands.
fn sorted_dirs(root: &str, prefix: &str) -> Vec<PathBuf> {
    let mut dirs: Vec<PathBuf> = fs::read_dir(root)
        .into_iter()
        .flatten()
        .flatten()
        .map(|e| e.path())
        .filter(|p| {
            p.file_name()
                .and_then(|n| n.to_str())
                .is_some_and(|n| n.starts_with(prefix))
        })
        .collect();
    dirs.sort();
    dirs
}

/// `MemTotal` from `/proc/meminfo`, in bytes (the file reports kibibytes).
///
/// Parsed here rather than going through `sbm_parser::linux::parse_mem`
/// because callers of `sbm_native::total_memory` want this before any
/// sampling state exists, and the one field is trivial to read directly.
pub fn total_memory() -> Option<u64> {
    read("/proc/meminfo")
        .lines()
        .find_map(|line| line.strip_prefix("MemTotal:"))
        .and_then(|rest| rest.split_whitespace().next()?.parse::<u64>().ok())
        .map(|kib| kib * 1024)
}

/// Linux under WSL2.
pub fn wsl() -> bool {
    read("/proc/sys/kernel/osrelease").to_ascii_lowercase().contains("microsoft")
}

/// Processes holding WSL2's GPU device (`/dev/dxg`), which every GPU of the
/// host is reached through: what `nvidia-smi` cannot list there. Those this
/// account may look into (its own, all as root); no memory figure.
pub fn dxg_processes() -> Vec<sbm_parser::types::GpuMemProcess> {
    let Ok(procs) = std::fs::read_dir("/proc") else { return Vec::new() };
    let mut out = Vec::new();
    for entry in procs.flatten() {
        let Some(pid) = entry.file_name().to_str().and_then(|n| n.parse::<i64>().ok()) else { continue };
        let Ok(fds) = std::fs::read_dir(entry.path().join("fd")) else { continue };
        let holds = fds.flatten().any(|fd| std::fs::read_link(fd.path()).is_ok_and(|t| t == std::path::Path::new("/dev/dxg")));
        if holds {
            let name = read(&format!("/proc/{pid}/comm")).trim().to_string();
            out.push(sbm_parser::types::GpuMemProcess { pid, name, memory: 0 });
        }
    }
    out
}

/// `lsblk`'s JSON, as `commands::DISK` runs it; empty where there is none.
pub fn block_devices() -> String {
    run("lsblk", &linux::LSBLK_ARGS)
}

/// `df -kT`, or `df -k` where `-T` is not understood (busybox, which prints
/// its usage to stderr and nothing to stdout): told apart by the output rather
/// than the status, and both kept whatever the status — GNU df exits 1 when
/// any one mount is unreadable and prints the rest anyway.
fn df() -> String {
    let typed = run_lenient("df", &["-kT"]);
    if !typed.trim().is_empty() {
        typed
    } else {
        run_lenient("df", &["-k"])
    }
}

/// `block_devices` is [`block_devices`]' last output, merged with a fresh
/// [`df`] the way `commands::DISK`'s output is — see `linux::merge_disks`;
/// `device_tree` is the same output parsed into the device tree.
pub fn sample(block_devices: &str, device_tree: &[BlockDevice]) -> ServerStatus {
    let mem_raw = read("/proc/meminfo");
    let (temp_types, temp_values) = thermal_zones();
    let disks: Vec<Disk> = linux::parse_disk(&format!(
        "{block_devices}\n{}\n{}",
        linux::DISK_DF_MARKER,
        df()
    ));
    // Read once: three fields come out of the same block.
    let os_release = os_release_block();

    ServerStatus {
        cpu: linux::parse_cpu(&read("/proc/stat")),
        cpu_brand: linux::parse_cpu_brand(&read("/proc/cpuinfo")),
        mem: linux::parse_mem(&mem_raw),
        swap: linux::parse_swap(&mem_raw),
        swap_areas: linux::parse_proc_swaps(&read("/proc/swaps")),
        disks,
        block_devices: device_tree.to_vec(),
        net: linux::parse_net(&read("/proc/net/dev")),
        temps: linux::parse_temps(&temp_types, &temp_values, 1000.0),
        conn: linux::parse_conn(&read("/proc/net/snmp")),
        uptime: common::parse_uptime(&run("uptime", &[])),
        sys: common::parse_sys_version(&os_release),
        os_id: common::parse_os_id(&os_release),
        os_id_like: common::parse_os_id_like(&os_release),
        // As the status script: the file, else the kernel's name, which is
        // what OpenWrt and others without the file have.
        host: common::parse_hostname(&read("/etc/hostname"))
            .or_else(|| common::parse_hostname(&read("/proc/sys/kernel/hostname"))),
        diskio: linux::parse_diskio(&read("/proc/diskstats")),
        ..ServerStatus::default()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A throwaway directory tree with fake sysfs entries, removed on drop.
    struct FakeSys(PathBuf);

    impl FakeSys {
        fn new(tag: &str) -> Self {
            let root = std::env::temp_dir().join(format!(
                "sbm_native_{}_{}_{tag}",
                std::process::id(),
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            ));
            Self(root.clone())
        }

        /// A `name/type/temp` device under [family].
        fn device(&self, family: &str, dir: &str, files: &[(&str, &str)]) -> &Self {
            let d = self.0.join(family).join(dir);
            std::fs::create_dir_all(&d).unwrap();
            for (file, content) in files {
                std::fs::write(d.join(file), content).unwrap();
            }
            self
        }
    }

    impl Drop for FakeSys {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.0);
        }
    }

    // Zones come out whole; a device of either kind missing one of its two
    // readings is skipped — what `parse_temps` needs to stay line-aligned
    // (#1957).
    #[test]
    fn zones_and_hwmons_come_out_line_aligned() {
        let sys = FakeSys::new("temps");
        sys.device(
            "thermal",
            "thermal_zone1",
            &[("type", "acpitz\n"), ("temp", "20000\n")],
        )
        .device(
            "thermal",
            "thermal_zone0",
            &[("type", "x86_pkg_temp\n"), ("temp", "44000\n")],
        )
        .device("thermal", "thermal_zone2", &[("type", "nvme\n")]) // no temp
        .device("hwmon", "hwmon9", &[("name", "k10temp\n"), ("temp1_input", "66125\n")])
        .device("hwmon", "hwmon2", &[("name", "nvme\n")]); // no temp
        let (types, values) =
            thermal_zones_under(&sys.0.join("thermal").to_string_lossy(), &sys.0.join("hwmon").to_string_lossy());
        // Sorted by directory name, zones before hwmons.
        assert_eq!(types, "x86_pkg_temp\nacpitz\nk10temp\n");
        assert_eq!(values, "44000\n20000\n66125\n");
    }

    // Reads the real host's procfs — can't assert exact values (that's
    // sbm_parser's fixture-based job), only that the native path actually
    // produces plausible data end to end on a real Linux machine.
    #[test]
    fn sample_produces_plausible_data() {
        let status = sample(&block_devices(), &[]);
        assert!(
            !status.cpu.is_empty(),
            "expected at least a 'cpu' summary row"
        );
        assert!(status.mem.is_some());
        assert!(status.host.is_some());
        assert!(
            !status.net.is_empty(),
            "expected at least one network interface"
        );
    }

    /// `lsblk`'s tree and a fresh `df -kT`, merged (#1669): the root
    /// filesystem is there, with its type — from either source — and numbers.
    #[test]
    fn disks_merge_the_device_tree_with_df() {
        fn find<'a>(disks: &'a [Disk], mount: &str) -> Option<&'a Disk> {
            disks
                .iter()
                .find_map(|d| (d.mount == mount).then_some(d).or_else(|| find(&d.children, mount)))
        }
        let status = sample(&block_devices(), &[]);
        let root = find(&status.disks, "/").expect("a root filesystem");
        assert!(root.fs_type.is_some(), "{root:?}");
        assert!(root.size > 0, "{root:?}");
    }

    /// #1747: under the service's `LANG=zh_CN.UTF-8`, `df` printed a
    /// translated header and the disk list came back empty.
    #[test]
    fn a_native_command_runs_in_a_fixed_locale() {
        let command = command("df", &["-kT"]);
        let locale = command
            .get_envs()
            .find(|(key, _)| *key == "LC_ALL")
            .and_then(|(_, value)| value);
        assert_eq!(locale, Some(std::ffi::OsStr::new(NATIVE_LOCALE)));
    }

    #[test]
    fn a_stuck_native_command_is_terminated() {
        let mut command = Command::new("sh");
        command.args(["-c", "sleep 2"]);
        let started = Instant::now();
        assert!(run_command_with_timeout(command, Duration::from_millis(100), true).is_empty());
        assert!(started.elapsed() < Duration::from_secs(1));
    }

    #[test]
    fn over_limit_native_output_terminates_the_command_group() {
        let mut command = Command::new("sh");
        let script = format!(
            "head -c {} /dev/zero; sleep 2",
            MAX_COMMAND_OUTPUT_BYTES + 1
        );
        command.args(["-c", &script]);
        let started = Instant::now();

        assert!(run_command_with_timeout(command, Duration::from_secs(2), true).is_empty());
        assert!(started.elapsed() < Duration::from_secs(1));
    }

    /// GNU df prints every mount it could read and exits 1 for the one it
    /// could not: that output is kept, where a strict command's is not.
    #[test]
    fn a_partial_failure_keeps_its_output_only_when_asked() {
        let failing = || {
            let mut command = Command::new("sh");
            command.args(["-c", "echo kept; exit 1"]);
            command
        };
        assert_eq!(run_command_with_timeout(failing(), COMMAND_TIMEOUT, true), "kept\n");
        assert!(run_command_with_timeout(failing(), COMMAND_TIMEOUT, false).is_empty());
    }

    #[test]
    fn child_reaper_limits_pending_children() {
        let mut reaper = ChildReaper {
            reserved_slots: MAX_REAPING_CHILDREN,
            ..Default::default()
        };
        assert!(!reaper.reserve());

        reaper.release();
        assert!(reaper.reserve());
    }

    #[test]
    fn output_file_is_owner_only() {
        use std::os::unix::fs::PermissionsExt;

        let (file, path) = output_file().expect("temporary output file");
        drop(file);
        let mode = fs::metadata(&path)
            .expect("output file metadata")
            .permissions()
            .mode();
        let _ = fs::remove_file(path);
        assert_eq!(mode & 0o077, 0);
    }
}
