import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/monitor_access.dart';
import 'package:server_box/data/model/server/monitor_capabilities.dart';
import 'package:server_box/data/model/server/system.dart';

/// `GET /api/v1/capabilities` in the shape the agent's `CapabilitiesView`
/// (`monitor/src/api/server.rs`) serializes: an account over plaintext HTTP
/// to an agent without `allow_insecure`, so `access` is refused. The agent's
/// `monitor/tests/permissions_api.rs` checks this fixture against its own
/// answer; the panel's `access.test.ts` reads it too.
void main() {
  final json =
      jsonDecode(
            File(
              'test/fixtures/monitor/capabilities_insecure.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final caps = MonitorCapabilities.fromJson(json);

  test('what the machine is', () {
    expect(caps.platform, SystemType.bsd);
    expect(caps.version, '0.1.3');
    expect(caps.retention, const Duration(days: 30));
    expect(caps.oldestSample, isNotNull);
    expect(caps.features, containsAll(['power', 'backup', 'virt', 'tmux']));
  });

  test('refused, and why', () {
    expect(caps.access.ok, isFalse);
    expect(caps.access.why, MonitorAccessWhy.insecureTransport);
  });

  test('onto what the rest of the app asks', () {
    final mapped = MonitorHttpCapabilities(caps.access);
    expect(mapped.tcpRelay, isFalse);
    expect(mapped.remoteListen, isFalse);
    expect(mapped.shell, isFalse);
    expect(mapped.terminal, isFalse);
    expect(mapped.files, isFalse);
  });
}
