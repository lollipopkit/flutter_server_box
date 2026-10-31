//! `lsblk` and `df` together (#1669): `linux::parse_disk` on the output of
//! `commands::DISK`, and `disk_usage` over what it makes of it.

use sbm_parser::commands;
use sbm_parser::linux::{self, DISK_DF_MARKER};
use sbm_parser::types::{Disk, DiskTotal, disk_total, disk_usage};

/// `lsblk` JSON and a `df` table as the command prints them.
fn output(lsblk: &str, df: &str) -> String {
    format!("{lsblk}\n{DISK_DF_MARKER}\n{df}")
}

fn find<'a>(disks: &'a [Disk], mount: &str) -> Option<&'a Disk> {
    disks.iter().find_map(|d| {
        if d.mount == mount {
            Some(d)
        } else {
            find(&d.children, mount)
        }
    })
}

#[test]
fn the_command_prints_the_marker_the_parser_splits_on() {
    let disk = commands::LINUX
        .iter()
        .find(|c| c.key == commands::DISK)
        .expect("a disk command");
    assert!(disk.cmd.contains(DISK_DF_MARKER), "{}", disk.cmd);
    // The agent's sampler runs `lsblk` itself, with these.
    let lsblk = format!("lsblk {} ", linux::LSBLK_ARGS.join(" "));
    assert!(disk.cmd.starts_with(&lsblk), "{}", disk.cmd);
}

/// A Proxmox VE host on LVM-thin, as the command printed it there: the root
/// volume stays under its physical volume with `df`'s numbers, the guests'
/// volumes (no filesystem) are not listed, and `df`'s `/etc/pve` — not a block
/// device `lsblk` knows — is added after the tree.
#[test]
fn a_pve_host_on_lvm() {
    let disks = linux::parse_disk(include_str!("fixtures/disk_pve_lvm.txt"));

    let root = find(&disks, "/").expect("root");
    assert_eq!(root.path, "/dev/mapper/pve-root");
    assert_eq!(root.fs_type.as_deref(), Some("ext4"));
    assert_eq!((root.size, root.used), (102626232, 15903040));
    assert!(root.uuid.is_some(), "lsblk's identity is kept");

    assert!(find(&disks, "/boot/efi").is_some());
    assert!(find(&disks, "/etc/pve").is_some());
    let mut paths = Vec::new();
    fn walk<'a>(disks: &'a [Disk], paths: &mut Vec<&'a str>) {
        for d in disks {
            paths.push(d.path.as_str());
            walk(&d.children, paths);
        }
    }
    walk(&disks, &mut paths);
    assert!(
        !paths.iter().any(|p| p.contains("vm--")),
        "guest volumes: {paths:?}"
    );

    assert_eq!(
        disk_usage(&disks, false),
        (15903040 + 9240 + 28, 102626232 + 1046512 + 131072)
    );
}

/// `df -kT`: the type column is read and does what an `lsblk` type does —
/// tmpfs and a squashfs image drop out by type, not only by name.
#[test]
fn a_typed_df_table() {
    let df = "Filesystem     Type     1K-blocks    Used Available Use% Mounted on\n\
        /dev/vda1      ext4      51343636 12057216  36648004  25% /\n\
        run            tmpfs       800412     1792    798620   1% /run\n\
        /dev/loop3     squashfs    296960   296960         0 100% /opt/app\n";
    let disks = linux::parse_disk(&output("", df));
    assert_eq!(disks.len(), 1, "{disks:?}");
    assert_eq!(disks[0].fs_type.as_deref(), Some("ext4"));
    assert_eq!((disks[0].size, disks[0].used), (51343636, 12057216));
}

/// No `lsblk` (busybox, OpenWrt) and no `-T`: the plain table alone.
#[test]
fn busybox_without_lsblk() {
    let df = "Filesystem           1K-blocks      Used Available Use% Mounted on\n\
        /dev/root               102400     51200     51200  50% /\n\
        tmpfs                    62244       100     62144   0% /tmp\n";
    let disks = linux::parse_disk(&output("", df));
    assert_eq!(disks.len(), 1);
    assert_eq!(disks[0].mount, "/");
    assert_eq!(disks[0].fs_type, None);
}

