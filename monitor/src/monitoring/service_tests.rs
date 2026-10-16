// The sampling service's tests, beside it rather than in it.

#[test]
fn a_gpus_processes_reach_the_metrics() {
    use sbm_parser::types::{GpuItem, GpuMem, GpuMemProcess};
    let process = GpuMemProcess { pid: 42, name: "/python3.12".to_string(), memory: 0 };
    let metrics = super::GpuMetrics::from(GpuItem {
        id: "nvidia:0".to_string(),
        vendor: "nvidia".to_string(),
        name: "Tesla T10".to_string(),
        utilization: Some(91.0),
        temperature: Some(86),
        power: None,
        memory: Some(GpuMem {
            total: 16384,
            used: 9493,
            unit: "MiB".to_string(),
            processes: vec![process.clone()],
        }),
        fan_speed: None,
        clock_speed: None,
    });
    assert_eq!(metrics.processes, vec![process]);
    let json = serde_json::to_value(&metrics).unwrap();
    assert_eq!(json["processes"][0]["name"], "/python3.12");
}

#[tokio::test]
async fn the_native_sampler_keeps_its_state_across_samples() {
    let mut sampler = super::NativeSampler::default();
    let system = super::system_type();
    let first = sampler.sample(system, true).await.unwrap();
    let second = sampler.sample(system, false).await.unwrap();
    // On the sysinfo backends the first sample has no CPU baseline and the
    // second has one only if the state stayed with the thread between
    // them (Linux reads cumulative counters and keeps no state).
    if !cfg!(target_os = "linux") {
        assert!(first.cpu.is_empty());
        assert!(!second.cpu.is_empty());
    }
    let tx = sampler.tx.clone().unwrap();
    let (reply, answer) = tokio::sync::oneshot::channel();
    tx.send((system, false, reply)).unwrap();
    assert!(answer.await.is_ok());
}

use super::*;
use sbm_parser::types::Disk;

#[test]
fn ensure_script_writes_and_rewrites() {
    let dir = std::env::temp_dir().join("sbm_monitor_ensure_script_test");
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join("status.sh");
    std::fs::remove_file(&path).ok();

    ensure_script(&path, "v1").unwrap();
    assert_eq!(std::fs::read_to_string(&path).unwrap(), "v1");

    // Unchanged content is not rewritten (mtime stays)
    let mtime = std::fs::metadata(&path).unwrap().modified().unwrap();
    ensure_script(&path, "v1").unwrap();
    assert_eq!(std::fs::metadata(&path).unwrap().modified().unwrap(), mtime);

    // Changed content is rewritten
    ensure_script(&path, "v2").unwrap();
    assert_eq!(std::fs::read_to_string(&path).unwrap(), "v2");

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mode = std::fs::metadata(&path).unwrap().permissions().mode();
        assert_eq!(mode & 0o777, 0o755);
    }
    std::fs::remove_dir_all(&dir).ok();
}

#[test]
fn effective_capabilities_only_advertises_bsd_native_gains_on_macos() {
    use sbm_parser::capabilities::FieldSupport;
    let caps = effective_capabilities(SystemType::Bsd);
    let expected = if cfg!(target_os = "macos") {
        FieldSupport::HardwareDependent
    } else {
        sbm_parser::capabilities::capabilities(SystemType::Bsd).swap
    };
    assert_eq!(caps.swap, expected);
    if cfg!(target_os = "macos") {
        assert_eq!(caps.diskio, FieldSupport::HardwareDependent);
        assert_eq!(caps.temps, FieldSupport::HardwareDependent);
    }
    // Untouched fields still match the script-manifest-derived baseline
    assert_eq!(caps.conn, FieldSupport::NotImplemented);
}

#[test]
fn effective_capabilities_adds_windows_native_swap() {
    use sbm_parser::capabilities::FieldSupport;
    assert_eq!(
        effective_capabilities(SystemType::Linux).swap,
        sbm_parser::capabilities::capabilities(SystemType::Linux).swap
    );
    assert_eq!(
        effective_capabilities(SystemType::Windows).swap,
        FieldSupport::HardwareDependent
    );
    assert_eq!(
        effective_capabilities(SystemType::Windows).diskio,
        sbm_parser::capabilities::capabilities(SystemType::Windows).diskio
    );
}

