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

  test('tree: a lost parent or a cycle is still listed, once', () {
    final tree = virtSnapshotTree([
      _s('orphan', 'deleted'),
      _s('x', 'y'),
      _s('y', 'x'),
      _s('self', 'self'),
    ]);
    expect(tree.map((e) => e.$1.name), unorderedEquals(['orphan', 'x', 'y', 'self']));
    expect(tree.firstWhere((e) => e.$1.name == 'orphan').$2, 0);
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
