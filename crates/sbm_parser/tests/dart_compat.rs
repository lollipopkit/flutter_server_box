//! Behavior-parity tests against the Dart implementation (the shared-parser design "tests as spec")
//!
//! Cases and fixtures ported from flutter_server_box `test/`
//! (cpu_test / memory_test / disk_test / net_speed_test),
//! Each test names its corresponding Dart case.

use sbm_parser::types::*;
use sbm_parser::{bsd, commands, linux, windows, SystemType};
use std::collections::HashMap;

// ---------- CPU:cpu_test.dart ----------

/// Dart 'Test SingleCpuCore.parse'
#[test]
fn cpu_parse_single_line() {
    let raw = "cpu  18232538 52837 5772391 334460731 247294 0 134107 0 0 0";
    let result = linux::parse_cpu(raw);
    assert_eq!(result.len(), 1);
    assert_eq!(result[0].id, "cpu");
    assert_eq!(result[0].total(), 358899898);
}

/// Dart 'SingleCpuCore.parse skips malformed rows'
#[test]
fn cpu_parse_skips_malformed() {
    let raw = "cpu  1 2 3 4 5 6 7\ncpu0  broken 2 3 4 5 6 7\ncpu1  8 9 10 11 12 13 14";
    let ids: Vec<String> = linux::parse_cpu(raw).into_iter().map(|c| c.id).collect();
    assert_eq!(ids, ["cpu", "cpu1"]);
}

/// Dart 'SingleCpuCore.parse skips blanks and stops at non-CPU records'
#[test]
fn cpu_parse_stops_at_non_cpu() {
    let raw = "cpu  1 2 3 4 5 6 7\n\ncpu0  8 9 10 11 12 13 14\nintr  1 2 3 4 5 6 7\ncpu1  15 16 17 18 19 20 21";
    let ids: Vec<String> = linux::parse_cpu(raw).into_iter().map(|c| c.id).collect();
    assert_eq!(ids, ["cpu", "cpu0"]);
}

/// Dart 'Test Cpus calculation': two-sample delta, used ≈ 75%
#[test]
fn cpu_used_percent_delta() {
    let pre = &linux::parse_cpu("cpu 18232538 52837 5772391 334460731 247294 0 134107 0 0 0")[0];
    let now = &linux::parse_cpu("cpu 18232638 52937 5772491 334460831 247294 0 134107 0 0 0")[0];
    let used = cpu_used_percent(pre, now);
    assert!((used - 75.0).abs() < 0.1, "expected ~75.0, got {}", used);
}

/// Dart 'Test parseBsdCpu for macOS'
#[test]
fn cpu_parse_bsd_macos() {
    let cores = bsd::parse_cpu("CPU usage: 14.70% user, 12.76% sys, 72.52% idle");
    assert_eq!(cores.len(), 1);
    assert_eq!(cores[0].user, 14);
    assert_eq!(cores[0].sys, 12);
    assert_eq!(cores[0].idle, 72);
}

/// Dart 'Test parseBsdCpu for FreeBSD'
#[test]
fn cpu_parse_bsd_freebsd() {
    let cores =
        bsd::parse_cpu("CPU: 5.2% user, 0.0% nice, 3.1% system, 0.1% interrupt, 91.6% idle");
    assert_eq!(cores[0].user, 5);
    assert_eq!(cores[0].nice, 0);
    assert_eq!(cores[0].sys, 3);
    assert_eq!(cores[0].irq, 0);
    assert_eq!(cores[0].idle, 91);
}

/// macOS/FreeBSD sysctl brand string, with the real core count appended
#[test]
fn cpu_brand_parse_bsd() {
    let brands = bsd::parse_cpu_brand("Apple M1 Pro\n10\n");
    assert_eq!(brands, vec![("Apple M1 Pro".to_string(), 10)]);
}

/// No trailing count line: falls back to a single-occurrence count
#[test]
fn cpu_brand_parse_bsd_no_count_line() {
    let brands = bsd::parse_cpu_brand("Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz\n");
    assert_eq!(brands, vec![("Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz".to_string(), 1)]);
}

/// Empty/whitespace-only output yields no brand entries
#[test]
fn cpu_brand_parse_bsd_empty() {
    assert!(bsd::parse_cpu_brand("").is_empty());
    assert!(bsd::parse_cpu_brand("\n\n").is_empty());
}

/// FreeBSD `top -b -d 1 -P`: genuine per-core lines, not replicated
#[test]
fn cpu_parse_freebsd_real_per_core() {
    let raw = "\
CPU 0:  0.7% user,  0.0% nice,  1.5% system,  0.7% interrupt, 97.0% idle
CPU 1:  0.0% user,  0.0% nice,  0.0% system,  0.4% interrupt, 99.6% idle
CPU 2:  50.0% user,  0.0% nice,  10.0% system,  0.0% interrupt, 40.0% idle
CPU 3:  0.0% user,  0.0% nice,  0.0% system,  0.0% interrupt, 100.0% idle
";
    let cores = bsd::parse_cpu(raw);
    assert_eq!(cores.len(), 4);
    assert_eq!(cores[0].id, "cpu0");
    assert_eq!(cores[0].idle, 97);
    assert_eq!(cores[2].user, 50);
    assert_eq!(cores[2].sys, 10);
    assert_eq!(cores[2].idle, 40);
    assert_eq!(cores[3].idle, 100);
}

/// macOS: real logical core count appended via `sysctl -n hw.ncpu`;
/// the aggregate reading is replicated per pseudo-core
#[test]
fn cpu_parse_bsd_macos_with_core_count() {
    let cores = bsd::parse_cpu("CPU usage: 14.70% user, 12.76% sys, 72.52% idle\n10\n");
    assert_eq!(cores.len(), 10);
    assert_eq!(cores[0].id, "cpu0");
    assert_eq!(cores[9].id, "cpu9");
    assert_eq!(cores[0].user, 14);
    assert_eq!(cores[9].user, 14);
    assert_eq!(cores[0].idle, 72);
}

/// FreeBSD: same trailing-count mechanism
#[test]
fn cpu_parse_bsd_freebsd_with_core_count() {
    let cores = bsd::parse_cpu(
        "CPU: 5.2% user, 0.0% nice, 3.1% system, 0.1% interrupt, 91.6% idle\n4\n",
    );
    assert_eq!(cores.len(), 4);
    assert_eq!(cores[3].id, "cpu3");
    assert_eq!(cores[0].idle, 91);
}

/// Dart 'Test parseBsdCpu fallback clamps invalid percentages'
#[test]
fn cpu_parse_bsd_fallback_clamps() {
    let cores = bsd::parse_cpu("CPU fallback: -5.5% user, 150.2% sys, 101.9% idle");
    assert_eq!(cores[0].user, 0);
    assert_eq!(cores[0].sys, 100);
    assert_eq!(cores[0].idle, 100);
}

// ---------- Memory: memory_test.dart ----------

/// Dart 'Test Memory.parse'
#[test]
fn mem_parse_meminfo() {
    let raw = "MemTotal:       32768 kB\nMemFree:        16384 kB\nMemAvailable:   24576 kB";
    let m = linux::parse_mem(raw).unwrap();
    assert_eq!(m.total, 32768);
    assert_eq!(m.free, 16384);
    assert_eq!(m.avail, 24576);
    assert!((m.used_percent() - 0.25).abs() < 0.01);
    assert!((m.avail_percent() - 0.75).abs() < 0.01);
}

