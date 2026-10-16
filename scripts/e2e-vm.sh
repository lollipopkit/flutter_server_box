#!/bin/sh
# Throwaway Proxmox VE VMs for the Monitor's end-to-end tests: each run gets
# a fresh VM (a linked clone of a template) with as many empty disks as it
# asks for, and is destroyed after. Nothing on an existing machine changes.
#
#   scripts/e2e-vm.sh template <node>                 # once: VM 9310 from an Ubuntu cloud image
#   scripts/e2e-vm.sh up       <node> [disks] [GiB]   # prints "<vmid> <address>"
#   scripts/e2e-vm.sh disk     <node> <vmid> add|remove <slot>   # slot 0…9: scsi20…29
#   scripts/e2e-vm.sh down     <node> <vmid>
#
# <node> is an ssh host for the PVE node (root). Environment:
#   SBM_E2E_VM_IP      the VM's address (192.168.31.231/24); one VM at a time
#   SBM_E2E_VM_GW      its gateway (192.168.31.1)
#   SBM_E2E_VM_PROXY   an HTTP proxy apt uses, kept in the template (none)
#   SBM_E2E_VM_KEY     the public key the VM lets in as root (~/.ssh/id_ed25519.pub)
#   SBM_E2E_VM_IMAGE   the cloud image on the node
#                      (/var/lib/vz/template/iso/ubuntu-26.04-server-cloudimg-amd64.img)
#
# Only VMs named sbm-e2e-* are ever destroyed.
set -eu

TEMPLATE=9310
cmd=${1:-}
node=${2:-}
ip=${SBM_E2E_VM_IP:-192.168.31.231/24}
gw=${SBM_E2E_VM_GW:-192.168.31.1}
key=${SBM_E2E_VM_KEY:-$HOME/.ssh/id_ed25519.pub}
image=${SBM_E2E_VM_IMAGE:-/var/lib/vz/template/iso/ubuntu-26.04-server-cloudimg-amd64.img}
addr=${ip%/*}

usage() {
  sed -n '2,19p' "$0" >&2
  exit 2
}
[ -n "$cmd" ] && [ -n "$node" ] || usage
number() { case $1 in '' | *[!0-9]*) echo "$2 is a number" >&2; exit 2 ;; esac; }
pve() { ssh -n "$node" "$@"; }
vm() { ssh -n -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5 "root@$addr" "$@"; }

wait_ssh() {
  i=0
  until vm true 2>/dev/null; do
    i=$((i + 1))
    [ "$i" -lt 60 ] || { echo "the VM did not answer ssh at $addr" >&2; exit 1; }
    sleep 5
  done
}

# Refuses a VM that is not one of ours.
ours() {
  name=$(pve "qm config $1" | sed -n 's/^name: //p')
  case $name in sbm-e2e-*) ;; *) echo "VM $1 is '$name', not an sbm-e2e VM" >&2; exit 1 ;; esac
}

case $cmd in
  template)
    if pve "qm status $TEMPLATE" >/dev/null 2>&1; then echo "VM $TEMPLATE exists already" >&2; exit 1; fi
    [ -f "$key" ] || { echo "no public key at $key" >&2; exit 1; }
    ping -c1 -W1 "$addr" >/dev/null 2>&1 && { echo "$addr answers already: pick another SBM_E2E_VM_IP" >&2; exit 1; }
    scp -q "$key" "$node:/tmp/sbm-e2e-key.pub"
    pve "qm create $TEMPLATE --name sbm-e2e-template --memory 2048 --balloon 0 --cores 2 --cpu host --ostype l26 \
      --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-single --agent enabled=1 --serial0 socket --vga serial0 \
      --scsi0 local-lvm:0,import-from=$image,discard=on,iothread=1,ssd=1 --ide2 local-lvm:cloudinit --boot order=scsi0 \
      --ciuser root --sshkeys /tmp/sbm-e2e-key.pub --ciupgrade 0 --ipconfig0 ip=$ip,gw=$gw --nameserver $gw \
      && qm disk resize $TEMPLATE scsi0 8G && rm -f /tmp/sbm-e2e-key.pub && qm start $TEMPLATE"
    wait_ssh
    proxy=${SBM_E2E_VM_PROXY:-}
    vm "set -e; cloud-init status --wait >/dev/null || true
      if [ -n '$proxy' ]; then printf 'Acquire::http::Proxy \"%s\";\nAcquire::https::Proxy \"%s\";\n' '$proxy' '$proxy' > /etc/apt/apt.conf.d/95proxy; fi
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -q >/dev/null
      apt-get install -y -q qemu-guest-agent mdadm zfsutils-linux smartmontools >/dev/null
      cloud-init clean --logs --machine-id
      poweroff" || true
    i=0
    until [ "$(pve "qm status $TEMPLATE")" = "status: stopped" ]; do
      i=$((i + 1)); [ "$i" -lt 60 ] || { echo "VM $TEMPLATE did not power off" >&2; exit 1; }; sleep 5
    done
    pve "qm set $TEMPLATE --ipconfig0 ip=dhcp >/dev/null && qm template $TEMPLATE"
    echo "template $TEMPLATE ready"
    ;;
  up)
    disks=${3:-0}
    size=${4:-4}
    number "$disks" disks
    number "$size" GiB
    ping -c1 -W1 "$addr" >/dev/null 2>&1 && { echo "$addr answers already: another e2e VM is up?" >&2; exit 1; }
    id=$(pve "pvesh get /cluster/nextid")
    # A VM that does not come up goes again.
    trap 'pve "qm stop $id --skiplock 1 >/dev/null 2>&1; qm destroy $id --purge 1 --destroy-unreferenced-disks 1 >/dev/null 2>&1"' EXIT
    pve "qm clone $TEMPLATE $id --name sbm-e2e-$id >/dev/null && qm set $id --ipconfig0 ip=$ip,gw=$gw >/dev/null"
    i=0
    while [ "$i" -lt "$disks" ]; do
      pve "qm set $id --scsi$((20 + i)) local-lvm:$size,serial=sbmdisk$i >/dev/null"
      i=$((i + 1))
    done
    pve "qm start $id >/dev/null"
    wait_ssh
    trap - EXIT
    echo "$id $addr"
    ;;
  disk)
    id=${3:-}
    op=${4:-}
    slot=${5:-}
    number "$id" vmid
    number "$slot" slot
    [ "$slot" -le 9 ] || { echo "slot is 0 to 9" >&2; exit 2; }
    ours "$id"
    case $op in
      add) pve "qm set $id --scsi$((20 + slot)) local-lvm:${SBM_E2E_VM_DISK_GIB:-4},serial=sbmdisk$slot >/dev/null" ;;
      remove) pve "qm disk unlink $id --idlist scsi$((20 + slot)) --force 1" ;;
      *) usage ;;
    esac
    ;;
  down)
    id=${3:-}
    number "$id" vmid
    ours "$id"
    pve "qm stop $id --skiplock 1 >/dev/null 2>&1; qm destroy $id --purge 1 --destroy-unreferenced-disks 1"
    ;;
  *) usage ;;
esac
