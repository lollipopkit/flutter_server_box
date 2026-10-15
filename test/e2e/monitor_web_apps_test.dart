/// Opt-in end-to-end test of the server page's web apps against a real
/// `monitor` agent with at least one deployed app: the list the card shows,
/// and the address the browser is handed, spent the way a browser spends it.
///
/// Skipped unless set, in the environment or the workspace-root `.env`:
///
/// - `SBM_E2E_MONITOR_WEBAPPS_ADDR`, `SBM_E2E_MONITOR_WEBAPPS_PASSWORD`.
/// - `SBM_E2E_MONITOR_WEBAPPS_INSECURE=1` for an agent on plain HTTP,
///   `SBM_E2E_MONITOR_WEBAPPS_IGNORE_CERT=1` for a self-signed one.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

import '../helpers/ssh_e2e.dart';

void main() {
  final addr = e2eEnv('SBM_E2E_MONITOR_WEBAPPS_ADDR');
  final pwd = e2eEnv('SBM_E2E_MONITOR_WEBAPPS_PASSWORD');
  if (addr == null || pwd == null) {
    test('web apps e2e', () {}, skip: 'SBM_E2E_MONITOR_WEBAPPS_ADDR / _PASSWORD not set');
    return;
  }
  final ignoreCert = e2eEnv('SBM_E2E_MONITOR_WEBAPPS_IGNORE_CERT') == '1';
  final client = MonitorHttpClient(
    MonitorHttpCredential(
      addr: addr,
      pwd: pwd,
      ignoreCert: ignoreCert,
      allowInsecure: e2eEnv('SBM_E2E_MONITOR_WEBAPPS_INSECURE') == '1',
    ),
  );
  tearDownAll(client.dispose);

  test('a deployed app opens through the proxy with the address handed out', () async {
    final apps = await client.stacks();
    final app = apps.firstWhere((a) => a.proxy, orElse: () => fail('no deployed app behind the proxy: $apps'));
    expect(app.titleIn('en'), isNotEmpty);

    final uri = (await client.stackEnter(app.id)).uri(client.agentUri);
    expect(uri.path, '/__sbm/enter');

    final http = HttpClient();
    if (ignoreCert) http.badCertificateCallback = (_, _, _) => true;
    addTearDown(() => http.close(force: true));

    final enter = await (await http.getUrl(uri)..followRedirects = false).close();
    await enter.drain<void>();
    expect(enter.statusCode, HttpStatus.seeOther);
    final session = enter.cookies.singleWhere((c) => c.name == '__sbm_${app.id}');
    expect(session.httpOnly, isTrue);

    // The ticket is single use.
    final again = await (await http.getUrl(uri)..followRedirects = false).close();
    await again.drain<void>();
    expect(again.statusCode, isNot(HttpStatus.seeOther));

    // With the session the service itself answers.
    final next = uri.resolve(enter.headers.value(HttpHeaders.locationHeader)!);
    final req = await http.getUrl(next)
      ..followRedirects = false
      ..cookies.add(session);
    final page = await req.close();
    await page.drain<void>();
    expect(page.statusCode, lessThan(500));
    expect(page.statusCode, isNot(HttpStatus.unauthorized));
  });
}