/// Dart 'Test parseBsdMemory for macOS'
#[test]
fn mem_parse_bsd_macos() {
    let m = bsd::parse_mem("PhysMem: 32G used (1536M wired), 64G unused.").unwrap();
    assert_eq!(m.total, (32 + 64) * 1024 * 1024);
    assert_eq!(m.free, 64 * 1024 * 1024);
    assert_eq!(m.avail, 64 * 1024 * 1024);
}

/// Modern macOS top output with commas inside parentheses (regression for an old monitor bug)
#[test]
fn mem_parse_bsd_macos_comma_in_parens() {
    let m = bsd::parse_mem("PhysMem: 61G used (6811M wired, 1251M compressor), 1867M unused.")
        .unwrap();
    assert_eq!(m.total, 61 * 1024 * 1024 + 1867 * 1024);
    assert_eq!(m.free, 1867 * 1024);
}

/// macOS PhysMem + vm_stat: avail derived from real usage
/// (active + wired + compressor), so cache does not count as used
#[test]
fn mem_parse_bsd_macos_with_vm_stat() {
    let raw = "PhysMem: 62G used (6542M wired, 3155M compressor), 1104M unused.\n\
Mach Virtual Memory Statistics: (page size of 16384 bytes)\n\
Pages free:                                    33594.\n\
Pages active:                                1741099.\n\
Pages inactive:                              1703799.\n\
Pages wired down:                             417030.\n\
Pages purgeable:                               58852.\n\
Pages occupied by compressor:                 201000.\n";
    let m = bsd::parse_mem(raw).unwrap();
    let total = 62 * 1024 * 1024 + 1104 * 1024;
    assert_eq!(m.total, total);
    assert_eq!(m.free, 1104 * 1024);
    let used_kib = (1741099 + 417030 + 201000) * 16; // pages x 16 KiB
    assert_eq!(m.avail, total - used_kib);
}

/// Dart 'Test parseBsdMemory for FreeBSD'
#[test]
fn mem_parse_bsd_freebsd() {
    let m = bsd::parse_mem(
        "Mem: 456M Active, 2918M Inact, 1127M Wired, 187M Cache, 829M Buf, 3535M Free",
    )
    .unwrap();
    assert_eq!(m.total, (456 + 2918 + 1127 + 187 + 829 + 3535) * 1024);
    assert_eq!(m.free, 3535 * 1024);
    assert_eq!(m.avail, 3535 * 1024);
}

/// Dart `Swap.parse` semantics
#[test]
fn swap_parse_meminfo() {
    let raw = "SwapTotal:      2097148 kB\nSwapFree:       1048574 kB\nSwapCached:     1024 kB";
    let s = linux::parse_swap(raw).unwrap();
    assert_eq!(s.total, 2097148);
    assert_eq!(s.free, 1048574);
    assert_eq!(s.cached, 1024);
}

// ---------- Disk: disk_test.dart ----------

/// Dart 'parse lsblk JSON output': 6 entries (LVM2_member/ext4//swap/vfat/ext2/crypto_LUKS)
#[test]
fn disk_parse_lsblk_json() {
    let disks = linux::parse_disk(include_str!("fixtures/lsblk.json"));
    assert_eq!(disks.len(), 6);

    let root = disks.iter().find(|d| d.mount == "/").unwrap();
    assert_eq!(root.fs_type.as_deref(), Some("ext4"));
    assert_eq!(root.size, 982141468672 / 1024);
    assert_eq!(root.used, 552718364672 / 1024);
    assert_eq!(root.avail, 379457622016 / 1024);
    assert_eq!(root.used_percent, 56);

    let efi = disks.iter().find(|d| d.mount == "/boot/efi").unwrap();
    assert_eq!(efi.fs_type.as_deref(), Some("vfat"));
    assert_eq!(efi.size, 535805952 / 1024);
    assert_eq!(efi.used_percent, 1);

    let boot = disks.iter().find(|d| d.mount == "/boot").unwrap();
    assert_eq!(boot.fs_type.as_deref(), Some("ext2"));
    assert_eq!(boot.used_percent, 34);
}

/// Dart 'parse nested lsblk JSON output falls back to child filesystems'
#[test]
fn disk_parse_nested_lsblk() {
    let disks = linux::parse_disk(include_str!("fixtures/lsblk_nested.json"));
    assert!(!disks.is_empty());
    assert!(!disks.iter().any(|d| d.path == "/dev/nvme0n1"));

    let root = disks.iter().find(|d| d.mount == "/").unwrap();
    assert_eq!(root.fs_type.as_deref(), Some("ext4"));
    assert_eq!(root.path, "/dev/nvme0n1p2");
    assert_eq!(root.used_percent, 45);

    let boot = disks.iter().find(|d| d.mount == "/boot").unwrap();
    assert_eq!(boot.uuid.as_deref(), Some("12345678-abcd-1234-abcd-1234567890ab"));
}

/// Dart 'preserves all descendants for intermediate containers'
#[test]
fn disk_parse_nested_container_keeps_children() {
    let disks = linux::parse_disk(include_str!("fixtures/lsblk_container.json"));
    assert_eq!(disks.len(), 1);

    let vg = &disks[0];
    assert_eq!(vg.path, "/dev/mapper/vg-root");
    assert_eq!(vg.children.len(), 2);
    let mounts: Vec<&str> = vg.children.iter().map(|d| d.mount.as_str()).collect();
    assert!(mounts.contains(&"/") && mounts.contains(&"/home"));
}

/// Dart 'parse df -k output (fallback mode)': 2 entries (vda3, vda2; tmpfs and
/// the kernel mounts excluded)
#[test]
fn disk_parse_df_k() {
    let disks = linux::parse_disk(include_str!("fixtures/df_k.txt"));
    assert_eq!(disks.len(), 2);

    let root = disks.iter().find(|d| d.mount == "/").unwrap();
    assert_eq!(root.path, "/dev/vda3");
    assert_eq!(root.used_percent, 47);
    assert_eq!(root.size, 40910528);
    assert_eq!(root.used, 18067948);
    assert_eq!(root.avail, 20951380);

    let efi = disks.iter().find(|d| d.mount == "/boot/efi").unwrap();
    assert_eq!(efi.path, "/dev/vda2");
    assert_eq!(efi.used_percent, 7);
    assert_eq!(efi.size, 192559);

    // udev on /dev used to be reported. It is 0 B used of a size that is just
    // the RAM the kernel would let it take, on a mount holding device nodes.
    assert!(!disks.iter().any(|d| d.mount == "/dev"));
}

/// A container host publishes one devtmpfs row per device node — 24 of them
/// here, every one 0 B used of the same 7.8 GB — plus shm, tmpfs and a bind
/// mount over /proc. None of it is storage.
#[test]
fn disk_parse_df_drops_kernel_mounts() {
    let disks = linux::parse_disk(include_str!("fixtures/df_orbstack.txt"));

    assert!(!disks.iter().any(|d| d.path == "devtmpfs"));
    assert!(!disks.iter().any(|d| d.mount.starts_with("/dev")));
    assert!(!disks.iter().any(|d| d.mount.starts_with("/proc")));
    assert!(!disks.iter().any(|d| d.path == "shm" || d.path == "tmpfs"));

    let root = disks.iter().find(|d| d.mount == "/").unwrap();
    assert_eq!(root.path, "/dev/vdb1");
    assert_eq!(root.used_percent, 9);
    assert_eq!(root.size, 235798528);

    // The virtiofs share is real storage and stays, wherever it is mounted
    assert!(disks.iter().any(|d| d.path == "mac" && d.mount == "/mnt/mac"));
}

