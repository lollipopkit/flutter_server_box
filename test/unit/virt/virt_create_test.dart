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

  group('cloud images and cloud-init', () {
    const image = VirtVolume(
      id: 'noble.img',
      name: 'noble.img',
      format: 'qcow2',
      capacity: 3758096384,
    );
    VirtCreateSpec withCi(
      VirtCloudInit ci, {
      VirtVolume? img = image,
      int diskGiB = 8,
    }) => VirtCreateSpec(
      kind: VirtGuestKind.qemu,
      name: 'ci-01',
      vmid: 105,
      cores: 1,
      memoryMiB: 1024,
      storage: _pool,
      diskGiB: diskGiB,
      image: img,
      cloudInit: ci,
    );
    VirtCreateIssue? issue(VirtCreateSpec s, [VirtHostKind h = VirtHostKind.libvirt]) =>
        virtCreateIssue(s, host: h, guests: const []);
    const ok = VirtCloudInit(user: 'debian', password: 'pw', hostname: 'ci-01');

    test('the image: chosen, and no bigger than the disk', () {
      expect(issue(withCi(ok)), isNull);
      expect(issue(withCi(ok, img: null)), VirtCreateIssue.image);
      expect(issue(withCi(ok, diskGiB: 3)), VirtCreateIssue.imageSize);
      expect(issue(withCi(ok, diskGiB: 4)), isNull);
    });

    test('the account, its way in, the hostname and the address', () {
      VirtCreateIssue? ci(VirtCloudInit c, [VirtHostKind h = VirtHostKind.libvirt]) =>
          issue(withCi(c), h);
      expect(ci(const VirtCloudInit(user: 'Root', password: 'x', hostname: 'h')), VirtCreateIssue.ciUser);
      expect(ci(const VirtCloudInit(user: '1st', password: 'x', hostname: 'h')), VirtCreateIssue.ciUser);
      expect(ci(const VirtCloudInit(user: 'u', hostname: 'h')), VirtCreateIssue.ciCredentials);
      expect(
        ci(const VirtCloudInit(user: 'u', sshKeys: 'not a key', hostname: 'h')),
        VirtCreateIssue.sshKeys,
      );
      expect(
        ci(const VirtCloudInit(user: 'u', sshKeys: 'ssh-ed25519 AAAA me\n\n', hostname: 'h')),
        isNull,
      );
      expect(ci(const VirtCloudInit(user: 'u', password: 'x', hostname: 'ci_01')), VirtCreateIssue.ciHostname);
      // PVE names the host after the VM: no hostname of its own.
      expect(ci(const VirtCloudInit(user: 'u', password: 'x'), VirtHostKind.pve), isNull);
      VirtCloudInit net({String? address, String? gateway, List<String> dns = const [], String? search}) =>
          VirtCloudInit(
            user: 'u',
            password: 'x',
            hostname: 'h',
            address: address,
            gateway: gateway,
            dns: dns,
            searchDomain: search,
          );
      expect(ci(net(address: '10.0.0.5')), VirtCreateIssue.ciAddress);
      expect(ci(net(address: '10.0.0.256/24')), VirtCreateIssue.ciAddress);
      expect(ci(net(address: '10.0.0.5/33')), VirtCreateIssue.ciAddress);
      expect(ci(net(address: '10.0.0.5/24', gateway: 'gw')), VirtCreateIssue.ciGateway);
      expect(ci(net(address: '10.0.0.5/24', gateway: '10.0.0.1')), isNull);
      expect(ci(net(dns: ['1.1.1.1', '2606:4700::1111'])), isNull);
      expect(ci(net(dns: ['one.one'])), VirtCreateIssue.ciDns);
      expect(ci(net(search: 'lab example')), VirtCreateIssue.ciSearch);
      // Never printed.
      expect('${net()}', isNot(contains('x,')));
      expect('${net()}', contains('[redacted]'));
    });

    test('which volumes are cloud images, and where they are looked for', () {
      bool lv(VirtVolume v) => virtIsCloudImage(v, VirtHostKind.libvirt);
      bool pve(VirtVolume v) => virtIsCloudImage(v, VirtHostKind.pve);
      expect(lv(image), isTrue);
      expect(lv(const VirtVolume(id: 'a', name: 'a.raw', format: 'raw')), isTrue);
      expect(lv(const VirtVolume(id: 'a', name: 'seed.iso', format: 'raw')), isFalse);
      expect(lv(const VirtVolume(id: 'a', name: 'a.iso', format: 'iso')), isFalse);
      expect(
        lv(const VirtVolume(id: 'a', name: 'a.qcow2', format: 'qcow2', users: [VirtGuestRef(guestId: 'g')])),
        isFalse,
      );
      expect(pve(const VirtVolume(id: 'l:import/a.qcow2', name: 'a.qcow2', format: 'qcow2', content: 'import')), isTrue);
      expect(pve(const VirtVolume(id: 'l:import/a.ova', name: 'a.ova', format: 'ova+vmdk', content: 'import')), isFalse);
      expect(pve(const VirtVolume(id: 'l:iso/a.img', name: 'a.img', format: 'raw', content: 'iso')), isFalse);
      const pools = [
        VirtStoragePool(id: 'pve/local', name: 'local', node: 'pve', type: 'dir', content: ['iso', 'import']),
        VirtStoragePool(id: 'pve/nas', name: 'nas', node: 'pve', type: 'nfs', content: ['iso']),
        VirtStoragePool(id: 'pve2/local', name: 'local', node: 'pve2', type: 'dir', content: ['import']),
      ];
      expect(
        [for (final p in virtImageStorages(pools, host: VirtHostKind.pve, node: 'pve')) p.id],
        ['pve/local'],
      );
    });
  });

  group('editing cloud-init', () {
    const state = VirtCloudInitState(user: 'sbxe', passwordSet: true, revision: 'r');
    VirtCreateIssue? issue(VirtCloudInitEdit e, {VirtCloudInitState s = state, VirtHostKind host = VirtHostKind.pve}) =>
        virtCloudInitEditIssue(s, e, host: host);

    test('the password set is a way in, unless it is removed', () {
      expect(issue(const VirtCloudInitEdit(VirtCloudInit(user: 'sbxe'))), isNull);
      expect(
        issue(const VirtCloudInitEdit(VirtCloudInit(user: 'sbxe'), removePassword: true)),
        VirtCreateIssue.ciCredentials,
      );
      expect(
        issue(const VirtCloudInitEdit(
          VirtCloudInit(user: 'sbxe', sshKeys: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 me'),
          removePassword: true,
        )),
        isNull,
      );
      // None set: a new one or a key.
      const bare = VirtCloudInitState(user: 'sbxe', revision: 'r');
      expect(issue(const VirtCloudInitEdit(VirtCloudInit(user: 'sbxe')), s: bare), VirtCreateIssue.ciCredentials);
      expect(issue(const VirtCloudInitEdit(VirtCloudInit(user: 'sbxe', password: 'x')), s: bare), isNull);
    });

    test('the rest as at creation: user, hostname on libvirt, address', () {
      expect(issue(const VirtCloudInitEdit(VirtCloudInit(user: 'Root'))), VirtCreateIssue.ciUser);
      expect(
        issue(const VirtCloudInitEdit(VirtCloudInit(user: 'sbxe', hostname: 'a_b')), host: VirtHostKind.libvirt),
        VirtCreateIssue.ciHostname,
      );
      expect(
        issue(const VirtCloudInitEdit(VirtCloudInit(user: 'sbxe', hostname: 'ok')), host: VirtHostKind.libvirt),
        isNull,
      );
      expect(
        issue(const VirtCloudInitEdit(VirtCloudInit(user: 'sbxe', address: '10.0.0.5'))),
        VirtCreateIssue.ciAddress,
      );
    });
  });
}
