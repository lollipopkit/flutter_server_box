/// `virtHwIssue`: what the Hardware view refuses before sending a change.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/virt/libvirt.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';

void main() {
  group('toString', _printed);

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
    expect(virtHwIssue(vm, const VirtHwGrowDisk(key: 'vdz', bytes: 2 << 30)), VirtHwIssue.diskSize);
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
    // The limit is the backend's: UTF-8 bytes, not UTF-16 units. 2731 CJK
    // characters are 8193 bytes; 2730 are 8190.
    expect(
      virtHwIssue(vm, VirtHwSetDescription('注' * 2731)),
      VirtHwIssue.description,
    );
    expect(virtHwIssue(vm, VirtHwSetDescription('注' * 2730)), isNull);
    expect(virtHwIssue(vm, VirtHwSetDescription('x' * virtHwDescriptionMax)), isNull);
    // DEL and C1 controls, as Rust's `char::is_control` has them.
    for (final c in ['\u007f', '\u0080', '\u009f']) {
      expect(
        virtHwIssue(vm, VirtHwSetDescription('a${c}b')),
        VirtHwIssue.description,
        reason: c.codeUnitAt(0).toRadixString(16),
      );
    }
    expect(virtHwIssue(vm, const VirtHwSetDescription('a\u00a0é~b')), isNull);
  });

  test('a boot order needs a device', () {
    expect(virtHwIssue(vm, const VirtHwSetBoot([])), VirtHwIssue.bootEmpty);
    expect(virtHwIssue(vm, const VirtHwSetBoot(['vda'])), isNull);
  });

  test('a MAC: unicast, six octets, not all zero', () {
    VirtHwIssue? mac(String m) => virtHwIssue(vm, VirtHwSetNicHardware(key: 'n', mac: m));
    expect(mac('52:54:00:12:34:56'), isNull);
    expect(mac('BC:24:11:AA:BB:CC'), isNull);
    expect(mac('01:00:5e:00:00:01'), VirtHwIssue.mac, reason: 'multicast');
    expect(mac('00:00:00:00:00:00'), VirtHwIssue.mac);
    expect(mac('52:54:00:12:34'), VirtHwIssue.mac);
    expect(mac('52-54-00-12-34-56'), VirtHwIssue.mac);
    expect(virtHwIssue(vm, const VirtHwSetNicHardware(key: 'n', model: 'e1000')), isNull);
  });

  test('a bus and the firmware change only while stopped', () {
    final stopped = vm.copyWith(running: false);
    const bus = VirtHwUpdateDisk(key: 'vda', bus: 'sata');
    expect(virtHwIssue(vm, bus), VirtHwIssue.stopFirst);
    expect(virtHwIssue(stopped, bus), isNull);
    // A cache mode waits for a restart instead: it is not refused.
    expect(virtHwIssue(vm, const VirtHwUpdateDisk(key: 'vda', cache: 'none')), isNull);
    const uefi = VirtHwSetFirmware(uefi: true);
    expect(virtHwIssue(vm, uefi), VirtHwIssue.stopFirst);
    expect(virtHwIssue(stopped, uefi, host: VirtHostKind.libvirt), isNull);
    // PVE puts the variables on a storage: one is needed.
    expect(virtHwIssue(stopped, uefi, host: VirtHostKind.pve), VirtHwIssue.storageMissing);
    expect(
      virtHwIssue(stopped, const VirtHwSetFirmware(uefi: true, storage: 'local-lvm'), host: VirtHostKind.pve),
      isNull,
    );
  });

  test('devices: one TPM, and a device picked', () {
    const usb = VirtHwAddDevice(kind: VirtHwDeviceKind.usb);
    expect(virtHwIssue(vm, usb), VirtHwIssue.device);
    expect(
      virtHwIssue(vm, const VirtHwAddDevice(kind: VirtHwDeviceKind.usb, host: VirtHostDevice(id: '0bda:b023', label: 'bt'))),
      isNull,
    );
    const tpm = VirtHwAddDevice(kind: VirtHwDeviceKind.tpm);
    expect(virtHwIssue(vm, tpm, host: VirtHostKind.libvirt), isNull);
    expect(virtHwIssue(vm, tpm, host: VirtHostKind.pve), VirtHwIssue.storageMissing);
    final withTpm = vm.copyWith(
      devices: const [VirtHwDevice(key: 'tpm', kind: VirtHwDeviceKind.tpm)],
    );
    expect(virtHwIssue(withTpm, tpm, host: VirtHostKind.libvirt), VirtHwIssue.device);
  });
}

void _printed() {
  test('printed without the revision, which can hold passwords', () {
    const hw = VirtHardware(
      kind: VirtGuestKind.qemu,
      running: true,
      cpu: VirtHwCpu(sockets: 1, cores: 1),
      memory: VirtHwMemory(mib: 512),
      revision: "<graphics type='vnc' passwd='s3cret'/>",
      configText: "<graphics type='vnc'/>",
    );
    expect('$hw', isNot(contains('s3cret')));
    expect('$hw', contains('qemu'));
  });

  test('the libvirt read is printed without its definitions', () {
    const secret = "<graphics type='vnc' passwd='s3cret'/>";
    const info = LibvirtHardwareInfo(
      config: LibvirtHwConfig(
        cpu: LibvirtHwCpu(sockets: 1, cores: 1, max: 1, current: 1),
        memoryKib: 1024,
        currentMemoryKib: 1024,
      ),
      configXml: secret,
      liveXml: secret,
    );
    expect('$info', isNot(contains('s3cret')));
  });
}
