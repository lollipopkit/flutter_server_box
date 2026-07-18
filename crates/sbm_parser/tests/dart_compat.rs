//! Dart 实现行为一致性测试(ADR 0001「测试即规格」)
//!
//! 用例与 fixture 移植自 flutter_server_box `test/`
//! (cpu_test / memory_test / disk_test / net_speed_test),
//! 各测试注明对应的 Dart 用例。

use sbm_parser::types::*;
use sbm_parser::{bsd, linux, windows};

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

/// Dart 'Test Cpus calculation':两次采样差分,used ≈ 75%
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

/// Dart 'Test parseBsdCpu fallback clamps invalid percentages'
#[test]
fn cpu_parse_bsd_fallback_clamps() {
    let cores = bsd::parse_cpu("CPU fallback: -5.5% user, 150.2% sys, 101.9% idle");
    assert_eq!(cores[0].user, 0);
    assert_eq!(cores[0].sys, 100);
    assert_eq!(cores[0].idle, 100);
}

// ---------- 内存:memory_test.dart ----------

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

/// macOS 括号内含逗号的现代 top 输出(monitor 历史 bug 回归)
#[test]
fn mem_parse_bsd_macos_comma_in_parens() {
    let m = bsd::parse_mem("PhysMem: 61G used (6811M wired, 1251M compressor), 1867M unused.")
        .unwrap();
    assert_eq!(m.total, 61 * 1024 * 1024 + 1867 * 1024);
    assert_eq!(m.free, 1867 * 1024);
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

/// Dart `Swap.parse` 语义
#[test]
fn swap_parse_meminfo() {
    let raw = "SwapTotal:      2097148 kB\nSwapFree:       1048574 kB\nSwapCached:     1024 kB";
    let s = linux::parse_swap(raw).unwrap();
    assert_eq!(s.total, 2097148);
    assert_eq!(s.free, 1048574);
    assert_eq!(s.cached, 1024);
}

// ---------- 磁盘:disk_test.dart ----------

/// Dart 'parse lsblk JSON output':6 项(LVM2_member/ext4//swap/vfat/ext2/crypto_LUKS)
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

/// Dart 'parse df -k output (fallback mode)':3 项(udev、vda3、vda2;tmpfs 排除)
#[test]
fn disk_parse_df_k() {
    let disks = linux::parse_disk(include_str!("fixtures/df_k.txt"));
    assert_eq!(disks.len(), 3);

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

    let udev = disks.iter().find(|d| d.path == "udev").unwrap();
    assert_eq!(udev.mount, "/dev");
    assert_eq!(udev.size, 864088);
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

/// Dart 'handle JSON parsing errors gracefully':畸形 JSON 且非 df → 空
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

/// Dart 'handle malformed lsblk output fallback':非 JSON 开头 → df 回退
#[test]
fn disk_parse_df_fallback_when_not_json() {
    let disks = linux::parse_disk(include_str!("fixtures/df_k.txt"));
    assert_eq!(disks.len(), 3);
}

// ---------- 网络:net_speed_test.dart ----------

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

/// Dart 'NetSpeed speed calculations for specific device':1000s 内 +1000000B → 1000 B/s
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

// ---------- 温度:temp.dart ----------

#[test]
fn temps_parse_and_priority() {
    let types = "/sys/class/thermal/thermal_zone0/acpitz\n/sys/class/thermal/thermal_zone1/x86_pkg_temp";
    let values = "45000\n55000";
    let temps = linux::parse_temps(types, values, 1000.0);
    assert_eq!(temps.0.get("acpitz"), Some(&45.0));
    assert_eq!(temps.0.get("x86_pkg_temp"), Some(&55.0));
    // CPU 器件优先(Dart `Temperatures.first`)
    assert_eq!(temps.first(), Some(55.0));
}

// ---------- Windows:windows_parser.dart ----------

/// Dart `WindowsParser.parseCpu`:单处理器 Map,含汇总头与逐逻辑核分摊
#[test]
fn windows_parse_cpu_single() {
    let raw = r#"{"LoadPercentage": 25, "NumberOfCores": 2, "NumberOfLogicalProcessors": 4}"#;
    let cores = windows::parse_cpu(raw, &[]);
    // 1 汇总 + 4 逻辑核
    assert_eq!(cores.len(), 5);
    assert_eq!(cores[0].id, "cpu");
    assert_eq!(cores[1].id, "cpu0");
    assert_eq!(cores[1].user, 25);
    assert_eq!(cores[1].idle, 75);
    // 汇总为逐核之和
    assert_eq!(cores[0].user, 100);
    assert_eq!(cores[0].idle, 300);
}

/// 伪累计:传入上次结果时在其基础上累加
#[test]
fn windows_parse_cpu_accumulates() {
    let raw = r#"{"LoadPercentage": 10, "NumberOfCores": 1, "NumberOfLogicalProcessors": 1}"#;
    let first = windows::parse_cpu(raw, &[]);
    let second = windows::parse_cpu(raw, &first);
    assert_eq!(second[1].user, 20);
    assert_eq!(second[1].idle, 180);
}

/// Dart `WindowsParser.parseMemory`:Win32_OperatingSystem 已是 KiB
#[test]
fn windows_parse_mem() {
    let raw = r#"[{"TotalVisibleMemorySize": 16777216, "FreePhysicalMemory": 8388608}]"#;
    let m = windows::parse_mem(raw).unwrap();
    assert_eq!(m.total, 16777216);
    assert_eq!(m.free, 8388608);
    assert_eq!(m.avail, 8388608);
}

/// Dart `WindowsParser.parseDisks`:字节 → KiB,缺字段跳过
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

// ---- 真机 fixture(Windows 11 Pro / 26200,采集自实机)----

/// Win32_Processor 实机输出:单 CPU 14 核 20 线程,负载 35%
#[test]
fn windows_real_cpu() {
    let cores = windows::parse_cpu(include_str!("fixtures/win_cpu.json"), &[]);
    assert_eq!(cores.len(), 21); // 汇总 + 20 逻辑核
    assert_eq!(cores[0].id, "cpu");
    assert_eq!(cores[0].user, 35 * 20);
    assert_eq!(cores[0].idle, 65 * 20);
    assert_eq!(cores[1].user, 35);
}

/// Win32_OperatingSystem 实机输出(64GB 物理内存)
#[test]
fn windows_real_mem() {
    let m = windows::parse_mem(include_str!("fixtures/win_mem.json")).unwrap();
    assert_eq!(m.total, 66874508);
    assert_eq!(m.free, 8798060);
}

/// Win32_LogicalDisk 实机输出(单盘 C: NTFS 2TB)
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

/// MSAcpi_ThermalZoneTemperature 实机输出
#[test]
fn windows_real_temp() {
    let temps = windows::parse_temps(include_str!("fixtures/win_temp.json"));
    assert_eq!(temps.0.get(r"ACPI\ThermalZone\TZ00_0"), Some(&27.8));
}

/// WMI 双采样实机输出:5 网卡,`{"value": [...], "Count"}` 包装形态
#[test]
fn windows_real_net_speed() {
    let speeds = windows::parse_net_speed(include_str!("fixtures/win_net.json"));
    assert_eq!(speeds.len(), 5);
    for (name, rx, tx) in &speeds {
        assert!(!name.is_empty() && name != "_Total");
        assert!(*rx >= 0.0 && *tx >= 0.0, "{}: rx={} tx={}", name, rx, tx);
    }
    // 活跃网卡(Wi-Fi)存在
    assert!(speeds.iter().any(|(n, _, _)| n.contains("Wi-Fi")));
}

/// Dart `_parseWindowsWmiDelta`:双采样差分,跳过 `_Total`,100ns 时间戳
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
    // 1 秒间隔(10000000 * 100ns),差值 2000/1000
    assert_eq!(*rx, 2000.0);
    assert_eq!(*tx, 1000.0);
}
