# virt fixtures

Inputs for `sbm_parser::virt` (`tests/virt.rs`, and through FFI
`test/unit/virt/virt_ffi_test.dart` and `test/unit/virt/libvirt_backend_test.dart`).

**Captured** files are raw `virsh --connect qemu:///system -q … </dev/null`
output (stderr included for errors, `LC_ALL=C`) from a Debian 13 host running
libvirt 11.3.0 / QEMU 10.0.13, captured 2026-09-25. Its guests: `cirros-run`
(running, autostart, VNC on 127.0.0.1, pty serial, 2 disks, 2 NICs),
`cirros-paused` (paused by the user, no graphics) and `it's-"odd"` (shut off,
no graphics, pty serial; its last start had failed, so its reason is
`failed`). `version_libvirt12.txt` is captured from a libvirt 12.0.0 /
QEMU 10.2.1 host.

**Hand-written** files cover what that host cannot produce. They follow
libvirt's printing code (`tools/virsh-domain-monitor.c`, `tools/virsh-domain.c`)
and documented formats, not a machine. Replace one with captured output when
a host that has the case is available.

The opt-in e2e test (`SBM_E2E_SSH_HOST`,
`cargo test -p sbm_parser --test ssh_e2e ssh_e2e_virt -- --ignored`) runs the
real scripts and is the check that the formats hold; the Dart one is
`test/e2e/virt_real_test.dart`.

| File | Source | Command | Notes |
| --- | --- | --- | --- |
| `version_libvirt11.txt`, `version_libvirt12.txt` | captured | `version` | |
| `list_uuid_name.txt` | captured | `list --all --uuid --name` | libvirt ≥ 7.0: `uuid name` |
| `list_uuid_name_libvirt6.txt` | hand-written | same | the captured list reprinted as libvirt < 7.0 did, `%-36s %-30s` |
| `list_autostart.txt`, `list_persistent.txt` | captured | `list --all --uuid --autostart` / `--persistent` | |
| `domstats.txt` | captured | `domstats --raw --nowait --state --cpu-total --balloon --vcpu --interface --block` | unfiltered: the script drops the `vcpu.N.*` lines on the host (~65 per vCPU on this version). A shut-off domain still reports `cpu.*` of its last run, `balloon.current/maximum`, `vcpu.*` and block sizes, but no I/O counters and no nets. |
| `domstats_synthetic.txt` | hand-written | same | vCPUs below maximum, an empty cdrom (no `path`), macvtap, a domain in shutdown (state 4) |
| `dumpxml_cirros_run.xml` | captured | `dumpxml` | running: VNC `port='5900'`, backing chain, `<channel>` (not a console) |
| `dumpxml_cirros_run_inactive.xml` | captured | `dumpxml --inactive` | what a shut-off domain with autoport VNC prints: no port, no `vnetN` |
| `dumpxml_odd.xml` | captured | `dumpxml` | shut off, no graphics, serial console, XML-escaped name |
| `dumpxml_win11.xml` | hand-written | `dumpxml` | file, cdrom, rbd and pool-volume disks, bridge and macvtap NICs, SPICE with TLS |
| `dumpxml_inactive_vnc.xml` | hand-written | `dumpxml` | autoport VNC plus a socket VNC |
| `domdisplay_cirros_run.txt` | captured | `domdisplay` | `vnc://127.0.0.1:0`, no trailing newline |
| `domdisplay_win11.txt` | hand-written | `domdisplay` | SPICE with `tls-port` |
| `error_display_not_running.txt`, `error_display_no_graphics.txt` | captured | `domdisplay` | shut off / running without graphics |
| `error_already_active.txt` | captured | `start` on a running domain | `Domain is already active`, no "Requested operation" line |
| `error_already_running.txt` | captured | `resume` on a running domain | |
| `error_not_running.txt` | captured | `suspend` on a shut-off domain | |
| `error_not_found.txt` | captured | `start` on an unknown UUID | |
| `error_apparmor_start.txt` | captured | `start` of `it's-"odd"` | `virt-aa-helper` rejects a domain name containing `"` ("bad name"), so on an AppArmor host such a domain cannot start at all |
| `error_polkit.txt` | captured | any, as a user outside the `libvirt` group | this host's socket is 0666 and polkit refuses |
| `error_permission.txt` | hand-written | same | socket `Permission denied` (a host whose socket is group-restricted) |
| `error_no_daemon.txt` | hand-written | any | daemon not running |

