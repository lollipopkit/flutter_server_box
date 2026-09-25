import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';

const _pool = VirtStoragePool(id: 'images', name: 'images', type: 'dir');

VirtCreateSpec _spec({
  VirtGuestKind kind = VirtGuestKind.qemu,
  String name = 'web-02',
  int? vmid = 105,
  int cores = 2,
  int memoryMiB = 2048,
  VirtStoragePool storage = _pool,
  int diskGiB = 32,
  VirtVolume? media,
  String? password,
  String? sshKeys,
}) => VirtCreateSpec(
  kind: kind,
  name: name,
  node: 'pve',
  vmid: vmid,
  cores: cores,
  memoryMiB: memoryMiB,
  storage: storage,
  diskGiB: diskGiB,
  media: media,
  password: password,
  sshKeys: sshKeys,
);

const _guests = [
  VirtGuest(
    id: 'qemu/100',
    name: 'debian-libvirt',
    kind: VirtGuestKind.qemu,
    state: VirtGuestState.running,
    vmid: 100,
  ),
];

VirtCreateIssue? _libvirt(VirtCreateSpec s) =>
    virtCreateIssue(s, host: VirtHostKind.libvirt, guests: _guests);

VirtCreateIssue? _pve(VirtCreateSpec s, {int? maxCores}) => virtCreateIssue(
  s,
  host: VirtHostKind.pve,
  guests: _guests,
  maxCores: maxCores,
);

