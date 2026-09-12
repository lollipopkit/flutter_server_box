//! Output shapes real machines produce that were read wrongly or not at all.
//!
//! Unlike `hostile_input.rs` nothing here crashes: each case parsed, and
//! answered something that looked like a reading.

use sbm_parser::{bsd, linux};

/// `df` puts an overlong source on a line of its own and the columns on the
/// next. The buffered name belongs in front of those columns; it was written
/// *over* the first one instead, destroying the size and leaving five fields,
/// which the row-shape check then dropped. A stock Ubuntu LVM install is
/// exactly this case, so it reported no root filesystem at all.
#[test]
fn a_wrapped_df_row_keeps_its_columns() {
    let raw = "Filesystem                        1K-blocks     Used Available Use% Mounted on\n\
               /dev/mapper/ubuntu--vg-ubuntu--lv\n\
               \x20                                 30298176 10000000  18000000  36% /\n";

    let disks = linux::parse_disk(raw);
    assert_eq!(disks.len(), 1, "the root filesystem is missing");
    assert_eq!(disks[0].path, "/dev/mapper/ubuntu--vg-ubuntu--lv");
    assert_eq!(disks[0].mount, "/");
    assert_eq!(disks[0].size, 30298176);
    assert_eq!(disks[0].used, 10000000);
    assert_eq!(disks[0].avail, 18000000);
    assert_eq!(disks[0].used_percent, 36);
}

/// The buffered name applies to the next row only.
#[test]
fn a_wrapped_row_does_not_rename_the_rows_after_it() {
    let raw = "Filesystem 1K-blocks Used Available Use% Mounted on\n\
               /dev/mapper/ubuntu--vg-ubuntu--lv\n\
               \x20 30298176 10000000 18000000 36% /\n\
               /dev/sda2 1000000 400000 600000 40% /boot\n";

    let disks = linux::parse_disk(raw);
    assert_eq!(disks.len(), 2);
    assert_eq!(disks[1].path, "/dev/sda2");
    assert_eq!(disks[1].size, 1000000);
}

/// FreeBSD's `netstat -ibn` has an `Idrop` column between `Ierrs` and
/// `Ibytes`, so its rows are 12 wide where macOS's are 11. Only the macOS
/// width was accepted, which discarded every line and left a FreeBSD host
/// reporting no network at all.
#[test]
fn freebsd_netstat_has_a_twelfth_column() {
    let raw = "Name    Mtu Network       Address              Ipkts Ierrs Idrop     Ibytes    Opkts Oerrs     Obytes  Coll\n\
               em0    1500 <Link#1>      08:00:27:4e:66:a1  1234567     0     0  987654321  7654321     0  123456789     0\n";

    let ifaces = bsd::parse_net(raw);
    assert_eq!(ifaces.len(), 1);
    assert_eq!(ifaces[0].device, "em0");
    assert_eq!(ifaces[0].rx_bytes, 987654321);
    assert_eq!(ifaces[0].tx_bytes, 123456789);
}

/// An interface with no link-layer address leaves that column empty, so the
/// row is one narrower — 11 on FreeBSD, the same width as an addressed macOS
/// row. Counting the byte columns from the right reads both correctly.
#[test]
fn a_freebsd_interface_without_an_address_still_reads() {
    let raw = "Name    Mtu Network       Address              Ipkts Ierrs Idrop     Ibytes    Opkts Oerrs     Obytes  Coll\n\
               lo0   16384 <Link#2>                            4242     0     0     424242     1111     0     111111     0\n";

    let ifaces = bsd::parse_net(raw);
    assert_eq!(ifaces.len(), 1);
    assert_eq!(ifaces[0].rx_bytes, 424242);
    assert_eq!(ifaces[0].tx_bytes, 111111);
}

/// The names and the values come from two independent `cat` globs. A zone
/// whose `temp` cannot be read drops a line from one side only, and pairing
/// positionally then reports every later zone's temperature under the previous
/// zone's name — which is worse than reporting none, because nothing about it
/// looks wrong.
#[test]
fn a_missing_thermal_value_reports_no_temperatures() {
    let types = "acpitz\nx86_pkg_temp\niwlwifi_1\n";
    let values = "45000\n55000\n";

    let temps = linux::parse_temps(types, values, 1000.0);
    assert!(
        temps.0.is_empty(),
        "a shifted pairing is not a set of readings: {:?}",
        temps.0
    );
}

/// Trailing newlines are not a mismatch.
#[test]
fn an_uneven_trailing_newline_is_not_a_mismatch() {
    let temps = linux::parse_temps("acpitz\nx86_pkg_temp\n\n", "45000\n55000", 1000.0);
    assert_eq!(temps.0.get("acpitz"), Some(&45.0));
    assert_eq!(temps.0.get("x86_pkg_temp"), Some(&55.0));
}

/// /proc/stat's columns are `user nice system idle iowait irq softirq`. Field 2
/// was read as `sys` and field 3 as `nice`, so the server detail page's "sys"
/// row showed nice time — near zero on most machines — and real system time
/// was displayed nowhere. `total()` sums every field, which is why every
/// aggregate agreed with itself throughout.
#[test]
fn proc_stat_columns_are_user_nice_system() {
    let cores = linux::parse_cpu("cpu 100 5 300 400 10 1 2");
    assert_eq!(cores.len(), 1);
    assert_eq!(cores[0].user, 100);
    assert_eq!(cores[0].nice, 5);
    assert_eq!(cores[0].sys, 300);
    assert_eq!(cores[0].idle, 400);
    assert_eq!(cores[0].iowait, 10);
    assert_eq!(cores[0].irq, 1);
    assert_eq!(cores[0].softirq, 2);
    assert_eq!(cores[0].total(), 818);
}