/// One filesystem published under many paths is one row: `/dev/vdb1` appears
/// 14 times in this `df` (once as `/`, then per container volume), `mac` six
/// times, all with identical numbers.
#[test]
fn disk_parse_df_collapses_repeated_mounts() {
    let disks = linux::parse_disk(include_str!("fixtures/df_orbstack.txt"));

    assert_eq!(disks.len(), 5);
    assert_eq!(disks[0].path, "/dev/vdb1");
    assert_eq!(
        disks[0].mount, "/",
        "the first mount df lists is the one kept"
    );
    assert_eq!(disks.iter().filter(|d| d.path == "/dev/vdb1").count(), 1);
    assert_eq!(disks.iter().filter(|d| d.path == "mac").count(), 1);

    // Same source, different numbers, so not the same filesystem: the tmpfs
    // orbstack mounts differ in what is used and both survive
    let orbstack: Vec<_> = disks.iter().filter(|d| d.path == "orbstack").collect();
    assert_eq!(orbstack.len(), 2);
    assert_ne!(orbstack[0].used, orbstack[1].used);
}

/// Dart 'parse ImmortalWrt df -k output without shrinking units'
#[test]
fn disk_parse_immortalwrt() {
    let disks = linux::parse_disk(include_str!("fixtures/df_immortalwrt.txt"));
    let data = disks.iter().find(|d| d.mount == "/mnt/sda").unwrap();
    assert_eq!(data.path, "/dev/sda");
    assert_eq!(data.size, 468851544);
    assert_eq!(data.used, 465106484);
    assert_eq!(data.avail, 1960492);
    assert_eq!(data.used_percent, 100);
}

/// Dart 'parse Debian df -k output preserves KB values'
#[test]
fn disk_parse_debian() {
    let disks = linux::parse_disk(include_str!("fixtures/df_debian.txt"));
    let root = disks.iter().find(|d| d.mount == "/").unwrap();
    assert_eq!(root.path, "/dev/sda2");
    assert_eq!(root.used_percent, 36);
    assert_eq!(root.size, 474286144);
    assert_eq!(root.used, 158343564);
    assert_eq!(root.avail, 291776744);

    let efi = disks.iter().find(|d| d.mount == "/boot/efi").unwrap();
    assert_eq!(efi.path, "/dev/sda1");
    assert_eq!(efi.used_percent, 1);
    assert_eq!(efi.size, 997432);
}

/// Dart 'handle empty/whitespace input gracefully'
#[test]
fn disk_parse_empty() {
    assert!(linux::parse_disk("").is_empty());
    assert!(linux::parse_disk("   \n\t  \r\n  ").is_empty());
}

/// Dart 'handle JSON with null/"null"/empty/invalid fields gracefully'
#[test]
fn disk_parse_lsblk_degenerate_fields() {
    for fields in [
        r#""fssize": null, "fsused": null, "fsavail": null, "fsuse%": null"#,
        r#""fssize": "null", "fsused": "null", "fsavail": "null", "fsuse%": "null""#,
        r#""fssize": "", "fsused": "", "fsavail": "", "fsuse%": """#,
        r#""fssize": "not_a_number", "fsused": "invalid", "fsavail": "broken", "fsuse%": "bad""#,
    ] {
        let raw = format!(
            r#"{{"blockdevices": [{{"fstype": "ext4", "mountpoint": "/", "path": "/dev/sda1", {}}}]}}"#,
            fields
        );
        let disks = linux::parse_disk(&raw);
        assert_eq!(disks.len(), 1, "input: {}", fields);
        let d = &disks[0];
        assert_eq!((d.size, d.used, d.avail, d.used_percent), (0, 0, 0, 0));
    }
}

/// macOS df -k has 9 columns (iused/ifree/%iused before the mount point);
/// the mount is the last column on both layouts
#[test]
fn disk_parse_df_macos_columns() {
    let raw = "\
Filesystem                          1024-blocks      Used Available Capacity iused      ifree %iused  Mounted on
/dev/disk3s1s1                        971298980  12276332 228035116     6%  458726 2280351160    0%   /
/dev/disk3s5                          971298980 719366920 228035116    76% 3607614 2280351160    2%   /System/Volumes/Data
devfs                                       223       223         0   100%     772          0  100%   /dev
";
    let disks = linux::parse_disk(raw);
    // devfs on /dev is a kernel mount like Linux's udev, and dropped with it
    assert_eq!(disks.len(), 2);
    assert_eq!(disks[0].mount, "/");
    assert_eq!(disks[0].used_percent, 6);
    assert_eq!(disks[1].mount, "/System/Volumes/Data");
    assert_eq!(disks[1].used, 719366920);
}

/// Dart 'handle JSON parsing errors gracefully': malformed JSON that isn't df → empty
#[test]
fn disk_parse_malformed_json() {
    let raw = r#"{"blockdevices": [ // broken"#;
    assert!(linux::parse_disk(raw).is_empty());
}

/// Dart 'handle lsblk with success marker'
#[test]
fn disk_parse_lsblk_success_marker() {
    let raw = r#"{"blockdevices": [{"fstype": "ext4", "mountpoint": "/", "path": "/dev/sda1", "fssize": 982141468672, "fsused": 552718364672, "fsavail": 379457622016, "fsuse%": "56%"}]}
LSBLK_SUCCESS"#;
    let disks = linux::parse_disk(raw);
    let root = disks.iter().find(|d| d.mount == "/").unwrap();
    assert_eq!(root.fs_type.as_deref(), Some("ext4"));
    assert_eq!(root.used_percent, 56);
}

/// Dart 'handle malformed lsblk output fallback': non-JSON prefix → df fallback
#[test]
fn disk_parse_df_fallback_when_not_json() {
    let disks = linux::parse_disk(include_str!("fixtures/df_k.txt"));
    assert_eq!(disks.len(), 2);
}

// ---------- Network: net_speed_test.dart ----------

/// Dart 'NetSpeed.parse with Linux format'
#[test]
fn net_parse_linux() {
    let raw = "\
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 45929941  269112    0    0    0     0          0         0 45929941  269112    0    0    0     0       0          0
  eth0: 48481023  505772    0    0    0     0          0         0 36002262  202307    0    0    0     0       0          0
  wlan0: 12345678  123456    0    0    0     0          0         0 87654321  123456    0    0    0     0       0          0
";
    let parts = linux::parse_net(raw);
    assert_eq!(parts.len(), 3);
    assert_eq!(parts[0].device, "lo");
    assert_eq!(parts[0].rx_bytes, 45929941);
    assert_eq!(parts[0].tx_bytes, 45929941);
    assert_eq!(parts[1].device, "eth0");
    assert_eq!(parts[1].rx_bytes, 48481023);
    assert_eq!(parts[1].tx_bytes, 36002262);
}

/// Dart 'NetSpeed.parseBsd with BSD format'
#[test]
fn net_parse_bsd() {
    let raw = "\
Name       Mtu   Network       Address            Ipkts Ierrs     Ibytes    Opkts Oerrs     Obytes  Coll
lo0        16384 <Link#1>      -              17296531     0 2524959720 17296531     0 2524959720     0
en0        1500  <Link#4>    22:20:xx:xx:xx:e6   739447     0  693997876   535600     0   79008877     0
en1        1500  <Link#5>    88:d8:xx:xx:xx:1d        0     0          0        0     0          0     0
";
    let parts = bsd::parse_net(raw);
    assert_eq!(parts.len(), 3);
    assert_eq!(parts[0].device, "lo0");
    assert_eq!(parts[0].rx_bytes, 2524959720);
    assert_eq!(parts[1].device, "en0");
    assert_eq!(parts[1].rx_bytes, 693997876);
    assert_eq!(parts[1].tx_bytes, 79008877);
    assert_eq!(parts[2].tx_bytes, 0);
}

