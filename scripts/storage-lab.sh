#!/bin/sh
# Spare disks for the Storage end-to-end tests (monitor/frontend/e2e/
# storage.e2e.ts, monitor/tests/storage_e2e.rs) on a Proxmox VE VM, over ssh
# to the node:
#
#   scripts/storage-lab.sh up   <node> <vmid> [count] [storage] [GiB]
#   scripts/storage-lab.sh down <node> <vmid> [count]
#
# `up` hot-plugs [count] (4) empty [GiB] (4) disks from [storage]
# (local-lvm) as scsi20… with serials sbmstor0…; inside the VM,
# `lsblk -o PATH,SERIAL | grep sbmstor` names them. `down` detaches them and
# deletes their volumes. Nothing else on the VM is touched.
set -eu

usage() {
  sed -n '2,13p' "$0" >&2
  exit 2
}

cmd=${1:-}
node=${2:-}
vmid=${3:-}
count=${4:-4}
[ -n "$cmd" ] && [ -n "$node" ] && [ -n "$vmid" ] || usage
case $vmid$count in *[!0-9]*) echo "vmid and count are numbers" >&2; exit 2 ;; esac

slots() {
  i=0
  while [ "$i" -lt "$count" ]; do
    echo "scsi$((20 + i)) $i"
    i=$((i + 1))
  done
}

case $cmd in
  up)
    storage=${5:-local-lvm}
    size=${6:-4}
    case $storage in *[!A-Za-z0-9_.-]*) echo "storage is not a plain name" >&2; exit 2 ;; esac
    case $size in *[!0-9]*) echo "GiB is a number" >&2; exit 2 ;; esac
    config=$(ssh "$node" "qm config $vmid")
    for slot in $(slots | cut -d' ' -f1); do
      if printf '%s\n' "$config" | grep -q "^$slot:"; then
        echo "$slot is already in use on VM $vmid" >&2
        exit 1
      fi
    done
    slots | while read -r slot i; do
      ssh -n "$node" "qm set $vmid --$slot $storage:$size,serial=sbmstor$i" >/dev/null
      echo "$slot: ${size}G, serial sbmstor$i"
    done
    ;;
  down)
    ids=$(slots | cut -d' ' -f1 | paste -sd, -)
    ssh "$node" "qm disk unlink $vmid --idlist $ids --force 1"
    ;;
  *) usage ;;
esac
