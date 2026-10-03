# PVE fixtures

API answers `sbm_virt::pve::resources` reads, asserted by
`tests/pve_storage.rs`. Captured from **PVE 9.2.2** through its API (moved
from the app's `test/fixtures/pve/`, whose README describes the capture).
Each file is the endpoint's `data` alone.

| File | Endpoint | Notes |
| --- | --- | --- |
| `node_storage.json` | `GET /nodes/{node}/storage` | the node's storages |
| `storage_config.json` | `GET /storage` | the cluster's storage configuration (paths, `vgname`/`thinpool`) |
| `content_local.json`, `content_local_lvm.json` | `GET /nodes/{node}/storage/{id}/content` | an ISO on `local`, a disk on `local-lvm` |
| `network.json` | `GET /nodes/{node}/network` | the node's interfaces: `vmbr0` with the management address on `nic0` |
