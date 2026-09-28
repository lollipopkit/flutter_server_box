/// The snapshot rules both backends share: how the list is ordered into a
/// tree, which names a new one may have, and when it may hold memory.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';

VirtGuestSnapshot _s(String name, [String? parent, int day = 1]) =>
    VirtGuestSnapshot(
      name: name,
      parent: parent,
      createdAt: DateTime(2026, 9, day),
    );

void main() {
  group('networks', _networkAddress);

  test('tree: depth-first, siblings oldest first', () {
    final tree = virtSnapshotTree([
      _s('c', 'a', 3),
      _s('b', 'a', 2),
      _s('a'),
      _s('d', 'b', 4),
      _s('z', null, 9),
    ]);
    expect(tree.map((e) => '${e.$1.name}${e.$2}'), ['a0', 'b1', 'd2', 'c1', 'z0']);
  });

  test('tree: undated siblings after dated ones, whatever the input order', () {
    final a = _s('a', null, 3);
    final c = _s('c', null, 1);
    const b = VirtGuestSnapshot(name: 'b');
    const d = VirtGuestSnapshot(name: 'd');
    for (final input in [
      [a, b, c, d],
      [b, c, d, a],
      [c, d, a, b],
      [d, a, b, c],
      [a, c, b, d],
      [d, b, c, a],
    ]) {
      expect(
        virtSnapshotTree(input).map((e) => e.$1.name),
        ['c', 'a', 'b', 'd'],
        reason: input.map((s) => s.name).join(),
      );
    }
  });

  test('tree: a lost parent or a cycle is still listed, once', () {
    final tree = virtSnapshotTree([
      _s('orphan', 'deleted'),
      _s('x', 'y'),
      _s('y', 'x'),
      _s('under', 'y'),
      _s('self', 'self'),
    ]);
    expect(tree.map((e) => '${e.$1.name}${e.$2}'), ['orphan0', 'self0', 'x0', 'y1', 'under2']);
  });

  test('names: PVE\'s rule, and not one taken or reserved', () {
    final existing = [_s('base')];
    expect(virtSnapshotNameIssue('', existing), VirtSnapshotNameIssue.empty);
    for (final bad in ['1st', 'a', 'has space', 'semi;colon', 'dot.ted', 'x' * 41]) {
      expect(
        virtSnapshotNameIssue(bad, existing),
        VirtSnapshotNameIssue.invalid,
        reason: bad,
      );
    }
    expect(virtSnapshotNameIssue('base', existing), VirtSnapshotNameIssue.taken);
    expect(virtSnapshotNameIssue('current', existing), VirtSnapshotNameIssue.taken);
    for (final ok in ['ab', 'snap-1', 'pre_upgrade', 'A${'b' * 39}']) {
      expect(virtSnapshotNameIssue(ok, existing), isNull, reason: ok);
    }
  });

  test('memory: an active VM only; libvirt always, PVE by choice', () {
    const vm = VirtGuest(
      id: 'v',
      name: 'v',
      kind: VirtGuestKind.qemu,
      state: VirtGuestState.running,
    );
    const ct = VirtGuest(
      id: 'c',
      name: 'c',
      kind: VirtGuestKind.lxc,
      state: VirtGuestState.running,
    );
    const pve = VirtCapabilities(snapshots: true);
    const libvirt = VirtCapabilities(
      snapshots: true,
      snapshotMemoryRequired: true,
    );
    expect(
      virtSnapshotMemory(pve, vm, VirtGuestState.running),
      VirtSnapshotMemory.optional,
    );
    expect(
      virtSnapshotMemory(libvirt, vm, VirtGuestState.paused),
      VirtSnapshotMemory.always,
    );
    expect(
      virtSnapshotMemory(libvirt, vm, VirtGuestState.stopped),
      VirtSnapshotMemory.none,
    );
    expect(
      virtSnapshotMemory(pve, ct, VirtGuestState.running),
      VirtSnapshotMemory.none,
    );
  });
}

void _networkAddress() {
  test('a network\'s address is its IPv4 one, whatever comes first', () {
    const both = VirtNetwork(
      id: 'pve/vmbr1',
      name: 'vmbr1',
      mode: 'bridge',
      cidrs: ['fd00::1/64', '10.0.0.1/24'],
    );
    expect((both.ipv4Cidr, both.address, both.prefix), ('10.0.0.1/24', '10.0.0.1', 24));
    const v6 = VirtNetwork(id: 'n', name: 'n', mode: 'bridge', cidrs: ['fd00::1/64']);
    expect((v6.ipv4Cidr, v6.address, v6.prefix), (null, null, null));
  });
}