#[test]
fn is_extended_cycle_always_true_on_first_cycle() {
    assert!(is_extended_cycle(0, 5, 60));
    assert!(is_extended_cycle(0, 30, 60));
}

#[test]
fn is_extended_cycle_respects_ratio() {
    // 60s extended / 5s interval = every 12th cycle
    assert!(is_extended_cycle(12, 5, 60));
    assert!(!is_extended_cycle(1, 5, 60));
    assert!(!is_extended_cycle(11, 5, 60));
    // extended_interval_secs smaller than interval_seconds: every cycle
    assert!(is_extended_cycle(1, 30, 5));
}

fn live_settings(idle_pause_enabled: bool, idle_pause_threshold_secs: u64) -> LiveSettings {
    LiveSettings {
        extended_interval_secs: 60,
        idle_pause_enabled,
        idle_pause_threshold_secs,
        disk_counts_network: false,
    }
}

#[test]
fn should_run_extended_never_upgrades_a_non_due_cycle() {
    // extended_due=false stays false regardless of idle state
    assert!(!should_run_extended(false, &live_settings(false, 100), 0));
    assert!(!should_run_extended(false, &live_settings(true, 100), 0));
}

#[test]
fn should_run_extended_ignores_idle_when_disabled() {
    assert!(should_run_extended(true, &live_settings(false, 10), 9999));
}

#[test]
fn should_run_extended_skips_when_idle_past_threshold() {
    let live = live_settings(true, 30);
    assert!(
        should_run_extended(true, &live, 29),
        "just under the threshold: still runs"
    );
    assert!(
        !should_run_extended(true, &live, 30),
        "at the threshold: idle"
    );
    assert!(!should_run_extended(true, &live, 999), "well past: idle");
}

/// The threshold is a `u64` out of a config file or a settings PUT, and the
/// comparison is in `i64`. `as i64` wraps past `i64::MAX`, so the largest
/// value anyone could enter — "effectively never pause" — turned into a
/// negative threshold that no idle time is below, pausing the extended
/// cycle for good.
#[test]
fn should_run_extended_does_not_wrap_a_huge_threshold() {
    let live = live_settings(true, u64::MAX);
    assert!(should_run_extended(true, &live, 0));
    assert!(should_run_extended(true, &live, i64::MAX - 1));

    // And one just past the signed range, which is where it first went
    // wrong rather than at u64::MAX.
    let live = live_settings(true, i64::MAX as u64 + 1);
    assert!(should_run_extended(true, &live, 86_400));
}

fn empty_status() -> ServerStatus {
    ServerStatus::default()
}

/// Windows disks use drive-letter paths ("C:"), not "/dev/..." — the
/// aggregation must not zero them out the way it would filter a
/// non-device Unix pseudo-filesystem
#[test]
fn aggregate_disks_counts_windows_drive_letters() {
    let disks = vec![sbm_parser::types::Disk {
        path: "C:".to_string(),
        mount: "C:".to_string(),
        used: 1000,
        size: 2000,
        avail: 1000,
        ..Default::default()
    }];

    let metrics = aggregate_disks(&disks, false);
    assert_eq!(metrics.total, 2000 * 1024);
    assert_eq!(metrics.used, 1000 * 1024);

    let details = flatten_disks(&disks);
    assert_eq!(details.len(), 1);
    assert_eq!(details[0].path, "C:");
}

#[test]
fn aggregate_disks_ignores_non_dev_paths_on_unix() {
    let disks = vec![sbm_parser::types::Disk {
        path: "tmpfs".to_string(),
        mount: "/tmp".to_string(),
        used: 1000,
        size: 2000,
        avail: 1000,
        ..Default::default()
    }];

    let metrics = aggregate_disks(&disks, false);
    assert_eq!(metrics.total, 0);
    assert!(flatten_disks(&disks).is_empty());
}

/// NFS is listed, and in the total only when the setting says (#1669).
#[test]
fn network_filesystems_count_on_request() {
    let disks = vec![
        Disk {
            path: "/dev/vda1".to_string(),
            fs_type: Some("ext4".to_string()),
            mount: "/".to_string(),
            used: 100,
            size: 1000,
            avail: 900,
            ..Default::default()
        },
        Disk {
            path: "nas:/export".to_string(),
            fs_type: Some("nfs4".to_string()),
            mount: "/mnt/nas".to_string(),
            used: 400,
            size: 500,
            avail: 100,
            ..Default::default()
        },
    ];
    assert_eq!(aggregate_disks(&disks, false).total, 1000 * 1024);
    assert_eq!(aggregate_disks(&disks, true).total, 1500 * 1024);
    assert_eq!(flatten_disks(&disks).len(), 2);
}