/// Dart 'NetSpeed.parseBsd skips disabled devices'
#[test]
fn net_parse_bsd_skips_disabled() {
    let raw = "\
Name       Mtu   Network       Address            Ipkts Ierrs     Ibytes    Opkts Oerrs     Obytes  Coll
lo0        16384 <Link#1>      -              17296531     0 2524959720 17296531     0 2524959720     0
en2*       1500  <Link#11>   36:7c:xx:xx:xx:xx        0     0          0        0     0          0     0
en0        1500  <Link#4>    22:20:xx:xx:xx:e6   739447     0  693997876   535600     0   79008877     0
";
    let devices: Vec<String> = bsd::parse_net(raw).into_iter().map(|n| n.device).collect();
    assert_eq!(devices, ["lo0", "en0"]);
}

/// Dart 'NetSpeed speed calculations for specific device': +1000000B over 1000s → 1000 B/s
#[test]
fn net_speed_delta() {
    let pre = NetIface { device: "eth0".into(), rx_bytes: 1_000_000, tx_bytes: 500_000 };
    let now = NetIface { device: "eth0".into(), rx_bytes: 2_000_000, tx_bytes: 1_000_000 };
    let (rx, tx) = net_speed(&pre, &now, 1000.0).unwrap();
    assert_eq!(rx, 1000.0);
    assert_eq!(tx, 500.0);
    // Dart 'returns zero speed for equal timestamps'
    assert!(net_speed(&pre, &now, 0.0).is_none());
}

// ---------- Temperature: temp.dart ----------

#[test]
fn temps_parse_and_priority() {
    let types = "/sys/class/thermal/thermal_zone0/acpitz\n/sys/class/thermal/thermal_zone1/x86_pkg_temp";
    let values = "45000\n55000";
    let temps = linux::parse_temps(types, values, 1000.0);
    assert_eq!(temps.0.get("acpitz"), Some(&45.0));
    assert_eq!(temps.0.get("x86_pkg_temp"), Some(&55.0));
    // CPU device preferred (Dart `Temperatures.first`)
    assert_eq!(temps.first(), Some(55.0));
}

// ---------- Windows:windows_parser.dart ----------

/// Dart `WindowsParser.parseCpu`: single-processor map with summary head and per-logical-core split
#[test]
fn windows_parse_cpu_single() {
    let raw = r#"{"LoadPercentage": 25, "NumberOfCores": 2, "NumberOfLogicalProcessors": 4}"#;
    let cores = windows::parse_cpu(raw, &[]);
    // 1 summary + 4 logical cores
    assert_eq!(cores.len(), 5);
    assert_eq!(cores[0].id, "cpu");
    assert_eq!(cores[1].id, "cpu0");
    assert_eq!(cores[1].user, 25);
    assert_eq!(cores[1].idle, 75);
    // Summary equals the per-core sum
    assert_eq!(cores[0].user, 100);
    assert_eq!(cores[0].idle, 300);
}

/// Pseudo-accumulation: accumulates on top of the previous result when passed
#[test]
fn windows_parse_cpu_accumulates() {
    let raw = r#"{"LoadPercentage": 10, "NumberOfCores": 1, "NumberOfLogicalProcessors": 1}"#;
    let first = windows::parse_cpu(raw, &[]);
    let second = windows::parse_cpu(raw, &first);
    assert_eq!(second[1].user, 20);
    assert_eq!(second[1].idle, 180);
}

/// Dart `WindowsParser.parseMemory`: Win32_OperatingSystem is already KiB
#[test]
fn windows_parse_mem() {
    let raw = r#"[{"TotalVisibleMemorySize": 16777216, "FreePhysicalMemory": 8388608}]"#;
    let m = windows::parse_mem(raw).unwrap();
    assert_eq!(m.total, 16777216);
    assert_eq!(m.free, 8388608);
    assert_eq!(m.avail, 8388608);
}

/// Dart `WindowsParser.parseDisks`: bytes → KiB, missing fields skipped
#[test]
fn windows_parse_disks() {
    let raw = r#"[
        {"DeviceID": "C:", "Size": 512000000000, "FreeSpace": 256000000000, "FileSystem": "NTFS"},
        {"DeviceID": "D:", "Size": null, "FreeSpace": null, "FileSystem": null}
    ]"#;
    let disks = windows::parse_disks(raw);
    assert_eq!(disks.len(), 1);
    let c = &disks[0];
    assert_eq!(c.path, "C:");
    assert_eq!(c.size, 512000000000 / 1024);
    assert_eq!(c.avail, 256000000000 / 1024);
    assert_eq!(c.used, c.size - c.avail);
    assert_eq!(c.used_percent, 50);
    assert_eq!(c.fs_type.as_deref(), Some("NTFS"));
}

// ---- Real-device fixtures (Windows 11 Pro / 26200, captured on hardware) ----

/// Real Win32_Processor output: single CPU, 14 cores / 20 threads, 35% load
#[test]
fn windows_real_cpu() {
    let cores = windows::parse_cpu(include_str!("fixtures/win_cpu.json"), &[]);
    assert_eq!(cores.len(), 21); // summary + 20 logical cores
    assert_eq!(cores[0].id, "cpu");
    assert_eq!(cores[0].user, 35 * 20);
    assert_eq!(cores[0].idle, 65 * 20);
    assert_eq!(cores[1].user, 35);
}

/// Real Win32_OperatingSystem output (64GB physical memory)
#[test]
fn windows_real_mem() {
    let m = windows::parse_mem(include_str!("fixtures/win_mem.json")).unwrap();
    assert_eq!(m.total, 66874508);
    assert_eq!(m.free, 8798060);
}

/// Real Win32_LogicalDisk output (single C: NTFS 2TB volume)
#[test]
fn windows_real_disk() {
    let disks = windows::parse_disks(include_str!("fixtures/win_disk.json"));
    assert_eq!(disks.len(), 1);
    let c = &disks[0];
    assert_eq!(c.path, "C:");
    assert_eq!(c.fs_type.as_deref(), Some("NTFS"));
    assert_eq!(c.size, 2047328907264 / 1024);
    assert_eq!(c.avail, 587356827648 / 1024);
    assert_eq!(c.used_percent, 71);
}

/// Real MSAcpi_ThermalZoneTemperature output
#[test]
fn windows_real_temp() {
    let temps = windows::parse_temps(include_str!("fixtures/win_temp.json"));
    assert_eq!(temps.0.get(r"ACPI\ThermalZone\TZ00_0"), Some(&27.8));
}

/// A full volume (FreeSpace = 0) is a valid state and must not be dropped
#[test]
fn windows_parse_disks_keeps_full_volume() {
    let raw = r#"[
        {"DeviceID": "C:", "Size": 512000000000, "FreeSpace": 0, "FileSystem": "NTFS"}
    ]"#;
    let disks = windows::parse_disks(raw);
    assert_eq!(disks.len(), 1);
    assert_eq!(disks[0].avail, 0);
    assert_eq!(disks[0].used, disks[0].size);
    assert_eq!(disks[0].used_percent, 100);
}

