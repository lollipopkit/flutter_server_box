/// The Dart side of a guest's hardware: the rules (`sbm_virt::hardware`,
/// tested there) reached through FFI, what a change and a read cross as,
/// and what each issue says.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/model/virt/virt_rust.dart';

import '../../helpers/rust_lib_helper.dart';

void main() {
  setUpAll(initRustLibForTest);

  const vm = VirtHardware(
    kind: VirtGuestKind.qemu,
    running: true,
    cpu: VirtHwCpu(sockets: 1, cores: 2, threads: 2),
    memory: VirtHwMemory(mib: 1024, minMib: 512, balloon: true),
    disks: [VirtHwDisk(key: 'vda', kind: VirtHwDiskKind.disk, size: 1 << 30, bus: 'virtio')],
    nics: [VirtHwNic(key: 'n', mac: '52:54:00:00:00:01')],
    boot: ['vda'],
    limits: VirtHwLimits(hostCpus: 8, hostMemoryBytes: 4 << 30),
    support: VirtHwSupport(
      buses: ['virtio', 'sata'],
      caches: ['default', 'none'],
      nicModels: ['virtio', 'e1000'],
      mac: true,
      uefi: true,
      tpm: true,
      usb: true,
    ),
  );
  const pool = VirtStoragePool(
    id: 'images',
    name: 'images',
    type: 'dir',
    available: 10 << 30,
  );

  test('rules through sbm_virt: a sample', () {
    expect(virtHwIssue(vm, const VirtHwSetCpu(sockets: 2, cores: 2)), isNull);
    expect(virtHwIssue(vm, const VirtHwSetCpu(sockets: 2, cores: 3)), VirtHwIssue.cpuCount);
    expect(virtHwIssue(vm, const VirtHwSetMemory(mib: 1024, minMib: 2048)), VirtHwIssue.memoryMin);
    expect(virtHwIssue(vm, const VirtHwGrowDisk(key: 'vda', bytes: 1 << 30)), VirtHwIssue.diskShrink);
    // The storage the change carries is what it is checked against here.
    expect(virtHwIssue(vm, const VirtHwAddDisk(storage: pool, gib: 10), host: VirtHostKind.libvirt), isNull);
    expect(
      virtHwIssue(vm, const VirtHwAddDisk(storage: pool, gib: 11), host: VirtHostKind.libvirt),
      VirtHwIssue.storageSpace,
    );
    expect(virtHwIssue(vm, const VirtHwSetNicHardware(key: 'n', mac: '01:00:5e:00:00:01')), VirtHwIssue.mac);
    expect(virtHwIssue(vm, const VirtHwSetNicHardware(key: 'gone', model: 'e1000')), VirtHwIssue.notFound);
    expect(virtHwIssue(vm, const VirtHwUpdateDisk(key: 'vda', bus: 'sata')), VirtHwIssue.stopFirst);
    expect(
      virtHwIssue(vm.copyWith(running: false), const VirtHwSetFirmware(uefi: true), host: VirtHostKind.pve),
      VirtHwIssue.storageMissing,
    );
    expect(
      virtHwIssue(
        vm.copyWith(running: false),
        const VirtHwSetFirmware(uefi: true, storage: pool),
        host: VirtHostKind.pve,
      ),
      isNull,
    );
    expect(virtHwIssue(vm, const VirtHwAddDevice(kind: VirtHwDeviceKind.usb)), VirtHwIssue.device);
    // A name: the host's rule, or both without one.
    expect(virtHwIssue(vm, const VirtHwSetName('web_02'), host: VirtHostKind.pve), VirtHwIssue.nameInvalid);
    expect(virtHwIssue(vm, const VirtHwSetName('web_02')), VirtHwIssue.nameInvalid);
    expect(virtHwIssue(vm, const VirtHwSetDescription('a\u0007b')), VirtHwIssue.description);
  });

  test('a change crosses with what it names by id', () {
    const iso = VirtVolume(id: 'a.iso', name: 'a.iso');
    expect(VirtRust.hwChangeJson(const VirtHwAddDisk(storage: pool, gib: 4)), {
      'op': 'add_disk',
      'pool': 'images',
      'gib': 4,
      'mount_point': null,
    });
    expect(VirtRust.hwChangeJson(const VirtHwSetMedia(key: 'hdc', media: (pool: pool, volume: iso))), {
      'op': 'set_media',
      'key': 'hdc',
      'media': {'pool': 'images', 'volume': 'a.iso'},
    });
    expect(
      VirtRust.hwChangeJson(
        const VirtHwAddDevice(
          kind: VirtHwDeviceKind.usb,
          host: VirtHostDevice(id: '0bda:b023', label: 'bt', usbBus: 1, usbDevice: 4),
          usbNaming: VirtUsbNaming.address,
        ),
      ),
      containsPair('usb_naming', 'address'),
    );
    expect(VirtRust.hwChangeJson(const VirtHwSetCpu(sockets: 1, cores: 2, type: 'host'))['type'], 'host');
  });

  test('a read crosses back as it went', () {
    final again = VirtRust.hardware(jsonDecode(jsonEncode(VirtRust.hardwareJson(vm))));
    expect(again, vm);
  });

  test('an issue sbm_virt names maps back; each one is said', () {
    expect(VirtHwIssue.ofRust('disk_shrink'), VirtHwIssue.diskShrink);
    expect(VirtHwIssue.ofRust('not_offered'), VirtHwIssue.notOffered);
    expect(VirtHwIssue.ofRust('what'), VirtHwIssue.unsupported);
    expect(VirtHwIssue.ofRust(null), isNull);
    for (final i in VirtHwIssue.values) {
      expect(virtHwIssueText(i), isNotEmpty, reason: i.name);
    }
  });

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
}
