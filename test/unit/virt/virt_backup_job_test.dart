import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/virt/pve_resources.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_backup_schedule.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';

/// The payloads `test/fixtures/pve/` holds, as PVE 9.2.2 answered them.
Object? fixture(String name) => jsonDecode(
  File('test/fixtures/pve/$name').readAsStringSync(),
);

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
  group('backup jobs as PVE lists them', () {
    test('a job that names its guests: every field read', () {
      final raw = fixture('backup_job_fields.json')! as List;
      final job = PveResources.parseBackupJobs(raw).single;
      expect(job.id, 'sbxe2e-capture');
      expect(job.schedule, 'mon..fri 02:30');
      expect(job.storage, 'local');
      expect((job.mode, job.compress), ('snapshot', 'zstd'));
      expect(job.enabled, isTrue);
      expect(job.all, isFalse);
      expect(job.vmids, [911, 912]);
      expect(job.exclude, isEmpty);
      expect(job.comment, 'sb e2e capture');
      expect(job.notesTemplate, 'sb {{guestname}} {{vmid}}');
      expect(job.mailNotification, 'failure');
      // PVE answers `prune-backups` as an object of strings.
      expect(job.prune, 'keep-daily=4,keep-last=7');
      expect(job.keep, job.prune);
      expect(job.selectionLabel, '911,912');
      // The node and the pool are not in this answer: PVE leaves them out
      // when they are unset (`next-run` and `type` are PVE's own).
      expect(job.node, isNull);
      expect(job.pool, isNull);
    });

    test('a job that takes every guest, less what it excludes', () {
      final raw = fixture('backup_jobs_all.json')! as List;
      final jobs = PveResources.parseBackupJobs(raw);
      expect(jobs, hasLength(2));
      final all = jobs.firstWhere((j) => j.id == 'sbxe2e-all');
      expect(all.all, isTrue);
      expect(all.exclude, [912]);
      expect(all.vmids, isEmpty);
      expect(all.enabled, isFalse);
      expect(all.selectionLabel, 'all');
      expect(all.schedule, 'sat 03:00');
      expect(all.mode, 'stop');
      expect(all.compress, 'lzo');
      // `prune-backups` is absent: neither the storage's nor the node's own.
      expect(all.prune, isNull);
    });

    test('which guests a job takes', () {
      final jobs = PveResources.parseBackupJobs(
        fixture('backup_jobs_all.json')! as List,
      );
      final named = jobs.firstWhere((j) => j.id == 'sbxe2e-capture');
      expect(named.takes(911), isTrue);
      expect(named.takes(912), isTrue);
      expect(named.takes(913), isFalse);

      final all = jobs.firstWhere((j) => j.id == 'sbxe2e-all');
      expect(all.takes(911), isTrue);
      expect(all.takes(912), isFalse, reason: 'excluded');
      expect(all.takes(913), isTrue);

      // A guest's Plan group: only the jobs that take it.
      final forGuest = PveResources.parseBackupJobs(
        fixture('backup_jobs_all.json')! as List,
        vmid: 912,
      );
      expect(forGuest.map((j) => j.id), ['sbxe2e-capture']);
      expect(
        PveResources.parseBackupJobs(
          fixture('backup_jobs_all.json')! as List,
          vmid: 913,
        ).map((j) => j.id),
        ['sbxe2e-all'],
      );
    });

    test('a job by pool names none of its guests', () {
      final raw = [
        {'id': 'pool-job', 'type': 'vzdump', 'pool': 'prod', 'storage': 'local'},
      ];
      final job = PveResources.parseBackupJobs(raw).single;
      expect(job.pool, 'prod');
      expect(job.selectionLabel, 'pool:prod');
      // Which guests a pool holds is not in this answer, so a guest's own
      // Plan group cannot claim one takes it.
      expect(job.takes(100), isFalse);
      expect(PveResources.parseBackupJobs(raw, vmid: 100), isEmpty);
    });
  });

  group('the schedule', () {
    test('what PVE takes, this accepts', () {
      for (final ok in [
        '02:30',
        '02:30:15',
        'mon..fri 02:30',
        'mon,wed 03:00',
        'sat 03:00',
        '*-*-* 04:00',
        'daily',
        'hourly',
        'weekly',
        'monthly',
        'yearly',
        '*:0/15',
        '*/5',
        'mon',
        'mon 02:30:15',
        '0/15',
        'mon..sun 02:30',
        // From PVE's documentation (Schedule Format), not put to the host:
        // a weekday, a date and a time together, and ranges in the date and
        // the time.
        'sat *-1..7 15:00',
        'mon..fri 8..17,22:0/15',
        '2015-10-21 01:00',
        'mon *-*-* 02:00',
      ]) {
        expect(virtScheduleIssue(ok), isNull, reason: ok);
      }
      // PVE's own parser is looser than a range check on the hour: the form
      // sends this and the host answers (checked with `schedule-analyze` on
      // PVE 9.2.2 — `mon 59:59` is taken, `mon 60:59` is not).
      expect(virtScheduleIssue('mon 25:00'), isNull);
    });

    test('what PVE refuses, this refuses first', () {
      for (final bad in [
        '',
        '   ',
        'nope',
        '02:30 mon',
        'Mon-Fri 02:30',
        '* 02:30',
        'mon 02:70',
        'mon..xyz 02:30',
        '02:30; rm -rf /',
        'a\nb',
        'daily 02:30',
        'mon 02:30 extra',
        '02:30 *-*-*',
        'mon mon',
        // None of these are a calendar event, and one of them would be an
        // argument to `pvesh` had the value not been refused: the host is
        // never asked with them.
        '--help',
        r'$(id)',
        '`id`',
        'mon 60:00',
        'mon 59:60',
        // A step too long for an int: invalid, not a FormatException.
        '*/999999999999999999999999',
        'mon *:0/999999999999999999999999',
      ]) {
        expect(virtScheduleIssue(bad), isNotNull, reason: bad);
      }
    });

    test('every value the host was asked about, and its answer', () {
      // The table below is `GET /cluster/jobs/schedule-analyze` on PVE
      // 9.2.2, one line per value: what the host takes (`ok`) and what it
      // refuses (`REJECT`). The local check has to agree in both directions
      // — a value it passes on that the host refuses is a round trip, and a
      // value it refuses that the host takes is a schedule the user cannot
      // write.
      const answers = {
        '02:30': true,
        '02:30:15': true,
        'mon..fri 02:30': true,
        'mon,wed 03:00': true,
        'sat 03:00': true,
        '*-*-* 04:00': true,
        'daily': true,
        'hourly': true,
        'weekly': true,
        'monthly': true,
        'yearly': true,
        '*:0/15': true,
        '*/5': true,
        'mon': true,
        'mon 25:00': true,
        'mon 02:30:15': true,
        '0/15': true,
        'mon..sun 02:30': true,
        'nope': false,
        '02:30 mon': false,
        'Mon-Fri 02:30': false,
        '* 02:30': false,
        'mon 02:70': false,
        'mon..xyz 02:30': false,
        '02:30; rm -rf /': false,
        '--help': false,
        r'$(id)': false,
        '`id`': false,
        'mon 02:30 extra': false,
        '   ': false,
        'mon 60:00': false,
        'mon 59:60': false,
      };
      for (final MapEntry(:key, :value) in answers.entries) {
        final issue = virtScheduleIssue(key);
        expect(
          issue == null,
          value,
          reason: '$key: the host says $value, this says $issue',
        );
      }
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
