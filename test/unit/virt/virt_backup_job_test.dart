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

    test('a node the host does not have', () {
      // The rest of the node checks are `sbm_virt`'s (tests/create.rs); this
      // is the answer crossing into a [VirtCreateIssue].
      const nodes = [VirtNode(name: 'pve'), VirtNode(name: 'pve2')];
      expect(
        virtCloneNodeIssue(
          nodes: nodes,
          targetNode: 'gone',
          sourceNode: 'pve',
        ),
        VirtCreateIssue.cloneNodeUnknown,
      );
    });
  });
}
