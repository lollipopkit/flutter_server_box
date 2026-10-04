# PVE fixtures

API answers `sbm_virt::pve` reads, which `test/unit/virt/pve_backend_test.dart`
serves to the app's session and `crates/sbm_virt/tests/` assert. Captured from **PVE 9.2.2**
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
| `snapshots_qemu.json`, `snapshots_none.json` | `GET .../qemu/{vmid}/snapshot` | one snapshot with `vmstate: 1`, and a guest with none |
| `snapshot_config.json`, `snapshot_current_config.json` | `GET .../snapshot/{name}/config` | the configuration a snapshot recorded, for the diff |
| `hw_vm_config.json` | `GET .../qemu/{vmid}/config` | a VM's configuration |
| `hw_vm_pending.json` | `GET .../pending` | PVE's `{key, value, pending}` list |
| `hardware_usb.json`, `hardware_pci.json` | `GET /nodes/{node}/hardware/{usb,pci}` | the node's own devices (root only) |
| `mapping_usb.json`, `mapping_pci.json` | `GET /cluster/mapping/{usb,pci}` | resource mappings |

`GET /cluster/jobs/schedule-analyze` is not a fixture: its answers are the
table in `crates/sbm_virt/tests/backup.rs`, one line per value the
host was asked about, since what matters there is which values it takes, not
the timestamps it prints.

The backup jobs' fixtures, the containers' hardware fixtures and the VM with
passthrough devices moved to
`crates/sbm_virt/tests/fixtures/pve/`, with the tests that read them.