/// A device nothing is mounted from is a row; one that only holds others
/// (the LVM physical volume under the root) is the tree, not a row.
#[test]
fn disk_details_list_unmounted_devices_but_not_containers() {
    let disks = vec![
        Disk {
            path: "/dev/nvme0n1p3".to_string(),
            fs_type: Some("LVM2_member".to_string()),
            children: vec![Disk {
                path: "/dev/mapper/pve-root".to_string(),
                fs_type: Some("ext4".to_string()),
                mount: "/".to_string(),
                used: 100,
                size: 1000,
                avail: 900,
                ..Default::default()
            }],
            ..Default::default()
        },
        Disk {
            path: "/dev/sdb1".to_string(),
            fs_type: Some("ext4".to_string()),
            ..Default::default()
        },
        Disk {
            path: "/dev/sdc".to_string(),
            fs_type: Some("zfs_member".to_string()),
            ..Default::default()
        },
    ];
    let paths: Vec<String> = flatten_disks(&disks).into_iter().map(|d| d.path).collect();
    assert_eq!(paths, ["/dev/mapper/pve-root", "/dev/sdb1"]);
    assert_eq!(aggregate_disks(&disks, true).total, 1000 * 1024);
}

#[test]
fn disk_details_keep_distinct_mounts_of_the_same_device() {
    let disks = vec![
        Disk {
            path: "/dev/mapper/data".to_string(),
            mount: "/".to_string(),
            used: 100,
            size: 1000,
            ..Default::default()
        },
        Disk {
            path: "/dev/mapper/data".to_string(),
            mount: "/home".to_string(),
            used: 200,
            size: 1000,
            ..Default::default()
        },
    ];

    let details = flatten_disks(&disks);
    assert_eq!(details.len(), 2);
    assert_eq!(details[0].mount, "/");
    assert_eq!(details[1].mount, "/home");
}

#[test]
fn unidentified_apfs_volumes_are_not_merged_by_capacity() {
    let disks = vec![
        Disk {
            path: "Macintosh HD (/)".to_string(),
            mount: "/".to_string(),
            fs_type: Some("apfs".to_string()),
            used: 200,
            size: 1000,
            avail: 600,
            ..Default::default()
        },
        Disk {
            path: "Macintosh HD (/System/Volumes/Data)".to_string(),
            mount: "/System/Volumes/Data".to_string(),
            fs_type: Some("APFS".to_string()),
            used: 200,
            size: 1000,
            avail: 600,
            ..Default::default()
        },
    ];

    let metrics = aggregate_disks(&disks, false);
    assert_eq!(metrics.total, 2000 * 1024);
    assert_eq!(metrics.free, 1200 * 1024);
    assert_eq!(metrics.used, 400 * 1024);
}

/// Native sampling keys a volume by its mount point — the panel needs one
/// row per volume — so the `/dev/diskN` form never reaches `path` and the
/// device arrives in `name`. Without pooling on it, a Mac's capacity is
/// reported once per volume. Values as probed on a real machine.
#[test]
fn native_apfs_volumes_are_pooled_by_container() {
    let volume = |mount: &str, device: &str| Disk {
        path: mount.to_string(),
        mount: mount.to_string(),
        fs_type: Some("apfs".to_string()),
        name: Some(device.to_string()),
        used: 400,
        size: 1000,
        avail: 600,
        ..Default::default()
    };
    let disks = vec![
        volume("/", "disk3s1s1"),
        volume("/System/Volumes/Data", "disk3s5"),
        volume("/System/Volumes/VM", "disk3s6"),
    ];

    let metrics = aggregate_disks(&disks, false);
    assert_eq!(metrics.total, 1000 * 1024, "capacity counted once");
    assert_eq!(metrics.free, 600 * 1024);
    // A container's used space is its size less its free space — what all
    // its volumes share, the ones sysinfo does not list included.
    assert_eq!(metrics.used, 400 * 1024);
    assert_eq!(metrics.usage_percent, 40.0);
}