/// Raw cumulative counters of the last sample group → NetIface (`_Total` skipped)
#[test]
fn windows_parse_net_last_sample() {
    let raw = r#"[
        [
            {"Name": "_Total", "BytesReceivedPersec": 100, "BytesSentPersec": 100, "Timestamp_Sys100NS": 10000000},
            {"Name": "Ethernet", "BytesReceivedPersec": 1000, "BytesSentPersec": 500, "Timestamp_Sys100NS": 10000000}
        ],
        [
            {"Name": "_Total", "BytesReceivedPersec": 300, "BytesSentPersec": 200, "Timestamp_Sys100NS": 20000000},
            {"Name": "Ethernet", "BytesReceivedPersec": 3000, "BytesSentPersec": 2000, "Timestamp_Sys100NS": 20000000}
        ]
    ]"#;
    let ifaces = windows::parse_net(raw);
    assert_eq!(ifaces.len(), 1);
    assert_eq!(ifaces[0].device, "Ethernet");
    assert_eq!(ifaces[0].rx_bytes, 3000);
    assert_eq!(ifaces[0].tx_bytes, 2000);
}

/// Real-device fixture: cumulative counters also extracted from the `{"value": [...]}` wrapper form
#[test]
fn windows_real_net_totals() {
    let ifaces = windows::parse_net(include_str!("fixtures/win_net.json"));
    assert_eq!(ifaces.len(), 5);
    for i in &ifaces {
        assert!(!i.device.is_empty() && i.device != "_Total");
    }
}

/// Real WMI double-sample output: 5 NICs, `{"value": [...], "Count"}` wrapper form
#[test]
fn windows_real_net_speed() {
    let speeds = windows::parse_net_speed(include_str!("fixtures/win_net.json"));
    assert_eq!(speeds.len(), 5);
    for (name, rx, tx) in &speeds {
        assert!(!name.is_empty() && name != "_Total");
        assert!(*rx >= 0.0 && *tx >= 0.0, "{}: rx={} tx={}", name, rx, tx);
    }
    // The active NIC (Wi-Fi) is present
    assert!(speeds.iter().any(|(n, _, _)| n.contains("Wi-Fi")));
}

/// Dart `_parseWindowsWmiDelta`: two-sample delta, `_Total` skipped, 100ns timestamps
#[test]
fn windows_parse_net_speed_delta() {
    let raw = r#"[
        [
            {"Name": "_Total", "BytesReceivedPersec": 0, "BytesSentPersec": 0, "Timestamp_Sys100NS": 10000000},
            {"Name": "Ethernet", "BytesReceivedPersec": 1000, "BytesSentPersec": 500, "Timestamp_Sys100NS": 10000000}
        ],
        [
            {"Name": "_Total", "BytesReceivedPersec": 99, "BytesSentPersec": 99, "Timestamp_Sys100NS": 20000000},
            {"Name": "Ethernet", "BytesReceivedPersec": 3000, "BytesSentPersec": 1500, "Timestamp_Sys100NS": 20000000}
        ]
    ]"#;
    let speeds = windows::parse_net_speed(raw);
    assert_eq!(speeds.len(), 1);
    let (name, rx, tx) = &speeds[0];
    assert_eq!(name, "Ethernet");
    // 1s interval (10000000 * 100ns), deltas 2000/1000
    assert_eq!(*rx, 2000.0);
    assert_eq!(*tx, 1000.0);
}

// ---------- Conn:conn_test.dart ----------

/// Dart 'Conn.parse reads MaxConn and AttemptFails from /proc/net/snmp'
#[test]
fn conn_parse() {
    let raw = "Tcp: RtoAlgorithm RtoMin RtoMax MaxConn ActiveOpens PassiveOpens AttemptFails EstabResets CurrEstab InSegs OutSegs RetransSegs InErrs OutRsts InCsumErrors\nTcp: 1 200 120000 -1 11 22 33 44 55 66 77 88 99 111 222";
    let conn = linux::parse_conn(raw).unwrap();
    assert_eq!(conn.max_conn, -1);
    assert_eq!(conn.fail, 33);
}

/// Dart 'Conn.parse rejects truncated/non-numeric TCP rows'
#[test]
fn conn_parse_invalid() {
    assert!(linux::parse_conn("Tcp: 1 2 3").is_none());
    assert!(linux::parse_conn("Tcp: 1 200 120000 unknown 11 22 invalid 44").is_none());
}

// ---------- Uptime:uptime_test.dart ----------

#[test]
fn uptime_parse_formats() {
    use sbm_parser::common::parse_uptime;
    let cases = [
        ("19:39:15 up 61 days, 18:16,  1 user,  load average: 0.00, 0.00, 0.00", Some("61 days, 18:16")),
        ("19:39:15 up 1 day, 2:34,  1 user,  load average: 0.00, 0.00, 0.00", Some("1 day, 2:34")),
        ("19:39:15 up 2:34,  1 user,  load average: 0.00, 0.00, 0.00", Some("2:34")),
        ("19:39:15 up 34 min,  1 user,  load average: 0.00, 0.00, 0.00", Some("34 min")),
        ("19:39:15 up 5 days,  1 user,  load average: 0.00, 0.00, 0.00", Some("5 days")),
        ("invalid uptime format", None),
        ("", None),
    ];
    for (raw, expect) in cases {
        assert_eq!(parse_uptime(raw).as_deref(), expect, "input: {:?}", raw);
    }
}

// ---------- DiskIO:disk.dart DiskIO.parse ----------

#[test]
fn diskio_parse() {
    let raw = "\
   7       0 loop0 55 0 2170 42 0 0 0 0 0 80 42 0 0 0 0 0 0
 259       0 nvme0n1 1234 0 567890 100 4321 0 98765 200 0 300 400 0 0 0 0 0 0
   8       0 sda 111 0 22222 10 333 0 44444 20 0 30 40 0 0 0 0 0 0";
    let pieces = linux::parse_diskio(raw);
    assert_eq!(pieces.len(), 2); // loop devices skipped
    assert_eq!(pieces[0].dev, "nvme0n1");
    assert_eq!(pieces[0].sectors_read, 567890);
    assert_eq!(pieces[0].sectors_write, 98765);
    assert_eq!(pieces[1].dev, "sda");
}

// ---------- Battery: battery_test.dart ----------

/// Dart 'parse battery': all 7 power_supply blocks parsed (no filtering)
#[test]
fn battery_parse_seven_supplies() {
    let raw = include_str!("fixtures/power_supply.txt");
    let all = linux::parse_batteries(raw, false);
    assert_eq!(all.len(), 7);

    // First block: 73%, discharging, Li-poly, cycle 1
    let first = &all[0];
    assert_eq!(first.percent, Some(73));
    assert_eq!(first.status, BatteryStatus::Discharging);
    assert_eq!(first.tech.as_deref(), Some("Li-poly"));
    assert_eq!(first.cycle, Some(1));
    assert!(first.is_li_poly());

    // The app's actual call keeps Li-poly only
    let li_poly = linux::parse_batteries(raw, true);
    assert_eq!(li_poly.len(), 1);
}

/// Windows Win32_Battery(server_status_update_req._parseWindowsBatteries)
#[test]
fn battery_parse_windows() {
    let raw = r#"{"EstimatedChargeRemaining": 88, "BatteryStatus": 6}"#;
    let batteries = windows::parse_batteries(raw);
    assert_eq!(batteries.len(), 1);
    assert_eq!(batteries[0].percent, Some(88));
    assert_eq!(batteries[0].status, BatteryStatus::Charging);
}

// ---------- Sensors:sensors_test.dart ----------

