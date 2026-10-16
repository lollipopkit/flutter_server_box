/// Opt-in end-to-end test of what the Monitor tab reads from a real `monitor`
/// agent: the firing rules, the notifications, the audit log (this run's own
/// sign-in in it) and what is signed in (this device among it, by name).
/// Nothing on the agent is ended or forgotten.
///
/// The same agent and variables as `monitor_web_apps_test.dart`, in the
/// environment or the workspace-root `.env`:
///
/// - `SBM_E2E_MONITOR_WEBAPPS_ADDR`, `SBM_E2E_MONITOR_WEBAPPS_PASSWORD`.
/// - `SBM_E2E_MONITOR_WEBAPPS_INSECURE=1` for an agent on plain HTTP,
///   `SBM_E2E_MONITOR_WEBAPPS_IGNORE_CERT=1` for a self-signed one.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

import '../helpers/ssh_e2e.dart';

void main() {
  final addr = e2eEnv('SBM_E2E_MONITOR_WEBAPPS_ADDR');
  final pwd = e2eEnv('SBM_E2E_MONITOR_WEBAPPS_PASSWORD');
  if (addr == null || pwd == null) {
    test('monitor overview e2e', () {}, skip: 'SBM_E2E_MONITOR_WEBAPPS_ADDR / _PASSWORD not set');
    return;
  }
  final client = MonitorHttpClient(
    MonitorHttpCredential(
      addr: addr,
      pwd: pwd,
      ignoreCert: e2eEnv('SBM_E2E_MONITOR_WEBAPPS_IGNORE_CERT') == '1',
      allowInsecure: e2eEnv('SBM_E2E_MONITOR_WEBAPPS_INSECURE') == '1',
    ),
  );
  tearDownAll(client.dispose);

  test('the agent offers the tab\'s sections', () async {
    final caps = await client.fetchCapabilities();
    expect(caps.features, containsAll(['alerts', 'audit', 'live', 'desk']));
    expect(caps.access.ok, isTrue, reason: 'the audit log and sessions need a link the agent lets act');
  });

  test('firing rules and notifications read', () async {
    final alerts = await client.alerts();
    for (final alert in alerts.alerts) {
      expect(alert.rule, isNotEmpty);
      expect(alert.since, isNotNull);
    }
    final notices = await client.notices(limit: 20);
    expect(notices.unread, lessThanOrEqualTo(500));
  });

  test('this sign-in is in the audit log and this device in the list', () async {
    final page = await client.audit(kind: 'login', result: 'ok');
    expect(page.entries, isNotEmpty);
    expect(page.entries.first.kind, 'login');
    expect(page.entries.first.remoteIp, isNotNull);

    final live = await client.live();
    expect(live.devices.map((d) => d.label), contains(MonitorHttpClient.deviceName));
  });

  test('ending what is not there is not found', () async {
    await expectLater(
      client.endConnection('0'),
      throwsA(isA<MonitorHttpErr>().having((e) => e.type, 'type', MonitorHttpErrType.notFound)),
    );
  });
}