/// The script path (`df`, the type from `mount`): each volume has its own
/// `used`, and the container is still counted once, used = size - free. Values from a
/// real Mac, except the Data volume's free space, moved a little as it
/// would when written to between two volumes' readings.
#[test]
fn df_apfs_volumes_are_one_container() {
    let volume = |path: &str, mount: &str, used: u64, avail: u64| Disk {
        path: path.to_string(),
        mount: mount.to_string(),
        used,
        size: 971298980,
        avail,
        fs_type: Some("apfs".to_string()),
        ..Default::default()
    };
    let disks = vec![
        volume("/dev/disk3s1s1", "/", 13340072, 193612532),
        volume("/dev/disk3s6", "/System/Volumes/VM", 15729228, 193612532),
        volume("/dev/disk3s5", "/System/Volumes/Data", 735346236, 193612480),
        Disk {
            path: "/dev/disk12s1".to_string(),
            mount: "/Volumes/aigo".to_string(),
            used: 696246752,
            size: 2000193840,
            avail: 433466892,
            fs_type: Some("apfs".to_string()),
            ..Default::default()
        },
    ];

    let metrics = aggregate_disks(&disks, false);
    assert_eq!(metrics.total, (971298980 + 2000193840) * 1024);
    assert_eq!(metrics.free, (193612532 + 433466892) * 1024);
    // `aigo` shares its container with a volume that is not mounted, so
    // the container's own figure is what that disk has used.
    assert_eq!(metrics.used, (971298980 - 193612532 + 2000193840 - 433466892) * 1024);
    assert!(metrics.usage_percent < 100.0);
}

/// Two disks are two disks. The volume *label* cannot say so — two drives
/// nobody renamed share one ("Untitled"), and a pair bought together has
/// the same capacity, so a label-keyed pool would report half the storage
/// this machine has. The container behind each volume is the identity.
#[test]
fn distinct_apfs_containers_are_not_pooled() {
    let volume = |mount: &str, device: &str| Disk {
        path: mount.to_string(),
        mount: mount.to_string(),
        fs_type: Some("apfs".to_string()),
        name: Some(device.to_string()),
        used: 400,
        size: 1000,
        avail: 600,
        ..Default::default()
    };
    let disks = vec![
        volume("/Volumes/Untitled", "disk4s1"),
        volume("/Volumes/Untitled 1", "disk9s1"),
    ];

    let metrics = aggregate_disks(&disks, false);
    assert_eq!(metrics.total, 2000 * 1024);
    assert_eq!(metrics.free, 1200 * 1024);
    // Each container's size less its free space.
    assert_eq!(metrics.used, 800 * 1024);
}

/// The `name` fallback is APFS-only: on Linux `name` is an lsblk NAME, and
/// two rows carrying one are two views of a device, not a pool.
#[test]
fn non_apfs_volumes_sharing_a_name_are_not_pooled() {
    let volume = |path: &str, mount: &str| Disk {
        path: path.to_string(),
        mount: mount.to_string(),
        fs_type: Some("ext4".to_string()),
        name: Some("sda1".to_string()),
        used: 200,
        size: 1000,
        avail: 600,
        ..Default::default()
    };
    let disks = vec![
        volume("/dev/sda1", "/"),
        volume("/dev/sda1-bind", "/mnt/data"),
    ];

    let metrics = aggregate_disks(&disks, false);
    assert_eq!(metrics.total, 2000 * 1024);
}

#[test]
fn adapt_status_uses_fresh_extended_fields_when_present() {
    let mut status = empty_status();
    status.uptime = Some("up 1 day".to_string());
    status.conn = Some(sbm_parser::types::Conn {
        max_conn: 10,
        fail: 0,
    });
    status.diskio = vec![sbm_parser::types::DiskIoPiece {
        dev: "sda".to_string(),
        sectors_read: 100,
        sectors_write: 50,
    }];
    status.batteries = vec![sbm_parser::types::Battery {
        percent: Some(80),
        status: sbm_parser::types::BatteryStatus::Charging,
        name: None,
        cycle: None,
        tech: None,
    }];
    status.sensors = vec![sbm_parser::types::SensorItem {
        device: "coretemp".to_string(),
        adapter: "ISA".to_string(),
        details: vec![],
    }];
    status.disk_smart = vec![sbm_parser::types::DiskSmart {
        device: "sda".to_string(),
        healthy: Some(true),
        temperature: Some(35.0),
        model: None,
        serial: None,
        power_on_hours: None,
        power_cycle_count: None,
        raw_data: serde_json::Value::Null,
        smart_attributes: Default::default(),
    }];

    let metrics = adapt_status(
        SystemType::Linux,
        status,
        &Config::default(),
        None,
        None,
        true,
        false,
    );

    assert_eq!(metrics.uptime.as_deref(), Some("up 1 day"));
    assert_eq!(metrics.conn.unwrap().max_conn, 10);
    assert_eq!(metrics.diskio.len(), 1);
    assert_eq!(metrics.batteries.len(), 1);
    assert_eq!(metrics.sensors.len(), 1);
    assert_eq!(metrics.disk_smart.len(), 1);
}