/// The monitor agent's sampler hands `df` over on its own, with no marker.
#[test]
fn df_alone_still_parses() {
    let df = "Filesystem     Type 1K-blocks    Used Available Use% Mounted on\n\
        /dev/vda1      ext4  51343636 12057216  36648004  25% /\n";
    let disks = linux::parse_disk(df);
    assert_eq!(disks.len(), 1);
    assert_eq!(disks[0].fs_type.as_deref(), Some("ext4"));
}

/// `df` under `LANG=zh_CN.UTF-8` (#1747): a translated header, with and
/// without the type column. Both used to be dropped whole, which left the
/// agent with a disk total of 0 and its disk rule never evaluated.
#[test]
fn a_translated_header_is_read_like_any_other() {
    let typed = "文件系统       类型       1K的块     已用     可用 已用% 挂载点\n\
        udev           devtmpfs   910160        0   910160    0% /dev\n\
        /dev/vda3      ext4     61549628 46179808 12639780   79% /\n\
        /dev/loop0     squashfs    75776    75776        0  100% /snap/core22/2955\n\
        /dev/vda2      vfat       192559    12045   180514    7% /boot/efi\n";
    let disks = linux::parse_disk(typed);
    let root = find(&disks, "/").expect("root");
    assert_eq!(root.fs_type.as_deref(), Some("ext4"));
    assert_eq!((root.size, root.used), (61549628, 46179808));
    assert!(find(&disks, "/snap/core22/2955").is_none(), "{disks:?}");

    let plain = "文件系统         1K的块     已用     可用 已用% 挂载点\n\
        /dev/vda3      61549628 46179808 12639780   79% /\n\
        /dev/vda2        192559    12045   180514    7% /boot/efi\n";
    let disks = linux::parse_disk(&output("", plain));
    let root = find(&disks, "/").expect("root");
    assert_eq!(root.fs_type, None);
    assert_eq!(root.size, 61549628);
}

/// An English header decides for the whole table. macOS names autofs maps
/// with a space, and rows like these outnumbering the disks once read as a
/// type column, which took the size off the root row and dropped it.
#[test]
fn a_spaced_source_is_not_a_type_column() {
    let df = "Filesystem     1024-blocks      Used Available Capacity iused ifree %iused  Mounted on\n\
        /dev/disk3s1s1   482797652  10759236 172384600     6%  425798 1723846000    0%   /\n\
        map auto_home            0         0         0   100%       0          0     -   /System/Volumes/Data/home\n\
        map -hosts               0         0         0   100%       0          0     -   /net\n\
        map -static              0         0         0   100%       0          0     -   /Volumes/static\n";
    let disks = linux::parse_disk(df);
    let root = find(&disks, "/").expect("root");
    assert_eq!(root.fs_type, None);
    assert_eq!(root.size, 482797652);
}

/// ZFS: every dataset reports its own used space and the pool's free space.
/// Summed per dataset, a 1 TB pool with three datasets read as 3 TB.
#[test]
fn zfs_datasets_count_their_pool_once() {
    let df = "Filesystem       Type 1K-blocks      Used Available Use% Mounted on\n\
        rpool/ROOT/pve-1 zfs   900000000 100000000 800000000  12% /\n\
        rpool/data       zfs   850000000  50000000 800000000   6% /rpool/data\n\
        rpool            zfs   800000128       128 800000000   1% /rpool\n\
        tank/media       zfs   600000000 400000000 200000000  67% /tank/media\n";
    let disks = linux::parse_disk(&output("", df));
    assert_eq!(disks.len(), 4);
    let rpool_used = 100000000 + 50000000 + 128;
    let tank_used = 400000000;
    assert_eq!(
        disk_usage(&disks, false),
        (
            rpool_used + tank_used,
            rpool_used + 800000000 + tank_used + 200000000
        )
    );
}