`script_*.txt` are whole script outputs rather than one command's: what
`snapshots_script`, `storage_script`, `volumes_script`, `networks_script` and
the snapshot actions printed when fed to `sh` on the same host, markers and
`SbVirtRc=` lines included. For them the host also had, besides the domains
above: snapshots `sbx-a` (running, with memory), `sbx-off` (taken shut off,
disks only) and `sbx-b` (running) of `cirros-run` in a chain, `sbx-a`
current; an active dir pool `sbx-iso` holding `my disk.qcow2` (a name with a
space) and `tiny.iso`, and an inactive dir pool `sbx-off`; an isolated network
`sbx-isolated` with DHCP and an IPv6 address, and an inactive bridge-mode
network `sbx-bridge`; `it's-"odd"` with a second NIC on `sbx-isolated` and
`tiny.iso` as a cdrom.

| File | Script | Notes |
| --- | --- | --- |
| `script_snapshots_cirros_run.txt` | `snapshots_script` | three snapshots, `snapshot-dumpxml` with the embedded `<domain>` |
| `script_snapshots_none.txt` | `snapshots_script` | no snapshots: `snapshot-current` fails (`has no current snapshot`) |
| `script_snapshot_error_raw.txt` | `snapshot_create_script` | a domain with a raw disk: `internal snapshot for disk vda unsupported for storage type raw` |
| `script_snapshot_error_exists.txt` | `snapshot_create_script` | a name taken: `domain moment sbx-a already exists` |
| `script_snapshot_error_not_found.txt`, `script_snapshot_error_delete_not_found.txt` | `snapshot_revert_script` / `snapshot_delete_script` | an unknown snapshot |
| `script_storage.txt` | `storage_script` | `vol-list` with its header, so the Path column is found |
| `script_volumes_images.txt` | `volumes_script` | qcow2 overlays with a backing file, and `gone.qcow2`, which does not exist |
| `script_volumes_sbx_iso.txt` | `volumes_script` | the name with a space, a raw `.iso` |
| `script_networks.txt` | `networks_script` | NAT, isolated with IPv6, inactive bridge mode, two DHCP leases |

`overview.expected.json`, `detail_*.expected.json`, `snapshots_*.expected.json`,
`storage.expected.json`, `volumes_*.expected.json` and `networks.expected.json`
are the parsers' output for these inputs, asserted by both the Rust and the
Dart test.

`script_create_*`, `script_define_*` and `script_undefine.txt` are what the
create and delete scripts printed on the same host (2026-09-25):
`create_host_script` (`domcapabilities` for KVM/q35, KVM, QEMU/q35, QEMU —
**trimmed** to the elements the parser reads, the rest of each document runs
to ~65 KB), `create_volume_script` for `sbm-create-test` (1 GiB qcow2 in
`images`) and again once it was defined (`_exists`: stopped before creating
anything), `define_script` with the ISO `sbm-test.iso` and the network
`default`, started (`_ok`), and with the machine type `pc-bogus-9.9`
(`_rollback`: "No PCI buses available", the volume deleted again), and
`undefine_script` with `--storage vda`. All of them were removed afterwards.

`script_hardware_{running,stopped}.txt` are `hardware_script` on a domain
`sbhw-test` made for them (libvirt 11.3, 2026-09-26): running with 3 of 4
vCPUs online and 2 in the persistent definition, and shut off.
`script_hw_*.txt` are `hardware_change_script` on the same domain, one
change each (`hardware_changes_as_captured` names the change behind each
file), including the refusals: `_add_disk_ide_live_refused` (IDE cannot be
hot-plugged, saved for the next start), `_remove_disk_kept` (the running
domain keeps the disk, so its volume is kept), `_add_disk_exists` (the volume
name taken), `_conflict` (the persistent XML changed since it was read) and
`_guard_refused`. The domain and its volumes were removed afterwards.

Devices, display and firmware (hardware, second part), captured with the
same scripts on a throwaway q35 domain on that host (a nested Debian guest:
no IOMMU, no USB device, no swtpm, a QEMU without SPICE):

| File | What |
| --- | --- |
| `script_hardware_caps_stopped.txt` | `hardware_script` on the stopped domain, with its `domcapabilities` (q35: Secure Boot offered, TPM not) |
| `script_hardware_caps_running.txt` | The same running with UEFI and Secure Boot, a cache mode changed in the definition only |
| `script_host_devices.txt` | `host_devices_script`: 13 PCI devices, none in an IOMMU group; no USB |
| `script_hw_update_disk_bus.txt`, `script_hw_update_disk_cache.txt`, `script_hw_cache_running.txt` | `vda` moved to SATA, then a cache mode, stopped and running |
| `script_hw_nic_hardware.txt` | Model `e1000e` and a new MAC |
| `script_hw_firmware_*.txt` | UEFI with Secure Boot, without, back to BIOS, to UEFI again, and Secure Boot on after a start (the variables file moved to `-sb`) |
| `script_hw_display.txt` | Listen on `0.0.0.0`, card `vga` |
| `script_hw_add_pci.txt`, `script_hw_remove_pci.txt` | A host PCI device written into the definition (the start is then refused: no IOMMU), and removed |
