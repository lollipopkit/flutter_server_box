/// Opt-in end-to-end test of Flutter's `MonitorHttpClient` MCP token and
/// policy methods against a real `monitor` agent (`/api/v1/api-tokens*`,
/// `/api/v1/mcp`, #1681).
///
/// Uses the same environment variables as `monitor_overview_test.dart`:
/// - `SBM_E2E_MONITOR_WEBAPPS_ADDR`, `SBM_E2E_MONITOR_WEBAPPS_PASSWORD`
/// - `SBM_E2E_MONITOR_WEBAPPS_INSECURE=1` for plain HTTP.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/monitor/http.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor/monitor_api_token.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/ssh_e2e.dart';

Future<(int status, Map<String, dynamic> body)> _mcpPost(
  String url,
  String bearer,
  Map<String, dynamic> rpc, {
  String? pin,
}) async {
  final http = HttpClient();
  if (pin != null) {
    http.badCertificateCallback = (cert, _, _) => sha256.convert(cert.der).toString() == pin;
  }
  try {
    final req = await http.postUrl(Uri.parse(url));
    req.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $bearer')
      ..set(HttpHeaders.contentTypeHeader, 'application/json')
      ..set(HttpHeaders.acceptHeader, 'application/json')
      ..set('MCP-Protocol-Version', '2025-11-25');
    req.add(utf8.encode(jsonEncode(rpc)));
    final res = await req.close();
    final text = await utf8.decodeStream(res);
    return (
      res.statusCode,
      text.isEmpty ? <String, dynamic>{} : (jsonDecode(text) as Map).cast<String, dynamic>(),
    );
  } finally {
    http.close(force: true);
  }
}

Future<void> main() async {
  final addr = e2eEnv('SBM_E2E_MONITOR_WEBAPPS_ADDR');
  final pwd = e2eEnv('SBM_E2E_MONITOR_WEBAPPS_PASSWORD');
  if (addr == null || pwd == null) {
    test('monitor mcp e2e', () {}, skip: 'SBM_E2E_MONITOR_WEBAPPS_ADDR / _PASSWORD not set');
    return;
  }

  final pin = await e2eAgentCertSha256(addr);
  final client = MonitorHttpClient(
    MonitorHttpCredential(
      addr: addr,
      pwd: pwd,
      certSha256: pin,
      allowInsecure: e2eEnv('SBM_E2E_MONITOR_WEBAPPS_INSECURE') == '1',
    ),
  );
  setUpAll(initRustLibForTest);
  tearDownAll(client.dispose);

  test('Flutter client manages MCP policy and tokens and speaks to /api/v1/mcp', () async {
    final caps = await client.capabilities();
    expect(caps.features, contains('mcp'));
    expect(client.mcpEndpointUrl, endsWith('/api/v1/mcp'));

    final origPolicy = await client.mcpPolicy();
    final runTag = 'flutter-mcp-e2e-${DateTime.now().millisecondsSinceEpoch}';
    int? createdId;

    try {
      await expectLater(
        client.createApiToken(name: runTag, password: '$pwd-wrong'),
        throwsA(isA<MonitorHttpErr>().having((e) => e.type, 'type', MonitorHttpErrType.reauth)),
      );

      final minted = await client.createApiToken(name: runTag, password: pwd, days: 7);
      createdId = minted.token.id;
      expect(minted.value.startsWith('sbt_'), isTrue);
      expect(minted.value.length, 68);
      expect(minted.token.scopes, containsAll(MonitorApiToken.allScopes));
      expect(minted.token.lastUsedAt, isNull);

      final (status, callRes) = await _mcpPost(
        client.mcpEndpointUrl,
        minted.value,
        {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'tools/call',
          'params': {
            'name': 'run_command',
            'arguments': {'command': 'echo flutter-e2e-ok'},
          },
        },
        pin: pin,
      );
      expect(status, 200);
      final result = (callRes['result'] as Map).cast<String, dynamic>();
      expect(result['isError'], isNot(true));

      final listed = await client.apiTokens();
      final refreshed = listed.firstWhere((t) => t.id == createdId);
      expect(refreshed.lastUsedAt, isNotNull);
      expect(refreshed.lastUsedIp, isNotNull);

      // Update token to read-only and verify exec is rejected.
      final updated = await client.updateApiToken(
        createdId,
        name: '$runTag-ro',
        scopes: const [MonitorApiToken.scopeRead],
        commands: const MonitorMcpCommandPolicy(mode: MonitorMcpCommandPolicy.modeAllowlist),
      );
      expect(updated.name, '$runTag-ro');
      expect(updated.scopes, [MonitorApiToken.scopeRead]);

      final (_, deniedExec) = await _mcpPost(
        client.mcpEndpointUrl,
        minted.value,
        {
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'tools/call',
          'params': {
            'name': 'run_command',
            'arguments': {'command': 'echo blocked'},
          },
        },
        pin: pin,
      );
      expect((deniedExec['error'] as Map)['code'], -32602);

      // Save and restore global policy via Flutter client.
      final narrowedGlobal = await client.saveMcpPolicy(
        scopes: const [MonitorApiToken.scopeRead],
        commands: const MonitorMcpCommandPolicy(
          mode: MonitorMcpCommandPolicy.modeAllowAll,
          deny: ['rm -rf *'],
        ),
      );
      expect(narrowedGlobal.scopes, [MonitorApiToken.scopeRead]);
      expect(narrowedGlobal.commands.deny, ['rm -rf *']);

      final restoredGlobal = await client.saveMcpPolicy(
        scopes: origPolicy.scopes,
        commands: origPolicy.commands,
      );
      expect(restoredGlobal.scopes, origPolicy.scopes);

      // Revoke and confirm immediate 401.
      await client.revokeApiToken(createdId);
      final revokedId = createdId;
      createdId = null;
      expect((await client.apiTokens()).where((t) => t.id == revokedId), isEmpty);

      final (revokedStatus, _) = await _mcpPost(
        client.mcpEndpointUrl,
        minted.value,
        {
          'jsonrpc': '2.0',
          'id': 3,
          'method': 'ping',
        },
        pin: pin,
      );
      expect(revokedStatus, 401);

      final audit = await client.audit(kind: 'mcp', limit: 10);
      expect(audit.entries, isNotEmpty);
      expect(
        audit.entries.any((e) => (e.detail ?? '').contains('flutter-e2e-ok')),
        isTrue,
      );
    } finally {
      try {
        await client.saveMcpPolicy(scopes: origPolicy.scopes, commands: origPolicy.commands);
      } finally {
        if (createdId != null) {
          await client.revokeApiToken(createdId);
        }
      }
    }
  });
}