#[test]
fn adapt_status_preserves_per_device_gpu_identity_and_optional_metrics() {
    let mut status = empty_status();
    status.gpus = vec![sbm_parser::types::GpuItem {
        id: "0000:00:02.0".to_string(),
        vendor: "intel".to_string(),
        name: "Intel Integrated Graphics".to_string(),
        utilization: Some(68.25),
        temperature: None,
        power: Some("1.50 W".to_string()),
        memory: None,
        fan_speed: None,
        clock_speed: Some(750),
    }];

    let metrics = adapt_status(
        SystemType::Linux,
        status,
        &Config::default(),
        None,
        None,
        false,
        false,
    );

    let gpu = &metrics.gpus[0];
    assert_eq!(gpu.id, "0000:00:02.0");
    assert_eq!(gpu.vendor, "intel");
    assert_eq!(gpu.usage_percent, Some(68.25));
    assert_eq!(gpu.temperature, None);
    assert_eq!(gpu.memory_used, None);
    assert_eq!(gpu.clock_speed, Some(750));
}

#[test]
fn adapt_status_carries_forward_when_extended_fields_absent() {
    let prev = adapt_status(
        SystemType::Linux,
        {
            let mut s = empty_status();
            s.uptime = Some("up 1 day".to_string());
            s.diskio = vec![sbm_parser::types::DiskIoPiece {
                dev: "sda".to_string(),
                sectors_read: 100,
                sectors_write: 50,
            }];
            s.batteries = vec![sbm_parser::types::Battery {
                percent: Some(80),
                status: sbm_parser::types::BatteryStatus::Charging,
                name: None,
                cycle: None,
                tech: None,
            }];
            s
        },
        &Config::default(),
        None,
        None,
        true,
        false,
    );
    // Next (non-extended) cycle: script-only fields carry forward, while
    // the native disk-I/O snapshot reflects the current empty device set.
    let metrics = adapt_status(
        SystemType::Linux,
        empty_status(),
        &Config::default(),
        None,
        Some(&prev),
        false,
        false,
    );

    assert_eq!(metrics.uptime.as_deref(), Some("up 1 day"));
    assert!(metrics.diskio.is_empty());
    assert_eq!(metrics.batteries.len(), 1);
    // The non-extended cycle didn't refresh extended data — freshness
    // timestamp carries over from the extended cycle, not bumped to now
    assert_eq!(metrics.extended_updated_at, prev.extended_updated_at);
}

#[test]
fn failed_extended_command_keeps_previous_extended_metrics() {
    use sbm_parser::script::{ShellFunc, cmd_marker};

    let mut prev = adapt_status(
        SystemType::Linux,
        {
            let mut status = empty_status();
            status.batteries = vec![sbm_parser::types::Battery {
                percent: Some(80),
                status: sbm_parser::types::BatteryStatus::Charging,
                name: None,
                cycle: None,
                tech: None,
            }];
            status
        },
        &Config::default(),
        None,
        None,
        true,
        false,
    );
    prev.custom_cmds = vec![CustomCmdOutput {
        name: "health".to_string(),
        output: "ok".to_string(),
    }];

    let mut execution = ScriptExecution::default();
    execution.record(
        &ShellFunc::StatusExt,
        false,
        format!("{}\npartial", cmd_marker("battery")).as_bytes(),
    );
    execution.record(
        &ShellFunc::Status,
        true,
        format!("{}\ncpu 100 0 100 0 0 0 0 0 0 0", cmd_marker("cpu")).as_bytes(),
    );

    assert!(execution.status_succeeded);
    assert!(!execution.extended_succeeded);
    assert!(execution.segments.iter().any(|(key, _)| key == "cpu"));
    assert!(!execution.segments.iter().any(|(key, _)| key == "battery"));

    let raw = execution.segments.into_iter().collect::<HashMap<_, _>>();
    let status = sbm_parser::parse_status(SystemType::Linux, &raw);
    let metrics = adapt_status(
        SystemType::Linux,
        status,
        &Config::default(),
        None,
        Some(&prev),
        execution.extended_succeeded,
        false,
    );

    assert_eq!(metrics.batteries, prev.batteries);
    assert_eq!(metrics.extended_updated_at, prev.extended_updated_at);
    let custom_cmds = refreshed_custom_cmds(Vec::new(), Some(&prev), false);
    assert_eq!(custom_cmds.len(), 1);
    assert_eq!(custom_cmds[0].name, "health");
    assert_eq!(custom_cmds[0].output, "ok");
}

