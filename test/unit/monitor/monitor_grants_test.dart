/// `capabilities.grants` and `capabilities.me` — `docs/dev/monitor-permissions.md`
/// — and what the rest of the app reads off them: the booleans every
/// capability question asks, and why an entry is greyed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/monitor_capabilities.dart';
import 'package:server_box/data/model/server/monitor_grants.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/port_forward_provider.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';

void main() {
  /// What an agent with roles answers for an account of role `desktop`.
  Map<String, dynamic> withGrants() => {
    'remote_access': {
      'terminal': false,
      'full_access': false,
      'files': true,
      'stream': true,
      'listen': false,
    },
    'me': {'username': 'alice', 'role': 'desktop', 'admin': false},
    'grants': {
      'shell': {'ok': false, 'why': 'not_granted'},
      'ssh_terminal': {'ok': false, 'why': 'not_granted'},
      'files': {'ok': true, 'mode': 'read'},
      'connect': {
        'ok': true,
        'allow': ['127.0.0.1:3389'],
      },
      'listen': {
        'ok': false,
        'why': 'insecure_transport',
        'public': false,
        'ports': null,
      },
    },
  };

  group('parsing', () {
    test('grants and the account come through', () {
      final caps = MonitorCapabilities.fromJson(withGrants());
      expect(caps.me?.username, 'alice');
      expect(caps.me?.role, 'desktop');
      expect(caps.me?.admin, isFalse);
      final grants = caps.remoteAccess.grants!;
      expect(grants.shell.why, MonitorGrantWhy.notGranted);
      expect(grants.files.ok, isTrue);
      expect(grants.filesReadOnly, isTrue);
      expect(grants.connectAllow, ['127.0.0.1:3389']);
      expect(grants.listen.why, MonitorGrantWhy.insecureTransport);
      // Not in this answer, as from an agent older than the grant.
      expect(grants.virt.ok, isFalse);
    });

    test('virt is read when the agent lists it', () {
      final json = withGrants();
      (json['grants'] as Map)['virt'] = {'ok': true};
      final grants = MonitorCapabilities.fromJson(json).remoteAccess.grants!;
      expect(grants.virt.ok, isTrue);
    });

    test('the booleans are the grants, not the legacy object beside them', () {
      // Disagreeing on purpose: the grants are the one source.
      final json = withGrants()
        ..['remote_access'] = {'full_access': true, 'stream': false};
      final access = MonitorCapabilities.fromJson(json).remoteAccess;
      expect(access.fullAccess, isFalse);
      expect(access.stream, isTrue);
      expect(access.files, isTrue);
      expect(access.listen, isFalse);
    });

    test('an agent older than roles keeps the legacy booleans', () {
      final caps = MonitorCapabilities.fromJson({
        'remote_access': {
          'terminal': true,
          'full_access': true,
          'files': false,
          'stream': true,
        },
      });
      expect(caps.me, isNull);
      expect(caps.remoteAccess.grants, isNull);
      expect(caps.remoteAccess.fullAccess, isTrue);
      expect(caps.remoteAccess.stream, isTrue);
    });

    test('a reason a later agent added is not taken for one this app knows', () {
      final grant = MonitorGrant.fromJson({'ok': false, 'why': 'quota'});
      expect(grant.why, MonitorGrantWhy.unknown);
    });
  });

  group('capabilities', () {
    test('map onto what the rest of the app asks', () {
      final access = MonitorCapabilities.fromJson(withGrants()).remoteAccess;
      final caps = MonitorHttpCapabilities(access);
      expect(caps.shell, isFalse);
      expect(caps.terminal, isFalse);
      expect(caps.files, isTrue);
      expect(caps.tcpRelay, isTrue);
      expect(caps.remoteListen, isFalse);
    });
  });

  group('why an entry is greyed', () {
    const monitor = MonitorHttpCredential(addr: 'https://agent:3770');
    final agentOnly = Spi(name: 'test', id: 'a', monitorHttp: monitor);
    final access = MonitorCapabilities.fromJson(withGrants()).remoteAccess;

    test('a grant the role lacks: ask the admin', () {
      expect(
        ServerFuncBtn.terminal.unavailableReason(agentOnly, access),
        l10n.funcNeedsAgentPermission(ServerFuncBtn.terminal.toStr),
      );
      expect(
        ServerFuncBtn.process.unavailableReason(agentOnly, access),
        l10n.funcNeedsAgentPermission(ServerFuncBtn.process.toStr),
      );
    });

    test('a grant held but not over this link: HTTPS', () {
      final server = ServerState(
        spi: agentOnly,
        status: InitStatus.status,
        remoteAccess: access,
      );
      expect(
        portForwardUnavailable(server, listen: true),
        contains('HTTPS'),
      );
      // The relay is fine, so a local forward is not held back.
      expect(portForwardUnavailable(server, listen: false), isNull);
    });

    test('a forward says listen\'s reason when connect\'s says nothing', () {
      // A forward is either grant's, so when the agent's reason for `connect`
      // is one this app cannot read, `listen`'s is the one worth showing.
      final access = MonitorCapabilities.fromJson(
        withGrants()
          ..['grants'] = {
            'connect': {'ok': false, 'why': 'a_later_reason'},
            'listen': {'ok': false, 'why': 'not_granted'},
          },
      ).remoteAccess;
      expect(
        ServerFuncBtn.portForward.unavailableReason(agentOnly, access),
        l10n.funcNeedsAgentPermission(ServerFuncBtn.portForward.toStr),
      );
    });

    test('a grant held with nothing behind it: its operator', () {
      final notConfigured = MonitorCapabilities.fromJson(
        withGrants()
          ..['grants'] = {
            'files': {'ok': false, 'why': 'not_configured'},
          },
      ).remoteAccess;
      expect(
        ServerFuncBtn.files.unavailableReason(agentOnly, notConfigured),
        l10n.funcNeedsAgentSetup(ServerFuncBtn.files.toStr),
      );
    });
  });
}