/// NFS and SMB are listed, and counted only when asked to: their size is the
/// other machine's.
#[test]
fn network_filesystems_are_listed_and_counted_on_request() {
    let df = "Filesystem          Type 1K-blocks    Used Available Use% Mounted on\n\
        /dev/vda1           ext4      1000      100       900  10% /\n\
        nas:/export/media   nfs4     50000    40000     10000  80% /mnt/media\n\
        //nas/share         cifs     20000    10000     10000  50% /mnt/share\n";
    let disks = linux::parse_disk(&output("", df));
    assert_eq!(disks.len(), 3);
    assert!(disks[1].is_network() && disks[2].is_network());
    assert_eq!(disk_usage(&disks, false), (100, 1000));
    assert_eq!(disk_usage(&disks, true), (100 + 40000 + 10000, 1000 + 50000 + 20000));

    // Without a type (`df -k`), by source.
    let df = "Filesystem        1K-blocks  Used Available Use% Mounted on\n\
        nas:/export/media     50000 40000     10000  80% /mnt/media\n";
    let disks = linux::parse_disk(&output("", df));
    assert!(disks[0].is_network());
}

/// In a container `lsblk` sees the host's devices with no filesystem numbers;
/// `df` has them, and the container's own overlay root is not storage.
#[test]
fn a_container_gets_its_numbers_from_df() {
    let lsblk = r#"{"blockdevices": [
        {"fstype": "ext4", "path": "/dev/sda1", "name": "sda1", "kname": "sda1",
         "mountpoint": null, "fssize": null, "fsused": null, "fsavail": null,
         "fsuse%": null, "uuid": "u-1"}
    ]}"#;
    let df = "Filesystem     Type    1K-blocks    Used Available Use% Mounted on\n\
        overlay        overlay  51343636 12057216  36648004  25% /\n\
        /dev/sda1      ext4     51343636 12057216  36648004  25% /etc/hosts\n";
    let disks = linux::parse_disk(&output(lsblk, df));
    assert_eq!(disks.len(), 1, "{disks:?}");
    assert_eq!(disks[0].path, "/dev/sda1");
    assert_eq!(disks[0].mount, "/etc/hosts");
    assert_eq!(disks[0].uuid.as_deref(), Some("u-1"));
    assert_eq!(disk_usage(&disks, false), (12057216, 51343636));
}

/// A device nothing is mounted from is listed, and adds nothing to the total
/// either way: there is no filesystem size to add.
#[test]
fn an_unmounted_device_is_listed_and_adds_nothing() {
    let lsblk = r#"{"blockdevices": [
        {"fstype": "ext4", "path": "/dev/vda1", "name": "vda1", "kname": "vda1",
         "mountpoint": "/", "fssize": 1024000, "fsused": 102400, "fsavail": 921600,
         "fsuse%": "10%", "uuid": "u-1"},
        {"fstype": "ext4", "path": "/dev/vdb1", "name": "vdb1", "kname": "vdb1",
         "mountpoint": null, "fssize": null, "fsused": null, "fsavail": null,
         "fsuse%": null, "uuid": "u-2"}
    ]}"#;
    let df = "Filesystem     Type 1K-blocks Used Available Use% Mounted on\n\
        /dev/vda1      ext4      1000  100       900  10% /\n";
    let disks = linux::parse_disk(&output(lsblk, df));
    assert_eq!(disks.len(), 2);
    assert_eq!(disks[1].path, "/dev/vdb1");
    assert_eq!(disks[1].mount, "");
    assert_eq!(disk_usage(&disks, false), (100, 1000));
    assert_eq!(disk_usage(&disks, true), (100, 1000));
}

fn row(path: &str, mount: &str, used: u64, size: u64) -> Disk {
    Disk {
        path: path.to_string(),
        mount: mount.to_string(),
        used,
        size,
        avail: size - used,
        ..Disk::default()
    }
}