#[test]
fn fresh_empty_extended_fields_clear_removed_devices() {
    let prev = adapt_status(
        SystemType::Linux,
        {
            let mut status = empty_status();
            status.batteries = vec![sbm_parser::types::Battery {
                percent: Some(80),
                status: sbm_parser::types::BatteryStatus::Charging,
                name: None,
                cycle: None,
                tech: None,
            }];
            status
        },
        &Config::default(),
        None,
        None,
        true,
        false,
    );

    let metrics = adapt_status(
        SystemType::Linux,
        empty_status(),
        &Config::default(),
        None,
        Some(&prev),
        true,
        false,
    );

    assert!(metrics.batteries.is_empty());
}

#[test]
fn diskio_rate_computed_from_cumulative_delta_over_elapsed_time() {
    let mut first_status = empty_status();
    first_status.diskio = vec![sbm_parser::types::DiskIoPiece {
        dev: "sda".to_string(),
        sectors_read: 1000,
        sectors_write: 500,
    }];
    let first = adapt_status(
        SystemType::Linux,
        first_status,
        &Config::default(),
        None,
        None,
        false,
        false,
    );
    assert!(
        first.diskio_rate.is_empty(),
        "no baseline on the first cycle"
    );

    let mut second_status = empty_status();
    // +2000 sectors read, +1000 written, 1MiB/512B-per-sector = 2048 sectors
    second_status.diskio = vec![sbm_parser::types::DiskIoPiece {
        dev: "sda".to_string(),
        sectors_read: 3000,
        sectors_write: 1500,
    }];
    let mut second = adapt_status(
        SystemType::Linux,
        second_status,
        &Config::default(),
        None,
        Some(&first),
        false,
        false,
    );
    // Force a known 2-second elapsed window instead of relying on real time
    // passing between the two adapt_status() calls in this test
    second.timestamp = first.timestamp + chrono::Duration::seconds(2);
    let rate = compute_diskio_rate(second.timestamp, &second.diskio, Some(&first));

    assert_eq!(rate.len(), 1);
    assert_eq!(rate[0].dev, "sda");
    // (3000-1000)*512 bytes / 2s = 512_000 B/s
    assert_eq!(rate[0].read_bytes_per_sec, 512_000.0);
    // (1500-500)*512 bytes / 2s = 256_000 B/s
    assert_eq!(rate[0].write_bytes_per_sec, 256_000.0);
}

#[test]
fn diskio_counter_reset_has_no_rate_sample() {
    let mut first_status = empty_status();
    first_status.diskio = vec![sbm_parser::types::DiskIoPiece {
        dev: "sda".to_string(),
        sectors_read: 1000,
        sectors_write: 500,
    }];
    let first = adapt_status(
        SystemType::Linux,
        first_status,
        &Config::default(),
        None,
        None,
        false,
        false,
    );

    let current = [sbm_parser::types::DiskIoPiece {
        dev: "sda".to_string(),
        sectors_read: 10,
        sectors_write: 5,
    }];
    let rate = compute_diskio_rate(
        first.timestamp + chrono::Duration::seconds(1),
        &current,
        Some(&first),
    );

    assert!(rate.is_empty());
}