/// Dart 'parse sensors1'
#[test]
fn sensors_parse_1() {
    let sensors = linux::parse_sensors(include_str!("fixtures/sensors1.txt"));
    let devices: Vec<&str> = sensors.iter().map(|s| s.device.as_str()).collect();
    assert_eq!(devices, ["coretemp-isa-0000", "acpitz-acpi-0", "iwlwifi_1-virtual-0", "nvme-pci-0400"]);
    let adapters: Vec<&str> = sensors.iter().map(|s| s.adapter.as_str()).collect();
    assert_eq!(adapters, ["ISA adapter", "ACPI interface", "Virtual device", "PCI adapter"]);
    let summaries: Vec<Option<&str>> = sensors.iter().map(|s| s.summary()).collect();
    assert_eq!(summaries, [
        Some("+56.0°C  (high = +105.0°C, crit = +105.0°C)"),
        Some("+27.8°C  (crit = +119.0°C)"),
        Some("+56.0°C"),
        Some("+45.9°C  (low  = -273.1°C, high = +83.8°C)"),
    ]);
}

/// Dart 'parse sensors2'
#[test]
fn sensors_parse_2() {
    let sensors = linux::parse_sensors(include_str!("fixtures/sensors2.txt"));
    let devices: Vec<&str> = sensors.iter().map(|s| s.device.as_str()).collect();
    assert_eq!(devices, ["asusec-isa-0000", "nct6798-isa-0290", "nvme-pci-0400", "k10temp-pci-00c3"]);
    let summaries: Vec<Option<&str>> = sensors.iter().map(|s| s.summary()).collect();
    assert_eq!(summaries, [
        Some("1.26 V"),
        Some("1.19 V  (min =  +0.00 V, max =  +1.74 V)"),
        Some("+45.9°C  (low  = -273.1°C, high = +69.8°C)"),
        Some("+44.9°C"),
    ]);
}

/// Win32_TemperatureProbe(no Dart reference; new Windows-only parser)
#[test]
fn sensors_parse_windows() {
    let raw = r#"[{"Name": "CPU Probe", "CurrentReading": 3033}, {"Name": null, "CurrentReading": 3001}]"#;
    let sensors = windows::parse_sensors(raw);
    assert_eq!(sensors.len(), 2);
    assert_eq!(sensors[0].device, "CPU Probe");
    assert_eq!(sensors[0].summary(), Some("30.2\u{b0}C"));
    // Null Name falls back to a generic label instead of an empty string
    assert_eq!(sensors[1].device, "Temperature Probe");
    assert_eq!(sensors[1].summary(), Some("27.0\u{b0}C"));
}

/// Get-StorageReliabilityCounter(no Dart reference; new Windows-only parser)
#[test]
fn disk_smart_parse_windows() {
    let raw = r#"[{"DeviceId": "0", "Temperature": 38, "TemperatureMax": 55, "Wear": 2, "PowerOnHours": 1200}]"#;
    let disks = windows::parse_disk_smart(raw);
    assert_eq!(disks.len(), 1);
    assert_eq!(disks[0].device, "0");
    assert_eq!(disks[0].temperature, Some(38.0));
    assert_eq!(disks[0].power_on_hours, Some(1200));
    // No pass/fail flag in this cmdlet's output — must not be fabricated
    assert_eq!(disks[0].healthy, None);
}

// ---------- NVIDIA:nvidia_test.dart ----------

/// Dart 'nvdia-smi' (inline fixture)
#[test]
fn nvidia_parse_inline() {
    let items = sbm_parser::gpu::nvidia_from_xml(include_str!("fixtures/nvidia_inline.xml"));
    assert_eq!(items.len(), 1);
    let item = &items[0];
    assert_eq!(item.name, "NVIDIA GeForce RTX 3080 Ti");
    assert_eq!(item.temp, 34);
    assert_eq!(item.power, "24.55 W / 350.00 W");
    assert_eq!(item.memory.total, 12288);
    assert_eq!(item.memory.used, 352);
    assert_eq!(item.memory.unit, "MiB");
    let procs = &item.memory.processes;
    assert_eq!(procs.len(), 3);
    assert_eq!(procs[0].pid, 1575);
    assert_eq!(procs[0].name, "/usr/lib/xorg/Xorg");
    assert_eq!(procs[0].memory, 220);
    assert_eq!(procs[1].pid, 1933);
    assert_eq!(procs[1].name, "/usr/bin/gnome-shell");
    assert_eq!(procs[1].memory, 34);
    assert_eq!(procs[2].pid, 16484);
    assert_eq!(procs[2].memory, 76);
}

/// Dart 'nvidia-smi with N/A':4 GPU
#[test]
fn nvidia_parse_multi_gpu() {
    let items = sbm_parser::gpu::nvidia_from_xml(include_str!("fixtures/nvidia.xml"));
    assert_eq!(items.len(), 4);
}

/// Dart 'nvidia-smi 2':1 GPU
#[test]
fn nvidia_parse_v2_format() {
    let items = sbm_parser::gpu::nvidia_from_xml(include_str!("fixtures/nvidia2.xml"));
    assert_eq!(items.len(), 1);
}

// ---------- AMD:amd_smi_test.dart ----------

#[test]
fn amd_parse_two_gpus() {
    let raw = r#"[
        {
            "name": "AMD Radeon RX 7900 XTX",
            "temp": 45,
            "power_draw": 120,
            "power_cap": 355,
            "memory": {
                "total": 24576,
                "used": 1024,
                "unit": "MB",
                "processes": [
                    {"pid": 2456, "name": "firefox", "memory": 512},
                    {"pid": 3784, "name": "blender", "memory": 256}
                ]
            },
            "utilization": 75,
            "fan_speed": 1200,
            "clock_speed": 2400
        },
        {
            "card_model": "AMD Radeon RX 6800 XT",
            "gpu_temp": "38°C",
            "current_power": "85W",
            "power_limit": "300W",
            "vram": {"total_memory": 16384, "used_memory": 512},
            "gpu_util": 25,
            "fan_rpm": 800,
            "sclk": 1800
        }
    ]"#;
    let gpus = sbm_parser::gpu::amd_from_json(raw);
    assert_eq!(gpus.len(), 2);

    let g1 = &gpus[0];
    assert_eq!(g1.name, "AMD Radeon RX 7900 XTX");
    assert_eq!(g1.temp, 45);
    assert_eq!(g1.power, "120W / 355W");
    assert_eq!(g1.memory.total, 24576);
    assert_eq!(g1.memory.used, 1024);
    assert_eq!(g1.memory.unit, "MB");
    assert_eq!(g1.memory.processes.len(), 2);
    assert_eq!(g1.memory.processes[0].pid, 2456);
    assert_eq!(g1.memory.processes[0].name, "firefox");
    assert_eq!(g1.memory.processes[0].memory, 512);
    assert_eq!(g1.utilization, 75);
    assert_eq!(g1.fan_speed, 1200);
    assert_eq!(g1.clock_speed, 2400);

    let g2 = &gpus[1];
    assert_eq!(g2.name, "AMD Radeon RX 6800 XT");
    assert_eq!(g2.temp, 38);
    assert_eq!(g2.power, "85W / 300W");
    assert_eq!(g2.memory.total, 16384);
    assert_eq!(g2.memory.used, 512);
    assert_eq!(g2.memory.unit, "MB");
    assert!(g2.memory.processes.is_empty());
    assert_eq!(g2.utilization, 25);
}