/// A node with numbers of its own is the total for what is under it.
#[test]
fn a_parent_with_numbers_is_not_counted_twice() {
    let mut parent = row("/dev/sda1", "/", 100, 200);
    parent.children = vec![row("/dev/sda1-child", "/child", 1000, 2000)];
    assert_eq!(disk_usage(&[parent], false), (100, 200));
}

/// A loop device carrying a writable filesystem is storage someone mounted.
#[test]
fn a_writable_loop_device_counts() {
    let mut disk = row("/dev/loop7", "/mnt/image", 515072, 1032256);
    disk.fs_type = Some("ext4".into());
    assert_eq!(disk_usage(&[disk], false), (515072, 1032256));
}

/// A source carries user-chosen text: a ZFS pool named `tmpfspool` is storage
/// and counts. The `host:/export` sources are storage too — listed — but on
/// another machine, so they count only when asked to.
#[test]
fn storage_named_like_a_virtual_fs_counts_as_what_it_is() {
    let size = 961873408;
    let disks = [
        row("tmpfspool/data", "/srv/pool", 12345678, size),
        row("shm-nas:/vol1", "/srv/nfs", 12345678, size),
        row("overlay-01:/export", "/srv/export", 12345678, size),
        row("devtmpfs-backup:/snapshots", "/srv/backup", 12345678, size),
    ];
    assert!(disks.iter().all(Disk::is_storage));
    assert_eq!(disk_usage(&disks, false).1, size);
    assert_eq!(disk_usage(&disks, true).1, size * 4);
}

/// The monitor agent's native sampler on macOS keys a volume by its mount
/// point and puts the device in `name`: the container still counts once.
#[test]
fn an_apfs_container_named_the_native_way_counts_once() {
    let volume = |label: &str, device: &str, mount: &str, used: u64| Disk {
        path: label.to_string(),
        name: Some(device.to_string()),
        fs_type: Some("apfs".into()),
        mount: mount.to_string(),
        used,
        size: 1000,
        avail: 100,
        ..Disk::default()
    };
    let disks = [
        volume("Macintosh HD", "disk3s1s1", "/", 15),
        volume("Data", "disk3s5", "/System/Volumes/Data", 800),
    ];
    assert_eq!(
        disk_total(&disks, false),
        DiskTotal {
            used: 900,
            size: 1000,
            avail: 100
        }
    );
}

/// Available is `df`'s, not size less used: ext4 keeps 5% back for root.
#[test]
fn available_space_is_what_the_filesystem_says() {
    let mut disk = row("/dev/vda1", "/", 400, 1000);
    disk.avail = 550;
    assert_eq!(
        disk_total(&[disk], false),
        DiskTotal {
            used: 400,
            size: 1000,
            avail: 550
        }
    );
}

/// Volumes of one container read a moment apart can disagree on free space:
/// still one container.
#[test]
fn an_apfs_container_read_a_moment_apart_counts_once() {
    let volume = |path: &str, avail: u64| Disk {
        path: path.to_string(),
        fs_type: Some("apfs".into()),
        mount: format!("/Volumes/{path}"),
        size: 1000,
        avail,
        ..Disk::default()
    };
    let disks = [volume("/dev/disk3s1s1", 100), volume("/dev/disk3s5", 98)];
    assert_eq!(disk_total(&disks, false), DiskTotal { used: 900, size: 1000, avail: 100 });
}

