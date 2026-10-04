# PVE fixtures

API answers `sbm_virt::pve::resources`, `pve::hardware` and `pve::backup` read,
asserted by `tests/pve_storage.rs`, `tests/pve_hardware.rs` and `tests/pve_backup.rs`. Captured from **PVE 9.2.2** through its API (moved
from the app's `test/fixtures/pve/`, whose README describes the capture).
Each file is the endpoint's `data` alone.

| File | Endpoint | Notes |
| --- | --- | --- |
| `node_storage.json` | `GET /nodes/{node}/storage` | the node's storages |
| `storage_config.json` | `GET /storage` | the cluster's storage configuration (paths, `vgname`/`thinpool`) |
| `content_local.json`, `content_local_lvm.json` | `GET /nodes/{node}/storage/{id}/content` | an ISO on `local`, a disk on `local-lvm` |
| `network.json` | `GET /nodes/{node}/network` | the node's interfaces: `vmbr0` with the management address on `nic0` |
| `hw_vm_config.json`, `hw_vm_pending.json` | `GET /nodes/{node}/qemu/{vmid}/config`, `.../pending` | a VM's configuration and what its running instance has instead |
| `hw_vm_devices_config.json` | `GET /nodes/{node}/qemu/{vmid}/config` | a VM with USB, PCI and a TPM |
| `hw_ct_config.json`, `hw_ct_pending.json` | `GET /nodes/{node}/lxc/{vmid}/config`, `.../pending` | a container's |
| `hw_ct_config_mp_delete.json`, `hw_ct_pending_mp_delete.json` | the same | a mount point removed while it runs: pending deletion |
| `hardware_usb.json`, `hardware_pci.json` | `GET /nodes/{node}/hardware/usb`, `.../pci` | the node's devices |
| `mapping_usb.json`, `mapping_pci.json` | `GET /cluster/mapping/usb`, `.../pci` | resource mappings |
| `node_storage_p8.json` | `GET /nodes/{node}/storage` | an older capture with `lvmthin` and a `dir`; only `local` holds backups |
| `backup_content.json` | `GET /nodes/{node}/storage/local/content?content=backup&vmid=` | one `vzdump` archive, with `notes`, `size`, `subtype`, `vmid` |
| `backup_job_fields.json` | `GET /cluster/backup` | one job that names its guests: `vmid` a comma list, `prune-backups` an object of strings, `notes-template` with PVE's `{{guestname}}` variables, `mailnotification` |
| `backup_jobs_all.json` | `GET /cluster/backup` | the same job plus one with `all: 1`, `exclude` and `enabled: 0` — the two shapes `BackupJob::takes` distinguishes |
| `backup_jobs.json` | `GET /cluster/backup` | one disabled job of one guest, with `prune-backups` |

`GET /cluster/jobs/schedule-analyze` is not a fixture: its answers are the
table in `tests/backup.rs`, one line per value the host was asked about.