#[test]
fn monitor_script_keeps_only_non_native_manifest_commands() {
    use sbm_parser::commands::{AMD, BATTERY, CONN, DISK_SMART, SENSORS};
    use sbm_parser::script::{ShellFunc, cmd_marker};

    let bsd_native = [DISK_SMART];
    let bsd_all = sbm_parser::commands::commands(SystemType::Bsd)
        .iter()
        .map(|spec| spec.key)
        .collect::<Vec<_>>();
    let bsd_expected = if native_status_available(SystemType::Bsd) {
        &bsd_native[..]
    } else {
        &bsd_all[..]
    };
    let cases: [(SystemType, &[&str]); 3] = [
        (SystemType::Linux, &[BATTERY, AMD, SENSORS, DISK_SMART]),
        (SystemType::Bsd, bsd_expected),
        (
            SystemType::Windows,
            &[CONN, BATTERY, AMD, SENSORS, DISK_SMART],
        ),
    ];
    for (system, expected) in cases {
        let enabled: Vec<&str> = sbm_parser::commands::commands(system)
            .iter()
            .filter(|spec| monitor_script_command_needed(system, spec.key))
            .map(|spec| spec.key)
            .collect();
        assert_eq!(enabled, expected, "{system:?}");

        // Assert the generated script itself, not just its disabled list.
        // Unix scripts carry Linux and BSD branches together, so inspect
        // only the branch this monitor will execute.
        let script = build_status_script(system);
        let generated = match system {
            SystemType::Windows => script,
            SystemType::Linux | SystemType::Bsd => [
                unix_monitor_branch(&script, ShellFunc::Status, system),
                unix_monitor_branch(&script, ShellFunc::StatusExt, system),
            ]
            .join("\n"),
        };
        for spec in sbm_parser::commands::commands(system) {
            assert_eq!(
                generated.contains(&cmd_marker(spec.key)),
                expected.contains(&spec.key),
                "{system:?} {} should {}be generated",
                spec.key,
                if expected.contains(&spec.key) {
                    ""
                } else {
                    "not "
                },
            );
        }
    }
}

fn unix_monitor_branch(
    script: &str,
    func: sbm_parser::script::ShellFunc,
    system: SystemType,
) -> &str {
    let start = script
        .find(&format!("{}() {{", func.name()))
        .expect("generated function");
    let body = &script[start..];
    let body = &body[..body.find("\n}\n").expect("function end")];
    let (_, branches) = body
        .split_once("\tif [ \"$macSign\" = \"\" ] && [ \"$bsdSign\" = \"\" ]; then\n")
        .expect("Unix system branch");
    let (linux, bsd) = branches.split_once("\n\telse\n").expect("Unix else branch");
    let (bsd, _) = bsd.split_once("\n\tfi\n").expect("Unix branch end");
    match system {
        SystemType::Linux => linux,
        SystemType::Bsd => bsd,
        SystemType::Windows => unreachable!("Windows uses a different script"),
    }
}

/// The monitor's real collection path: run the generated script, split
/// output. Both shell functions run, but native-covered keys stay absent.
#[cfg(unix)]
#[tokio::test]
async fn execute_commands_via_script_smoke() {
    let execution = execute_commands(system_type(), true).await.unwrap();
    assert!(execution.status_succeeded);
    assert!(execution.extended_succeeded);
    let keys: Vec<&str> = execution.segments.iter().map(|(k, _)| k.as_str()).collect();
    assert!(keys.contains(&"diskSmart"), "extended half missing");
    for redundant in ["echo", "time", "net", "cpu", "mem", "disk", "nvidia"] {
        assert!(
            !keys.contains(&redundant),
            "redundant {redundant} in {keys:?}"
        );
    }
}

/// Custom-command sections are picked out of the same output, keeping the
/// order the script printed them in — the user's order, and the only
/// place it survives.
#[test]
fn custom_cmd_outputs_keep_the_scripts_order() {
    let segments = vec![
        ("cpu".to_string(), "…".to_string()),
        (
            sbm_parser::script::custom_result_key("second"),
            "b".to_string(),
        ),
        (
            sbm_parser::script::custom_result_key("first"),
            "a".to_string(),
        ),
    ];
    let out = custom_cmd_outputs(&segments);
    assert_eq!(out.len(), 2);
    assert_eq!(out[0].name, "second");
    assert_eq!(out[0].output, "b");
    assert_eq!(out[1].name, "first");
}

#[test]
fn supported_bsd_targets_use_the_native_bsd_backend() {
    for os in ["macos", "freebsd", "openbsd", "netbsd", "dragonfly"] {
        assert_eq!(system_type_for(os), SystemType::Bsd, "{os}");
    }
    assert_eq!(system_type_for("linux"), SystemType::Linux);
    assert_eq!(system_type_for("windows"), SystemType::Windows);
}