/// Every device `lsblk` lists, whether or not a filesystem is on it or mounted
/// (#1829): a blank disk with its model, a partition nothing mounts, an active
/// zram swap. Loop devices are not disks and are left out. The filesystem list
/// is unchanged: the blank disk and the swap are not storage to count.
#[test]
fn block_devices_list_what_is_not_mounted() {
    let raw = include_str!("fixtures/lsblk_block_devices.txt");
    let devices = linux::parse_block_devices(raw);

    let names: Vec<&str> = devices.iter().map(|d| d.name.as_str()).collect();
    assert_eq!(names, ["sda", "nvme0n1", "zram0"]);

    let sda = &devices[0];
    assert_eq!(sda.kind, "disk");
    assert_eq!(sda.model.as_deref(), Some("WDC WD40EFRX-68N32N0"));
    assert_eq!(sda.tran.as_deref(), Some("sata"));
    assert_eq!(sda.size, 4_000_787_030_016);
    assert_eq!(sda.mount, None);
    assert!(sda.children.is_empty());

    let parts = &devices[1].children;
    assert_eq!(parts.len(), 3);
    assert_eq!(parts[0].mount.as_deref(), Some("/boot/efi"));
    assert_eq!(parts[0].size, 536_870_912, "a size lsblk printed as a string");
    assert_eq!(parts[2].fs_type.as_deref(), Some("ntfs"));
    assert_eq!(parts[2].mount, None);
    assert_eq!(parts[2].model, None);

    assert_eq!(devices[2].mount.as_deref(), Some("[SWAP]"));

    let mounts: Vec<String> = linux::parse_disk(raw).iter().flat_map(flat_mounts).collect();
    assert_eq!(mounts, ["/boot/efi", "/"]);
}

fn flat_mounts(d: &Disk) -> Vec<String> {
    let mut out = vec![d.mount.clone()];
    out.extend(d.children.iter().flat_map(flat_mounts));
    out.retain(|m| !m.is_empty());
    out
}

/// Output from before the lsblk half, or a host without `lsblk`: no devices.
#[test]
fn block_devices_need_lsblk() {
    assert!(linux::parse_block_devices("").is_empty());
    let df = "Filesystem 1K-blocks Used Available Use% Mounted on\n/dev/sda1 100 50 50 50% /\n";
    assert!(linux::parse_block_devices(&format!("{DISK_DF_MARKER}\n{df}")).is_empty());
    assert!(linux::parse_block_devices(df).is_empty());
}

/// A Proxmox VE thin pool, which `lsblk` lists under both `_tmeta` and
/// `_tdata`: listed once, under the first, so a client keying rows by path
/// never sees one twice. The transport newer `lsblk` repeats on every
/// partition stays on the disk.
#[test]
fn block_devices_list_a_shared_device_once() {
    let dev = |name: &str, kind: &str, children: &str| {
        format!(
            r#"{{"path":"/dev/mapper/{name}","name":"{name}","type":"{kind}","size":1,"tran":"nvme","children":[{children}]}}"#
        )
    };
    let pool = || dev("pve-data-tpool", "lvm", &dev("pve-vm--100--disk--0", "lvm", ""));
    let raw = format!(
        r#"{{"blockdevices":[{{"path":"/dev/nvme0n1","name":"nvme0n1","type":"disk","size":1,"tran":"nvme","children":[
            {}]}}]}}"#,
        dev(
            "nvme0n1p3",
            "part",
            &format!(
                "{},{}",
                dev("pve-data_tmeta", "lvm", &pool()),
                dev("pve-data_tdata", "lvm", &pool())
            )
        )
    );
    let devices = linux::parse_block_devices(&raw);

    let mut paths = Vec::new();
    fn walk(d: &[sbm_parser::types::BlockDevice], out: &mut Vec<String>) {
        for d in d {
            out.push(d.path.clone());
            walk(&d.children, out);
        }
    }
    walk(&devices, &mut paths);
    let unique: std::collections::HashSet<_> = paths.iter().collect();
    assert_eq!(unique.len(), paths.len(), "{paths:?}");
    assert!(paths.contains(&"/dev/mapper/pve-vm--100--disk--0".to_string()));

    let disk = &devices[0];
    assert_eq!(disk.tran.as_deref(), Some("nvme"));
    assert_eq!(disk.children[0].tran, None);
    let tmeta = &disk.children[0].children[0];
    let tdata = &disk.children[0].children[1];
    assert_eq!(tmeta.children.len(), 1);
    assert!(tdata.children.is_empty());
}