/// Dart: non-array / invalid JSON → empty
#[test]
fn amd_parse_invalid() {
    assert!(sbm_parser::gpu::amd_from_json("not json").is_empty());
    assert!(sbm_parser::gpu::amd_from_json(r#"{"name": "x"}"#).is_empty());
    assert!(sbm_parser::gpu::amd_from_json("No AMD GPU monitoring tools found").is_empty());
}

// ---------- SMART:disk_smart_test.dart ----------

#[test]
fn smart_parse_fixture() {
    let disks = sbm_parser::smart::parse(include_str!("fixtures/smartctl.json"));
    assert_eq!(disks.len(), 1);
    let d = &disks[0];
    assert_eq!(d.device, "/dev/sda");
    assert_eq!(d.temperature, Some(35.0));
    assert_eq!(d.power_on_hours, Some(17472));
    assert_eq!(d.power_cycle_count, Some(1948));
    assert!(!d.smart_attributes.is_empty());

    let temp_attr = d.smart_attributes.get("Temperature_Celsius").unwrap();
    assert_eq!(temp_attr.value, Some(65));
    assert_eq!(temp_attr.worst, Some(39));
    assert_eq!(temp_attr.raw_string.as_deref(), Some("35 (Min/Max 14/61)"));
    assert!(temp_attr.flags.prefailure);
    assert!(temp_attr.flags.updated_online);
    assert!(!temp_attr.flags.performance);

    let power_on = d.smart_attributes.get("Power_On_Hours").unwrap();
    assert_eq!(power_on.raw_value.as_i64(), Some(17472));

    assert!(!d.smart_attributes.contains_key("NonExistent"));
    assert_eq!(
        d.smart_attributes.get("SSD_Life_Left").and_then(|a| a.raw_value.as_i64()),
        Some(93)
    );
    assert_eq!(
        d.smart_attributes.get("Lifetime_Writes_GiB").and_then(|a| a.raw_value.as_i64()),
        Some(11520)
    );
    assert_eq!(
        d.smart_attributes.get("Lifetime_Reads_GiB").and_then(|a| a.raw_value.as_i64()),
        Some(12361)
    );
}

/// macOS's `/dev/diskN` whole-disk naming (no Dart reference — Bsd never
/// had a smartctl command before; this is a real captured `smartctl -a -j`
/// against an Apple Silicon internal NVMe SSD, serial redacted). Locks in
/// that `is_physical_disk` accepts this device-name shape and that NVMe's
/// top-level fields (no `ata_smart_attributes` table at all) still populate
/// health/temperature/power-on/cycle-count via the same fallback paths the
/// Linux NVMe case already exercises.
#[test]
fn smart_parse_macos_nvme() {
    let disks = sbm_parser::smart::parse(include_str!("fixtures/smartctl_macos.json"));
    assert_eq!(disks.len(), 1);
    let d = &disks[0];
    assert_eq!(d.device, "/dev/disk0");
    assert_eq!(d.healthy, Some(true));
    assert_eq!(d.temperature, Some(46.0));
    assert_eq!(d.model.as_deref(), Some("APPLE SSD AP1024Z"));
    assert_eq!(d.serial.as_deref(), Some("REDACTED0000"));
    assert_eq!(d.power_on_hours, Some(531));
    assert_eq!(d.power_cycle_count, Some(145));
    // NVMe output has no ATA attribute table at all
    assert!(d.smart_attributes.is_empty());
}

/// `-n standby` (see the `diskSmart` command) makes smartctl exit before it
/// reads anything, and a device it cannot open behaves the same way: both
/// print a JSON block naming the device with no reading in it. Neither may
/// surface as a disk with every field blank. No Dart reference — the Dart
/// implementation predates `-n standby`.
#[test]
fn smart_skips_blocks_without_a_reading() {
    let standby = r#"{
      "smartctl": {
        "messages": [{ "string": "Device is in STANDBY mode, exit(2)", "severity": "information" }],
        "exit_status": 2
      },
      "device": { "name": "/dev/sda", "type": "sat", "protocol": "ATA" }
    }"#;
    assert!(sbm_parser::smart::parse(standby).is_empty());

    // Bit 2 alone ("some SMART command failed") is a partial read, not a
    // skipped one — the macOS fixture exits with 4 and must still parse
    let partial = r#"{
      "smartctl": { "exit_status": 4 },
      "device": { "name": "/dev/sda" },
      "model_name": "Some Disk"
    }"#;
    assert_eq!(sbm_parser::smart::parse(partial).len(), 1);
}

// ---------- Btrfs RAID:btrfs_test.dart ----------

#[test]
fn disk_parse_btrfs_raid() {
    let disks = linux::parse_disk(include_str!("fixtures/lsblk_btrfs.json"));
    assert_eq!(disks.len(), 2);
    let nvme1 = disks.iter().find(|d| d.path.contains("nvme1n1")).unwrap();
    let nvme2 = disks.iter().find(|d| d.path.contains("nvme2n1")).unwrap();
    // RAID members share one filesystem UUID
    assert_eq!(nvme1.uuid, nvme2.uuid);
    // DiskUsage semantics: both physical disks counted
    let (used, size) = disk_usage(&disks);
    assert_eq!(size, nvme1.size + nvme2.size);
    assert_eq!(used, nvme1.used + nvme2.used);
}

// ---------- Common text: server_status_update_req.dart ----------

#[test]
fn sys_version_and_hostname() {
    use sbm_parser::common::*;
    assert_eq!(
        parse_sys_version("PRETTY_NAME=\"Ubuntu 22.04.3 LTS\"\n").as_deref(),
        Some("Ubuntu 22.04.3 LTS")
    );
    assert_eq!(parse_sys_version("no equals here"), None);
    assert_eq!(parse_hostname("  myhost \n").as_deref(), Some("myhost"));
    assert_eq!(parse_hostname("   "), None);
}

/// The `sys` command prints three keys now, and the two new ones are what
/// picks a distribution's mark — `PRETTY_NAME` is only what a person reads.
#[test]
fn os_release_keys() {
    use sbm_parser::common::*;
    let raw = "ID=linuxmint\nID_LIKE=\"ubuntu debian\"\nPRETTY_NAME=\"Linux Mint 21.3\"\n";

    assert_eq!(parse_os_id(raw).as_deref(), Some("linuxmint"));
    assert_eq!(parse_os_id_like(raw), vec!["ubuntu", "debian"]);
    assert_eq!(parse_sys_version(raw).as_deref(), Some("Linux Mint 21.3"));
}

/// An empty `ID_LIKE` is written out rather than omitted — NixOS 25.11 does,
/// measured — and must not become a base named "".
#[test]
fn os_release_empty_id_like() {
    use sbm_parser::common::*;
    let raw = "ID=nixos\nID_LIKE=\"\"\nPRETTY_NAME=\"NixOS 25.11 (Xantusia)\"\n";

    assert_eq!(parse_os_id(raw).as_deref(), Some("nixos"));
    assert_eq!(parse_os_id_like(raw), Vec::<String>::new());
}

