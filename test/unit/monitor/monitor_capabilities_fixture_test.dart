import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/monitor_capabilities.dart';
import 'package:server_box/data/model/server/monitor_grants.dart';

/// `GET /api/v1/capabilities` as a real agent answered it — the role a
/// `desktop` account holds on a `read` install with no file roots: `connect`
/// to one address, `files` granted read-only but not configured, nothing else.
///
/// Captured from the agent rather than written by hand, so the app's reading
/// of the contract is checked against what the agent actually sends.
void main() {
  final json =
      jsonDecode(
            File(
              'test/fixtures/monitor/capabilities_desktop_role.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final caps = MonitorCapabilities.fromJson(json);

  test('who is asking', () {
    expect(caps.me?.username, 'alice');
    expect(caps.me?.role, 'desktop');
    expect(caps.me?.admin, isFalse);
  });

  test('what the role can use, and why not the rest', () {
    final grants = caps.remoteAccess.grants!;
    expect(grants.connect.ok, isTrue);
    expect(grants.connectAllow, ['127.0.0.1:3389']);
    expect(grants.files.ok, isFalse);
    expect(grants.files.why, MonitorGrantWhy.notConfigured);
    expect(grants.filesMode, MonitorFilesMode.read);
    expect(grants.shell.why, MonitorGrantWhy.notGranted);
    expect(grants.listen.why, MonitorGrantWhy.notGranted);
  });

  test('onto what the rest of the app asks', () {
    final mapped = MonitorHttpCapabilities(caps.remoteAccess);
    expect(mapped.tcpRelay, isTrue);
    expect(mapped.remoteListen, isFalse);
    expect(mapped.shell, isFalse);
    expect(mapped.terminal, isFalse);
    expect(mapped.files, isFalse);
  });
}
