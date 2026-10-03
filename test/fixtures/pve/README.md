# PVE fixtures

API answers `PveResources` (`lib/data/model/virt/pve_resources.dart`) reads,
asserted by `test/unit/virt/pve_backend_test.dart` and
`test/unit/virt/virt_backup_job_test.dart`. Captured from **PVE 9.2.2**
(`pve-manager/9.2.2/b9984c6d90a4bd80`) through its API, one file per endpoint
or per shape an endpoint answers in. The host's guests are VM 100, VM 101 and
CT 200; anything named `sb*` was made for the capture and removed again.

Storage and network answers (`node_storage.json`, `storage_config.json`,
`content_local*.json`, `network.json`) moved with their parser to
`crates/sbm_virt/tests/fixtures/pve/`.

Each file is the endpoint's `data` alone (what `PveBackend` reads), verbatim
apart from the whitespace `python3 -m json.tool` adds.

| File | Endpoint | Notes |
| --- | --- | --- |
| `node_storage_p8.json` | `GET /nodes/{node}/storage` | an older capture with `lvmthin` and a `dir` |
| `backup_content.json` | `GET .../storage/local/content?content=backup&vmid=` | one `vzdump` archive, with `notes`, `size`, `subtype`, `vmid` |
| `backup_job_fields.json` | `GET /cluster/backup` | one job that names its guests: `vmid` a comma list, `prune-backups` an object of strings, `notes-template` with PVE's `{{guestname}}` variables, `mailnotification` |
| `backup_jobs_all.json` | `GET /cluster/backup` | the same job plus one with `all: 1` and `exclude`, and one that is `enabled: 0` — the two shapes `VirtBackupJob.takes` distinguishes |
| `snapshots_qemu.json`, `snapshots_none.json` | `GET .../qemu/{vmid}/snapshot` | one snapshot with `vmstate: 1`, and a guest with none |
| `snapshot_config.json`, `snapshot_current_config.json` | `GET .../snapshot/{name}/config` | the configuration a snapshot recorded, for the diff |
| `hw_vm_config.json`, `hw_vm_devices_config.json` | `GET .../qemu/{vmid}/config` | a VM's configuration, with and without passthrough devices |
| `hw_vm_pending.json`, `hw_ct_pending.json` | `GET .../pending` | PVE's `{key, value, pending}` list, and a `delete: 1` entry |
| `hw_ct_config.json`, `hw_ct_config_mp_delete.json` | `GET .../lxc/{vmid}/config` | a container's configuration, and one with a mount point to remove |
| `hw_ct_pending_mp_delete.json` | `GET .../lxc/{vmid}/pending` | a pending `delete` of a mount point |
| `hardware_usb.json`, `hardware_pci.json` | `GET /nodes/{node}/hardware/{usb,pci}` | the node's own devices (root only) |
| `mapping_usb.json`, `mapping_pci.json` | `GET /cluster/mapping/{usb,pci}` | resource mappings |

`GET /cluster/jobs/schedule-analyze` is not a fixture: its answers are the
table in `test/unit/virt/virt_backup_job_test.dart`, one line per value the
host was asked about, since what matters there is which values it takes, not
the timestamps it prints.