/// A double-quoted value is shell-quoted, so its backslash escapes are not
/// part of the value. They used to reach the status card as written.
#[test]
fn os_release_unescapes_double_quoted() {
    use sbm_parser::common::*;
    let raw = "PRETTY_NAME=\"Foo \\\"Bar\\\" Linux \\\\ 1.0\"\n";
    assert_eq!(
        parse_sys_version(raw).as_deref(),
        Some(r#"Foo "Bar" Linux \ 1.0"#)
    );

    // Only the four the shell escapes. Everything else keeps its backslash,
    // the way the shell leaves it.
    assert_eq!(
        parse_sys_version("PRETTY_NAME=\"a\\nb\"\n").as_deref(),
        Some(r"a\nb")
    );

    // Single quotes have no escapes in shell, and none here.
    assert_eq!(
        parse_sys_version("PRETTY_NAME='a\\nb'\n").as_deref(),
        Some(r"a\nb")
    );
}

/// `ID` must not be found inside `ID_LIKE`: the prefix alone matches, and
/// reading `_LIKE=debian` as this machine's own id would name a distribution
/// that does not exist.
#[test]
fn os_release_id_is_not_id_like() {
    use sbm_parser::common::*;
    assert_eq!(parse_os_id("ID_LIKE=debian\n").as_deref(), None);
    assert_eq!(parse_os_id_like("ID=debian\n"), Vec::<String>::new());
}

/// `/etc/os-release` is usually a symlink to `/usr/lib/os-release`, so the
/// command prints every key twice. os-release gives `/etc` precedence, which
/// here is the first occurrence.
#[test]
fn os_release_first_occurrence_wins() {
    use sbm_parser::common::*;
    let raw = "ID=rhel\nPRETTY_NAME=\"RHEL 9.4\"\nID=fedora\nPRETTY_NAME=\"Fedora 40\"\n";

    assert_eq!(parse_os_id(raw).as_deref(), Some("rhel"));
    assert_eq!(parse_sys_version(raw).as_deref(), Some("RHEL 9.4"));
}

/// A remote too old for os-release answers through the `/etc/*-release`
/// fallback, which has only the prose line. Everything else stays absent
/// rather than becoming a wrong guess.
#[test]
fn os_release_absent_leaves_only_pretty_name() {
    use sbm_parser::common::*;
    let raw = "PRETTY_NAME=\"Debian GNU/Linux 12 (bookworm)\"\n";

    assert_eq!(parse_sys_version(raw).as_deref(), Some("Debian GNU/Linux 12 (bookworm)"));
    assert_eq!(parse_os_id(raw), None);
    assert_eq!(parse_os_id_like(raw), Vec::<String>::new());
}

/// Unquoted values are legal, and the whole block reaches the parser through
/// `parse_status`, not just the isolated helpers.
#[test]
fn os_release_through_parse_status() {
    let raw = HashMap::from([(
        commands::SYS.to_string(),
        "ID=alpine\nPRETTY_NAME=Alpine Linux v3.20\n".to_string(),
    )]);
    let status = sbm_parser::parse_status(SystemType::Linux, &raw);

    assert_eq!(status.os_id.as_deref(), Some("alpine"));
    assert_eq!(status.sys.as_deref(), Some("Alpine Linux v3.20"));
}

/// Bsd and Windows have no os-release, and their `sys` command output must not
/// be mined for one — `uname -or` prints `24.5.0 Darwin`, which has no `=` in
/// it at all, but a future command's output might.
#[test]
fn os_id_is_linux_only() {
    for (system, sys) in [
        (SystemType::Bsd, "24.5.0 Darwin"),
        (SystemType::Windows, "Microsoft Windows 11 Pro"),
    ] {
        let raw = HashMap::from([(commands::SYS.to_string(), sys.to_string())]);
        let status = sbm_parser::parse_status(system, &raw);

        assert_eq!(status.sys.as_deref(), Some(sys));
        assert_eq!(status.os_id, None);
        assert!(status.os_id_like.is_empty());
    }
}

#[test]
fn cpu_brand_parse() {
    let raw = "model name\t: Intel(R) Xeon(R) CPU E5-2680 v4 @ 2.40GHz\nmodel name\t: Intel(R) Xeon(R) CPU E5-2680 v4 @ 2.40GHz";
    let brands = linux::parse_cpu_brand(raw);
    assert_eq!(brands.len(), 1);
    assert_eq!(brands[0].0, "Intel(R) Xeon(R) CPU E5-2680 v4 @ 2.40GHz");
    assert_eq!(brands[0].1, 2);
}

/// Ported from `test/windows_test.dart`, which upstream added while this
/// branch had already replaced `WindowsParser` with this module. The Dart
/// tests are the spec; the behaviour they pin down was missing here, and the
/// `free > size` case underflowed `size - free`.
#[test]
fn windows_mem_rejects_missing_and_impossible_values() {
    assert!(windows::parse_mem("{}").is_none());
    assert!(
        windows::parse_mem(r#"{"TotalVisibleMemorySize":0,"FreePhysicalMemory":0}"#).is_none(),
        "a zero total divides by zero in every percentage derived from it"
    );
    assert!(
        windows::parse_mem(r#"{"TotalVisibleMemorySize":100,"FreePhysicalMemory":200}"#).is_none(),
        "more free than total is not a reading"
    );

    let m = windows::parse_mem(r#"{"TotalVisibleMemorySize":100,"FreePhysicalMemory":20}"#)
        .expect("a plausible pair is accepted");
    assert_eq!(m.total, 100);
    assert_eq!(m.free, 20);
}

#[test]
fn windows_disks_accept_full_volumes_and_reject_bad_ranges() {
    let full = windows::parse_disks(
        r#"{"DeviceID":"C:","Size":1024,"FreeSpace":0,"FileSystem":"NTFS"}"#,
    );
    assert_eq!(full.len(), 1, "a full volume is a valid reading");
    assert_eq!(full[0].avail, 0);
    assert_eq!(full[0].used_percent, 100);

    assert!(
        windows::parse_disks(
            r#"{"DeviceID":"C:","Size":1024,"FreeSpace":2048,"FileSystem":"NTFS"}"#
        )
        .is_empty(),
        "more free than total would underflow size - free"
    );
}

/// Also ported from `test/windows_test.dart`. A processor entry whose load is
/// out of range is dropped rather than clamped: 150 and -1 both mean the query
/// failed, and both a pegged and an idle reading would be invented.
#[test]
fn windows_cpu_rejects_invalid_ranges_and_core_counts() {
    for raw in [
        r#"{"LoadPercentage":150,"NumberOfCores":4,"NumberOfLogicalProcessors":8}"#,
        r#"{"LoadPercentage":-1,"NumberOfCores":4,"NumberOfLogicalProcessors":8}"#,
        r#"{"LoadPercentage":50,"NumberOfCores":0,"NumberOfLogicalProcessors":0}"#,
    ] {
        assert!(windows::parse_cpu(raw, &[]).is_empty(), "accepted {raw}");
    }
}

/// Ported from `test/server_status_update_req_test.dart`. Win32_Battery's
/// enumeration has a distinct "fully charged" state; folding it into
/// discharging reported a battery on mains at 100% as draining.
#[test]
fn windows_battery_status_follows_the_win32_enumeration() {
    use sbm_parser::types::BatteryStatus;

    fn status_of(code: i64) -> BatteryStatus {
        let raw = format!(r#"{{"EstimatedChargeRemaining":100,"BatteryStatus":{code}}}"#);
        windows::parse_batteries(&raw).remove(0).status
    }

    assert_eq!(status_of(3), BatteryStatus::Full);
    for code in 6..=9 {
        assert_eq!(status_of(code), BatteryStatus::Charging, "code {code}");
    }
    assert_eq!(status_of(2), BatteryStatus::Unknown);
    assert_eq!(status_of(10), BatteryStatus::Unknown);
    assert_eq!(status_of(1), BatteryStatus::Discharging);
    assert_eq!(status_of(5), BatteryStatus::Discharging);
}
