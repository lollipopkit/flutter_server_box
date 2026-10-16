/// The Monitor tab's reading of `/alerts`, `/desk/notifications`, `/audit`,
/// `/live` and `/update` in the shapes the agent writes them. Which release
/// is the newest is Rust's (`sbm_parser::monitor_agent`).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor_overview.dart';
import 'package:server_box/view/page/monitor/audit.dart';

void main() {
  test('alerts: the rule, the reading and since when', () {
    final alerts = MonitorAlerts.fromJson({
      'checked_at': '2026-10-14T06:00:00+00:00',
      'alerts': [
        {
          'rule': 'High CPU',
          'monitor_type': 'cpu',
          'matcher': '>',
          'threshold': '90%',
          'value': '96.00%',
          'since': '2026-10-14T05:55:00+00:00',
        },
      ],
    });
    expect(alerts.checkedAt!.isAtSameMomentAs(DateTime.utc(2026, 10, 14, 6)), isTrue);
    final alert = alerts.alerts.single;
    expect((alert.rule, alert.value, alert.matcher, alert.threshold), ('High CPU', '96.00%', '>', '90%'));
    expect(alert.since!.isAtSameMomentAs(DateTime.utc(2026, 10, 14, 5, 55)), isTrue);
    // Before the agent's first check.
    expect(MonitorAlerts.fromJson({'checked_at': null, 'alerts': []}).checkedAt, isNull);
  });

  test('notifications: kind, params and read state', () {
    final notices = MonitorNotices.fromJson({
      'notifications': [
        {
          'id': 3,
          'created_at': '2026-10-14T06:00:00+00:00',
          'level': 'warning',
          'source': 'storage',
          'subject': 'sdb has 8 bad sectors',
          'body': 'It had 2.',
          'kind': 'storage.diskSectors',
          'params': {'device': '/dev/sdb', 'count': 8, 'was': 2},
          'read': false,
        },
        {'id': 2, 'level': 'info', 'source': 'alert', 'subject': 's', 'body': 'b', 'read': true},
      ],
      'unread': 1,
    });
    expect(notices.unread, 1);
    final first = notices.notices.first;
    expect((first.kind, first.param('device'), first.param('count')), ('storage.diskSectors', '/dev/sdb', '8'));
    expect(first.markedRead().read, isTrue);
    expect(notices.notices.last.kind, isNull);
  });

  test('audit: a page and where the next one starts', () {
    final page = MonitorAuditPage.fromJson({
      'entries': [
        {
          'id': 9,
          'timestamp': '2026-10-14T06:00:00.5+00:00',
          'kind': 'login',
          'action': 'denied',
          'result': 'denied',
          'subject': null,
          'remote_ip': '203.0.113.7',
          'ssh_user': null,
          'detail': 'wrong password',
        },
      ],
      'next': 9,
    });
    final entry = page.entries.single;
    expect((entry.kind, entry.result, entry.remoteIp, entry.detail), ('login', 'denied', '203.0.113.7', 'wrong password'));
    expect(entry.subject, isNull);
    expect(page.next, 9);
    expect(MonitorAuditPage.fromJson({'entries': [], 'next': null}).next, isNull);
  });

  test('live: sessions, connections, watch tokens and devices', () {
    final live = MonitorLive.fromJson({
      'sessions': [
        {'id': 'ab', 'user': 'lk', 'what': 'tmux main', 'remote_ip': '127.0.0.1', 'opened_at': '2026-10-14T06:00:00+00:00', 'attached': true},
      ],
      'connections': [
        {'id': '4', 'kind': 'rdp', 'target': 'win:3389', 'remote_ip': null, 'opened_at': '2026-10-14T06:00:00+00:00'},
      ],
      'watch_tokens': [
        {'client_id': 'widget:x', 'created_at': 1760421600, 'expires_at': 1768197600, 'scope': 'read'},
      ],
      'devices': [
        {'id': 5, 'label': 'ServerBox on ios (phone)', 'last_ip': '192.0.2.4', 'created_at': 1760421600, 'last_used': 1760421600},
      ],
    });
    expect(live.sessions.single.attached, isTrue);
    expect(live.connections.single.kind, 'rdp');
    expect(live.watchTokens.single.expiresAt, DateTime.fromMillisecondsSinceEpoch(1768197600 * 1000));
    expect((live.devices.single.id, live.devices.single.lastIp), (5, '192.0.2.4'));
  });

  test('a run of the same audit row is one, with how many', () {
    MonitorAuditEntry row(int id, {String detail = 'device known', String ip = '192.0.2.1'}) =>
        MonitorAuditEntry(id: id, kind: 'login', action: 'open', result: 'ok', detail: detail, remoteIp: ip);
    final runs = collapseAuditRuns([
      row(9),
      row(8),
      row(7),
      row(6, detail: 'new device'),
      row(5),
      row(4, ip: '192.0.2.2'),
    ]);
    expect([for (final (e, n) in runs) (e.id, n)], [(9, 3), (6, 1), (5, 1), (4, 1)]);
  });

  test('update: the newest release and how this agent is updated', () {
    final update = MonitorUpdate.fromJson({
      'version': '0.2.0',
      'latest': '0.3.0',
      'checked_at': '2026-10-14T06:00:00+00:00',
      'outdated': true,
      'install': 'script',
      'command': 'curl -fsSL https://example/install.sh | sh -s -- upgrade',
    });
    expect((update.version, update.latest, update.outdated), ('0.2.0', '0.3.0', true));
    expect(update.install, MonitorInstall.script);
    expect(update.command, endsWith('upgrade'));

    final failed = MonitorUpdate.fromJson({'version': '0.2.0', 'latest': null, 'error': 'HTTP 403', 'install': 'flatpak'});
    expect((failed.latest, failed.outdated, failed.error), (null, false, 'HTTP 403'));
    expect(failed.install, MonitorInstall.other);
  });
}
