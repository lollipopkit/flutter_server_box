import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_backup.dart';
import 'package:server_box/data/model/virt/virt_backup_schedule.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';

import '../../helpers/rust_lib_helper.dart';

const _pool = VirtStoragePool(
  id: 'pve/local',
  name: 'local',
  node: 'pve',
  type: 'dir',
  content: ['backup', 'iso', 'images'],
);
const _shared = VirtStoragePool(
  id: 'pve/nfs',
  name: 'nfs-backup',
  node: 'pve',
  type: 'nfs',
  content: ['backup', 'images'],
  shared: true,
);
const _backupOnly = VirtStoragePool(
  id: 'pve/local2',
  name: 'local',
  node: 'pve',
  type: 'dir',
  content: ['backup', 'iso'],
);

void main() {
  setUpAll(initRustLibForTest);

  // Reading `/cluster/backup` and the schedule's rules are
  // `sbm_virt::backup`'s (crates/sbm_virt/tests/backup.rs and
  // pve_backup.rs); what is left here is the glue.
  group('the rules through FFI', () {
    test('a schedule: empty, not one, or one PVE would take', () {
      expect(virtScheduleIssue(''), VirtBackupScheduleIssue.empty);
      expect(virtScheduleIssue('   '), VirtBackupScheduleIssue.empty);
      expect(virtScheduleIssue('02:30 mon'), VirtBackupScheduleIssue.invalid);
      expect(virtScheduleIssue(r'$(id)'), VirtBackupScheduleIssue.invalid);
      expect(virtScheduleIssue('mon..fri 02:30'), isNull);
      expect(virtScheduleIssue('daily'), isNull);
    });

    test("a guest's own plan: exactly that VMID, not all, not a pool", () {
      const own = VirtBackupJob(id: 'a', vmids: [911]);
      expect(own.takesOnly(911), isTrue);
      expect(own.takesOnly(912), isFalse);
      expect(own.takesOnly(null), isFalse);
      expect(const VirtBackupJob(id: 'b', vmids: [911, 912]).takesOnly(911), isFalse);
      expect(const VirtBackupJob(id: 'c', all: true).takesOnly(911), isFalse);
      expect(const VirtBackupJob(id: 'd', pool: 'p', vmids: [911]).takesOnly(911), isFalse);
    });

    test('a refusal says which rule', () {
      for (final issue in [
        'schedule_empty',
        'schedule_invalid',
        'storage',
        'mode',
        'compress',
        'guests',
        'node_offline',
        'not_stopped',
        'not_found',
        'unsupported',
      ]) {
        expect(virtBackupIssueText(issue), isNotEmpty, reason: issue);
      }
      expect(virtBackupIssueText(null), isNull);
    });
  });

  group('a clone target', () {
    const empty = <VirtStoragePool>[];

    test('a linked clone cannot name a storage or a node', () {
      expect(
        virtCloneStorageIssue(
          storages: const [_pool],
          storage: 'local',
          full: false,
        ),
        VirtCreateIssue.cloneLinkedTarget,
      );
      expect(
        virtCloneStorageIssue(
          storages: const [_pool],
          storage: null,
          full: false,
          targetNode: 'pve2',
        ),
        isNull,
        reason: 'no storage named: nothing to refuse here',
      );
    });

    test('a storage that is not there, or holds no images', () {
      expect(
        virtCloneStorageIssue(
          storages: const [_pool],
          storage: 'gone',
          full: true,
        ),
        VirtCreateIssue.cloneStorage,
      );
      expect(
        virtCloneStorageIssue(
          storages: const [_backupOnly],
          storage: 'local',
          full: true,
        ),
        VirtCreateIssue.cloneStorageContent,
      );
      expect(
        virtCloneStorageIssue(
          storages: empty,
          storage: null,
          full: true,
        ),
        isNull,
        reason: 'no target picked is the source\'s own storage',
      );
    });

    test('another node needs a shared storage', () {
      expect(
        virtCloneStorageIssue(
          storages: const [_pool],
          storage: 'local',
          full: true,
          targetNode: 'pve2',
        ),
        VirtCreateIssue.cloneStorageShared,
      );
      expect(
        virtCloneStorageIssue(
          storages: const [_shared],
          storage: 'nfs-backup',
          full: true,
          targetNode: 'pve2',
        ),
        isNull,
      );
      // The same storage on the source's own node is fine either way.
      expect(
        virtCloneStorageIssue(
          storages: const [_pool],
          storage: 'local',
          full: true,
          targetNode: 'pve',
        ),
        VirtCreateIssue.cloneStorageShared,
        reason: 'the check is about the target node, not the source one',
      );
    });

    test('a node the host does not have', () {
      const nodes = [VirtNode(name: 'pve'), VirtNode(name: 'pve2')];
      expect(
        virtCloneNodeIssue(
          nodes: nodes,
          targetNode: 'pve2',
          sourceNode: 'pve',
        ),
        isNull,
      );
      expect(
        virtCloneNodeIssue(
          nodes: nodes,
          targetNode: 'gone',
          sourceNode: 'pve',
        ),
        VirtCreateIssue.cloneNodeUnknown,
      );
      // The source's own node is never a target.
      expect(
        virtCloneNodeIssue(nodes: nodes, targetNode: 'pve', sourceNode: 'pve'),
        isNull,
      );
      // Nothing known about the nodes: the host answers.
      expect(
        virtCloneNodeIssue(nodes: const [], targetNode: 'x', sourceNode: 'pve'),
        isNull,
      );
    });
  });
}