void main() {
  test('names: what each host takes', () {
    expect(_libvirt(_spec()), isNull);
    expect(_libvirt(_spec(name: '')), VirtCreateIssue.nameEmpty);
    expect(_libvirt(_spec(name: 'debian-libvirt')), VirtCreateIssue.nameTaken);
    expect(_libvirt(_spec(name: 'win_11.test')), isNull);
    // What AppArmor, vol-create-as's XML or a file name would refuse.
    for (final bad in [
      "it's",
      'a"b',
      'a&b',
      'a<b',
      'a b',
      '-rf',
      '.hidden',
      'a/b',
      'x' * 64,
    ]) {
      expect(_libvirt(_spec(name: bad)), VirtCreateIssue.nameInvalid, reason: bad);
    }
    // PVE: a DNS name.
    expect(_pve(_spec(name: 'web.lan')), isNull);
    for (final bad in ['win_11', 'a..b', '-a', 'a-', 'x' * 64]) {
      expect(_pve(_spec(name: bad)), VirtCreateIssue.nameInvalid, reason: bad);
    }
  });

  test('VMIDs, cores, memory, disk', () {
    expect(_pve(_spec(vmid: null)), VirtCreateIssue.vmidInvalid);
    expect(_pve(_spec(vmid: 99)), VirtCreateIssue.vmidInvalid);
    expect(_pve(_spec(vmid: 100)), VirtCreateIssue.vmidTaken);
    // libvirt has none to check.
    expect(_libvirt(_spec(vmid: null)), isNull);
    expect(_pve(_spec(cores: 0)), VirtCreateIssue.cores);
    expect(_pve(_spec(cores: 13), maxCores: 12), VirtCreateIssue.cores);
    expect(_pve(_spec(cores: 12), maxCores: 12), isNull);
    expect(_pve(_spec(memoryMiB: 64)), VirtCreateIssue.memory);
    expect(
      _pve(
        _spec(
          kind: VirtGuestKind.lxc,
          memoryMiB: 64,
          media: const VirtVolume(id: 't', name: 't'),
          password: 'secret',
        ),
      ),
      isNull,
    );
    expect(_pve(_spec(diskGiB: 0)), VirtCreateIssue.diskSize);
    expect(
      _pve(_spec(storage: _pool.copyWith(active: false))),
      VirtCreateIssue.storage,
    );
  });

  test('a container: a template, and a root login', () {
    const t = VirtVolume(id: 'local:vztmpl/a.tar.xz', name: 'a.tar.xz');
    VirtCreateIssue? lxc({VirtVolume? media = t, String? pw, String? keys}) =>
        _pve(
          _spec(
            kind: VirtGuestKind.lxc,
            media: media,
            password: pw,
            sshKeys: keys,
          ),
        );
    expect(lxc(media: null, pw: 'secret'), VirtCreateIssue.template);
    expect(lxc(), VirtCreateIssue.credentials);
    expect(lxc(pw: 'abcd'), VirtCreateIssue.password);
    expect(lxc(pw: 'abcde'), isNull);
    expect(lxc(keys: 'ssh-ed25519 AAAAC3NzaC1 me@host'), isNull);
    expect(
      lxc(keys: 'ssh-ed25519 AAAA a\n\necdsa-sha2-nistp256 AAAA b\n'),
      isNull,
    );
    expect(lxc(keys: 'not a key'), VirtCreateIssue.sshKeys);
    expect(lxc(keys: '-----BEGIN OPENSSH PRIVATE KEY-----'), VirtCreateIssue.sshKeys);
  });

  test('where disks, media and NICs can go', () {
    const pools = [
      VirtStoragePool(
        id: 'pve/local',
        name: 'local',
        node: 'pve',
        type: 'dir',
        content: ['iso', 'vztmpl', 'backup'],
      ),
      VirtStoragePool(
        id: 'pve/local-lvm',
        name: 'local-lvm',
        node: 'pve',
        type: 'lvmthin',
        content: ['images', 'rootdir'],
      ),
      VirtStoragePool(
        id: 'pve2/local-lvm',
        name: 'local-lvm',
        node: 'pve2',
        type: 'lvmthin',
        content: ['images', 'rootdir'],
      ),
      VirtStoragePool(
        id: 'pve/off',
        name: 'off',
        node: 'pve',
        type: 'dir',
        content: ['images'],
        enabled: false,
      ),
    ];
    List<String> ids(List<VirtStoragePool> l) => [for (final p in l) p.id];
    expect(
      ids(virtDiskStorages(pools, host: VirtHostKind.pve, kind: VirtGuestKind.qemu, node: 'pve')),
      ['pve/local-lvm'],
    );
    expect(
      ids(virtMediaStorages(pools, host: VirtHostKind.pve, kind: VirtGuestKind.lxc, node: 'pve')),
      ['pve/local'],
    );
    const lv = [
      VirtStoragePool(id: 'images', name: 'images', type: 'dir'),
      VirtStoragePool(id: 'lun', name: 'lun', type: 'iscsi'),
      VirtStoragePool(id: 'off', name: 'off', type: 'dir', active: false),
    ];
    expect(
      ids(virtDiskStorages(lv, host: VirtHostKind.libvirt, kind: VirtGuestKind.qemu)),
      ['images'],
    );
    expect(virtLibvirtDiskFormat('dir'), 'qcow2');
    expect(virtLibvirtDiskFormat('logical'), 'raw');

    expect(virtIsMedia(const VirtVolume(id: 'a', name: 'Debian.ISO'), VirtGuestKind.qemu), isTrue);
    expect(virtIsMedia(const VirtVolume(id: 'a', name: 'disk.qcow2'), VirtGuestKind.qemu), isFalse);
    expect(
      virtIsMedia(const VirtVolume(id: 'a', name: 'x', content: 'vztmpl'), VirtGuestKind.lxc),
      isTrue,
    );
    expect(
      virtIsMedia(const VirtVolume(id: 'a', name: 'x.iso', content: 'iso'), VirtGuestKind.lxc),
      isFalse,
    );

    const nets = [
      VirtNetwork(id: 'pve/vmbr0', name: 'vmbr0', node: 'pve', mode: 'bridge'),
      VirtNetwork(id: 'pve/bond0', name: 'bond0', node: 'pve', mode: 'bond'),
      VirtNetwork(id: 'pve2/vmbr0', name: 'vmbr0', node: 'pve2', mode: 'bridge'),
    ];
    expect(
      [for (final n in virtCreateNetworks(nets, host: VirtHostKind.pve, node: 'pve')) n.id],
      ['pve/vmbr0'],
    );
  });
}
