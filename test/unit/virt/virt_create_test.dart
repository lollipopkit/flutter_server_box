/// The create and clone rules are `sbm_virt::create`'s
/// (`crates/sbm_virt/tests/create.rs`): this is how a spec crosses to them
/// and how their answers come back.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/model/virt/virt_rust.dart';

import '../../helpers/rust_lib_helper.dart';

const _pool = VirtStoragePool(id: 'images', name: 'images', type: 'dir');
const _isoPool = VirtStoragePool(id: 'isos', name: 'isos', type: 'dir');

VirtCreateSpec _spec({
  VirtGuestKind kind = VirtGuestKind.qemu,
  String name = 'web-02',
  int? vmid = 105,
  VirtPoolVolume? media,
  VirtPoolVolume? image,
  String? password,
  String? sshKeys,
  VirtCloudInit? cloudInit,
  int diskGiB = 32,
}) => VirtCreateSpec(
  kind: kind,
  name: name,
  node: 'pve',
  vmid: vmid,
  cores: 2,
  memoryMiB: 2048,
  storage: _pool,
  diskGiB: diskGiB,
  media: media,
  image: image,
  password: password,
  sshKeys: sshKeys,
  cloudInit: cloudInit,
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

void main() {
  setUpAll(initRustLibForTest);

  test('a spec crosses by id: pool, volumes, keys by line, cloud-init', () {
    const iso = VirtVolume(id: 'd.iso', name: 'd.iso');
    final json = VirtRust.specJson(
      _spec(
        media: (pool: _isoPool, volume: iso),
        sshKeys: ' ssh-ed25519 AAAA a \n\nssh-ed25519 BBBB b\n',
        cloudInit: const VirtCloudInit(user: 'u', sshKeys: 'ssh-ed25519 AAAA a'),
      ),
    );
    expect(json['storage'], 'images');
    expect(json['media'], {'pool': 'isos', 'volume': 'd.iso'});
    expect(json['image'], isNull);
    expect(json['ssh_keys'], ['ssh-ed25519 AAAA a', 'ssh-ed25519 BBBB b']);
    expect((json['cloud_init']! as Map)['ssh_keys'], ['ssh-ed25519 AAAA a']);
  });

  test('an issue name maps back; an unknown one is unsupported', () {
    expect(VirtCreateIssue.ofRust('name_taken'), VirtCreateIssue.nameTaken);
    expect(VirtCreateIssue.ofRust('clone_storage_shared'), VirtCreateIssue.cloneStorageShared);
    expect(VirtCreateIssue.ofRust('is_template'), VirtCreateIssue.isTemplate);
    expect(VirtCreateIssue.ofRust('something_new'), VirtCreateIssue.unsupported);
    expect(VirtCreateIssue.ofRust(null), isNull);
    for (final i in VirtCreateIssue.values) {
      expect(virtCreateIssueText(i), isNotEmpty, reason: i.name);
    }
  });

  test('the rules answer through the wrapper', () {
    expect(_libvirt(_spec()), isNull);
    expect(_libvirt(_spec(name: 'debian-libvirt')), VirtCreateIssue.nameTaken);
    expect(_libvirt(_spec(name: 'a b')), VirtCreateIssue.nameInvalid);
    expect(
      virtCreateIssue(
        _spec(vmid: 100),
        host: VirtHostKind.pve,
        guests: _guests,
        pools: [_pool.copyWith(node: 'pve', content: ['images'])],
      ),
      VirtCreateIssue.vmidTaken,
    );
    // A container's root login.
    const t = VirtVolume(id: 'local:vztmpl/a.tar.xz', name: 'a.tar.xz', content: 'vztmpl');
    final pools = [
      _pool.copyWith(node: 'pve', content: ['rootdir']),
      _isoPool.copyWith(node: 'pve', content: ['vztmpl']),
    ];
    VirtCreateIssue? ct({String? pw}) => virtCreateIssue(
      _spec(kind: VirtGuestKind.lxc, media: (pool: pools[1], volume: t), password: pw),
      host: VirtHostKind.pve,
      guests: _guests,
      pools: pools,
    );
    expect(ct(), VirtCreateIssue.credentials);
    expect(ct(pw: 'abcd'), VirtCreateIssue.password);
    expect(ct(pw: 'abcde'), isNull);
    // A cloud image no bigger than the disk, and cloud-init's address.
    const image = VirtVolume(id: 'noble.img', name: 'noble.img', format: 'qcow2', capacity: 3758096384);
    VirtCreateIssue? ci({int disk = 8, String? address}) => _libvirt(
      _spec(
        diskGiB: disk,
        image: (pool: _pool, volume: image),
        cloudInit: VirtCloudInit(user: 'u', password: 'x', hostname: 'h', address: address),
      ),
    );
    expect(ci(), isNull);
    expect(ci(disk: 3), VirtCreateIssue.imageSize);
    expect(ci(address: '10.0.0.5'), VirtCreateIssue.ciAddress);
  });

  test('where disks, media, images and NICs go', () {
    const pools = [
      VirtStoragePool(id: 'pve/local', name: 'local', node: 'pve', type: 'dir', content: ['iso', 'vztmpl', 'import']),
      VirtStoragePool(id: 'pve/local-lvm', name: 'local-lvm', node: 'pve', type: 'lvmthin', content: ['images', 'rootdir']),
      VirtStoragePool(id: 'pve2/local-lvm', name: 'local-lvm', node: 'pve2', type: 'lvmthin', content: ['images']),
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
    expect(ids(virtImageStorages(pools, host: VirtHostKind.pve, node: 'pve')), ['pve/local']);
    expect(virtIsMedia(const VirtVolume(id: 'a', name: 'Debian.ISO'), VirtGuestKind.qemu), isTrue);
    expect(
      virtIsCloudImage(const VirtVolume(id: 'a', name: 'a.qcow2', format: 'qcow2'), VirtHostKind.libvirt),
      isTrue,
    );
    const nets = [
      VirtNetwork(id: 'pve/vmbr0', name: 'vmbr0', node: 'pve', mode: 'bridge'),
      VirtNetwork(id: 'pve/bond0', name: 'bond0', node: 'pve', mode: 'bond'),
    ];
    expect(
      [for (final n in virtCreateNetworks(nets, host: VirtHostKind.pve, node: 'pve')) n.id],
      ['pve/vmbr0'],
    );
    expect(virtLibvirtDiskFormat('logical'), 'raw');
  });

  test('a clone: its name, storage and node', () {
    expect(virtCloneNameIssue('', VirtHostKind.pve), VirtCreateIssue.nameEmpty);
    expect(virtCloneNameIssue('a_b', VirtHostKind.pve), VirtCreateIssue.nameInvalid);
    expect(virtCloneNameIssue('a_b', VirtHostKind.libvirt), isNull);
    const ct = VirtStoragePool(id: 'pve/ct', name: 'ct', node: 'pve', type: 'dir', content: ['rootdir']);
    expect(
      virtCloneStorageIssue(storages: const [ct], storage: 'ct', full: true, kind: VirtGuestKind.lxc),
      isNull,
    );
    expect(
      virtCloneStorageIssue(storages: const [ct], storage: 'ct', full: true),
      VirtCreateIssue.cloneStorageContent,
    );
    expect(
      virtCloneNodeIssue(nodes: const [VirtNode(name: 'pve')], targetNode: 'gone', sourceNode: 'pve'),
      VirtCreateIssue.cloneNodeUnknown,
    );
  });
}
