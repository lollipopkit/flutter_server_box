/// `virtHwIssue`: what the Hardware view refuses before sending a change.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';

void main() {
  const vm = VirtHardware(
    kind: VirtGuestKind.qemu,
    running: true,
    cpu: VirtHwCpu(sockets: 1, cores: 2, threads: 2),
    memory: VirtHwMemory(mib: 1024, minMib: 512, balloon: true),
    disks: [VirtHwDisk(key: 'vda', kind: VirtHwDiskKind.disk, size: 1 << 30)],
    limits: VirtHwLimits(hostCpus: 8, hostMemoryBytes: 4 << 30),
  );
  final ct = vm.copyWith(kind: VirtGuestKind.lxc);
  const pool = VirtStoragePool(
    id: 'images',
    name: 'images',
    type: 'dir',
    available: 10 << 30,
  );

  test('CPUs: at least one, no more than the host has', () {
    expect(virtHwIssue(vm, const VirtHwSetCpu(sockets: 2, cores: 2)), isNull);
    // Threads are kept: 2 × 3 × 2 = 12 > 8.
    expect(virtHwIssue(vm, const VirtHwSetCpu(sockets: 2, cores: 3)), VirtHwIssue.cpuCount);
    expect(virtHwIssue(vm, const VirtHwSetCpu(sockets: 0, cores: 2)), VirtHwIssue.cpuCount);
    expect(virtHwIssue(vm, const VirtHwSetCpu(sockets: 1, cores: 2, online: 5)), VirtHwIssue.cpuOnline);
    expect(virtHwIssue(vm, const VirtHwSetCpu(sockets: 1, cores: 2, online: 0)), VirtHwIssue.cpuOnline);
    // The host's CPUs unknown: no upper limit but a sane one.
    final unknown = vm.copyWith(limits: const VirtHwLimits());
    expect(virtHwIssue(unknown, const VirtHwSetCpu(sockets: 4, cores: 16)), isNull);
  });

  test('memory: within the host, a floor under it, no negative swap', () {
    expect(virtHwIssue(vm, const VirtHwSetMemory(mib: 2048, minMib: 1024)), isNull);
    expect(virtHwIssue(vm, const VirtHwSetMemory(mib: 8, minMib: 4)), VirtHwIssue.memory);
    expect(virtHwIssue(vm, const VirtHwSetMemory(mib: 5000)), VirtHwIssue.memory);
    expect(virtHwIssue(vm, const VirtHwSetMemory(mib: 1024, minMib: 2048)), VirtHwIssue.memoryMin);
    expect(virtHwIssue(ct, const VirtHwSetMemory(mib: 1024, swapMib: -1)), VirtHwIssue.swap);
  });

  test('disks only grow, and fit the storage', () {
    expect(virtHwIssue(vm, const VirtHwGrowDisk(key: 'vda', bytes: 2 << 30)), isNull);
    expect(virtHwIssue(vm, const VirtHwGrowDisk(key: 'vda', bytes: 1 << 30)), VirtHwIssue.diskShrink);
    expect(virtHwIssue(vm, const VirtHwAddDisk(storage: pool, gib: 10)), isNull);
    expect(virtHwIssue(vm, const VirtHwAddDisk(storage: pool, gib: 11)), VirtHwIssue.storageSpace);
    expect(virtHwIssue(vm, const VirtHwAddDisk(storage: pool, gib: 0)), VirtHwIssue.diskSize);
  });

  test('a mount point: absolute, nothing PVE would read as another option', () {
    VirtHwIssue? mp(String? path) =>
        virtHwIssue(ct, VirtHwAddDisk(storage: pool, gib: 1, mountPoint: path));
    expect(mp('/srv/data'), isNull);
    for (final bad in [null, '', '/', 'srv', '/srv/', '/a,backup=1', '/a=b', '/a b']) {
      expect(mp(bad), VirtHwIssue.mountPoint, reason: '$bad');
    }
    // A VM's disk has none.
    expect(virtHwIssue(vm, const VirtHwAddDisk(storage: pool, gib: 1)), isNull);
  });

  test('a name the host takes; libvirt renames only a stopped guest', () {
    expect(
      virtHwIssue(vm, const VirtHwSetName('web-02'), host: VirtHostKind.pve),
      isNull,
    );
    // An underscore: libvirt's, not a DNS name.
    expect(
      virtHwIssue(vm, const VirtHwSetName('web_02'), host: VirtHostKind.pve),
      VirtHwIssue.nameInvalid,
    );
    final libvirt = vm.copyWith(renameRunning: false);
    expect(
      virtHwIssue(libvirt, const VirtHwSetName('web_02'), host: VirtHostKind.libvirt),
      VirtHwIssue.nameRunning,
    );
    expect(
      virtHwIssue(
        libvirt.copyWith(running: false),
        const VirtHwSetName('web_02'),
        host: VirtHostKind.libvirt,
      ),
      isNull,
    );
    expect(
      virtHwIssue(vm, const VirtHwSetName('-x'), host: VirtHostKind.libvirt),
      VirtHwIssue.nameInvalid,
    );
  });

  test('a note: lines and tabs, no other control characters, bounded', () {
    expect(virtHwIssue(vm, const VirtHwSetDescription('a\n\tb')), isNull);
    expect(virtHwIssue(vm, const VirtHwSetDescription('')), isNull);
    expect(
      virtHwIssue(vm, const VirtHwSetDescription('a\u0007b')),
      VirtHwIssue.description,
    );
    expect(
      virtHwIssue(vm, VirtHwSetDescription('x' * (virtHwDescriptionMax + 1))),
      VirtHwIssue.description,
    );
  });

  test('a boot order needs a device', () {
    expect(virtHwIssue(vm, const VirtHwSetBoot([])), VirtHwIssue.bootEmpty);
    expect(virtHwIssue(vm, const VirtHwSetBoot(['vda'])), isNull);
  });
}