#[test]
fn first_builtin_segment_wins_over_a_custom_spoof() {
    let segments = vec![
        ("host".to_string(), "real-host".to_string()),
        (
            sbm_parser::script::custom_result_key("bad"),
            "output".to_string(),
        ),
        ("host".to_string(), "forged-host".to_string()),
    ];
    let mut raw = HashMap::new();
    for (key, value) in segments {
        raw.entry(key).or_insert(value);
    }
    assert_eq!(raw.get("host").map(String::as_str), Some("real-host"));
}

#[tokio::test]
async fn a_stuck_external_command_is_terminated() {
    let command = if cfg!(windows) {
        let mut command = TokioCommand::new("powershell");
        command.args(["-NoProfile", "-Command", "Start-Sleep -Seconds 2"]);
        command
    } else {
        let mut command = TokioCommand::new("sh");
        command.args(["-c", "sleep 2"]);
        command
    };
    let started = std::time::Instant::now();
    let output = command_output_with_timeout(command, "test sleep", Duration::from_millis(100))
        .await
        .unwrap();

    assert!(output.is_none());
    assert!(started.elapsed() < Duration::from_secs(1));
}

#[cfg(windows)]
#[tokio::test]
async fn a_timed_out_windows_command_cannot_leave_a_descendant() {
    let dir = tempfile::tempdir().unwrap();
    let marker = dir.path().join("survived");
    let child_path = dir.path().join("child.ps1");
    let marker_arg = marker.to_string_lossy().replace('\'', "''");
    std::fs::write(
        &child_path,
        format!("Start-Sleep -Seconds 2; Set-Content -LiteralPath '{marker_arg}' -Value alive"),
    )
    .unwrap();
    let child_arg = child_path.to_string_lossy().replace('\'', "''");
    let parent_script = format!(
        "$q = '\"' + '{child_arg}' + '\"'; Start-Process powershell -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$q); Start-Sleep -Seconds 30"
    );
    let mut command = TokioCommand::new("powershell");
    command.args(["-NoProfile", "-Command", &parent_script]);

    let output =
        command_output_with_timeout(command, "test process tree", Duration::from_millis(200))
            .await
            .unwrap();
    assert!(output.is_none());
    tokio::time::sleep(Duration::from_secs(3)).await;
    assert!(!marker.exists());
}

#[tokio::test]
async fn an_external_command_cannot_silently_truncate_output() {
    // Comfortably over the cap rather than one byte over it. At exactly
    // `MAX + 1` the reader reaches its `take` limit in the same moment the
    // child finishes writing and exits, so the two things this races —
    // the overflow and the wait — become ready together, and the test
    // stops being about either. Well over, the reader hits the cap while
    // the child is still writing and then blocks on a full pipe, which is
    // the case the announcement exists for.
    const OVER_CAP: usize = 4 * 1024 * 1024;
    let ps_write = format!(
        "$out = [Console]::OpenStandardOutput(); $bytes = New-Object byte[] {OVER_CAP}; $out.Write($bytes, 0, $bytes.Length)"
    );

    let command = if cfg!(windows) {
        let mut command = TokioCommand::new("powershell");
        command.args(["-NoProfile", "-Command", &ps_write]);
        command
    } else {
        let mut command = TokioCommand::new("sh");
        command.args(["-c", &format!("head -c {OVER_CAP} /dev/zero")]);
        command
    };

    // Generous, because the number is not the subject. What is asserted is
    // that too much output is *reported* as too much; how long this
    // machine takes to start a process and move four megabytes is the CI
    // runner's business. Measured at 179 ms on an idle Windows box against
    // a 5-second budget, which windows-latest still exceeded often enough
    // to fail three of five runs — and which 70 runs here, twelve of them
    // concurrent, never reproduced. Detection that is actually broken
    // fails this just the same, only later.
    //
    // Says what it got instead of `unwrap_err`, which reported only
    // "Ok value: None" and did not separate a child that wrote nothing
    // from one that wrote enough and was never noticed.
    let error = match command_output_with_timeout(
        command,
        "test output",
        Duration::from_secs(30),
    )
    .await
    {
        Err(error) => error,
        Ok(output) => panic!(
            "expected an overflow error, got {:?}",
            output.map(|o| (o.status, o.stdout.len(), o.stderr.len()))
        ),
    };

    assert!(error.to_string().contains("more than"));
}
