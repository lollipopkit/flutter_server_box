/// The payload two native implementations decode.
///
/// `AppDelegate.publishWidgetServers` on iOS and `WidgetStore.publish` on
/// Android both parse this, in a process that cannot ask for a correction and
/// ships on its own schedule. So its shape is a contract, and it is the same
/// contract twice — a change asserted here is a change both have to make.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/scoped_token.dart';
import 'package:server_box/core/service/watch_sync.dart';
import 'package:server_box/core/service/widget_sync.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

import 'helpers/spi_fixture.dart';

void main() {
  const addr = 'https://10.0.0.1:3770';

  ScopedToken tok(String token, {int expiresAt = 1800000000}) =>
      ScopedToken(token: token, endpoint: addr, expiresAt: expiresAt);

  Spi monitorSpi({
    required String id,
    required String name,
    String addr = addr,
    bool ignoreCert = false,
    bool allowInsecure = false,
  }) {
    return spiFixture(name: name, id: id).copyWith(
      monitorHttp: MonitorHttpCredential(
        addr: addr,
        user: 'admin',
        pwd: 'secret',
        ignoreCert: ignoreCert,
        allowInsecure: allowInsecure,
      ),
    );
  }

  Map<String, dynamic> payload({
    required List<Spi> servers,
    Map<String, ScopedToken> tokens = const {},
  }) {
    return WidgetSync.payloadFrom(servers: servers, tokens: tokens);
  }

  List<Map> entries(Map<String, dynamic> p) =>
      (p['servers'] as List).cast<Map>();

  group('what a widget is told about a server', () {
    test('is everything it needs and no login', () {
      final result = payload(
        servers: [monitorSpi(id: 'a', name: 'Home', ignoreCert: true)],
        tokens: {'a': tok('widget-token')},
      );

      expect(result['v'], WidgetSync.payloadVersion);
      expect(entries(result), [
        {
          'id': 'a',
          'name': 'Home',
          'addr': addr,
          'token': 'widget-token',
          'expiresAt': 1800000000,
          'ignoreCert': true,
          'allowInsecure': false,
        },
      ]);
      // The agent password never leaves this app. A widget gets the scoped
      // read-only credential or it gets nothing.
      final entry = entries(result).single;
      expect(entry.containsKey('user'), isFalse);
      expect(entry.containsKey('pwd'), isFalse);
    });

    test('carries the plaintext opt-in, which is per server', () {
      // Android's `usesCleartextTraffic` lets the process speak plaintext at
      // all; it is not an answer about any one server. Without this flag the
      // widget would put a bearer token on an unencrypted wire for a server
      // whose owner never agreed to that.
      final result = payload(
        servers: [
          monitorSpi(
            id: 'a',
            name: 'Plain',
            addr: 'http://10.0.0.5:3770',
            allowInsecure: true,
          ),
        ],
        tokens: {'a': tok('t')},
      );

      expect(entries(result).single['allowInsecure'], isTrue);
    });

    test('normalises the address so a path can be appended to it', () {
      final result = payload(
        servers: [monitorSpi(id: 'a', name: 'A', addr: '  $addr/  ')],
        tokens: {'a': tok('t')},
      );

      expect(entries(result).single['addr'], addr);
    });

    test('is listed by name, which is how a picker is read', () {
      final result = payload(
        servers: [
          monitorSpi(id: 'c', name: 'zulu'),
          monitorSpi(id: 'a', name: 'Alpha'),
          monitorSpi(id: 'b', name: 'mike'),
        ],
        tokens: {'a': tok('a'), 'b': tok('b'), 'c': tok('c')},
      );

      expect(
        entries(result).map((e) => e['name']),
        ['Alpha', 'mike', 'zulu'],
      );
    });
  });

  group('a credential the platform is already holding', () {
    test('is not published back over itself', () {
      // The renewal decision needs to know a token exists, its endpoint and
      // its deadline — never the bytes, which stay in the platform credential
      // store. So a reused one comes back as a placeholder, and publishing
      // that would write the placeholder *over* the real credential. Every
      // request after it answers 401, and nothing re-issues, because from
      // this side the server still looks like it has a token.
      //
      // Found on a device: the first push worked and the next one wedged it.
      final result = payload(
        servers: [monitorSpi(id: 'a', name: 'A')],
        tokens: {
          'a': const ScopedToken.held(endpoint: addr, expiresAt: 1800000000),
        },
      );

      final entry = entries(result).single;
      expect(entry.containsKey('token'), isFalse);
      // The deadline still travels: the native side keeps the credential it
      // has and needs to agree about when it lapses.
      expect(entry['expiresAt'], 1800000000);
    });

    test('but a freshly issued one is', () {
      final result = payload(
        servers: [monitorSpi(id: 'a', name: 'A')],
        tokens: {'a': tok('brand-new')},
      );

      expect(entries(result).single['token'], 'brand-new');
    });

    test('and it still counts as reusable', () {
      // The other half of the same decision: a held token has to satisfy
      // `servesEndpoint`, or every push would mint a replacement for a
      // credential that was working.
      final held = const ScopedToken.held(
        endpoint: addr,
        expiresAt: 1800000000,
      );

      expect(held.isEmpty, isFalse);
      expect(
        held.servesEndpoint(addr, DateTime.utc(2026, 8, 26)),
        isTrue,
      );
    });
  });

  group('a server the app could not get a token for', () {
    test('is still published, without one', () {
      // Dropping it would empty a configuration screen because an agent was
      // briefly unreachable. The widget can still show a name and say it
      // cannot reach the agent, and the next push repairs it.
      final result = payload(servers: [monitorSpi(id: 'a', name: 'A')]);

      final entry = entries(result).single;
      expect(entry['id'], 'a');
      expect(entry.containsKey('token'), isFalse);
      // Zero is what the native side reads as "there is no credential here",
      // as distinct from one that has not been renewed yet.
      expect(entry['expiresAt'], 0);
    });

    test('and an empty token counts as none', () {
      final result = payload(
        servers: [monitorSpi(id: 'a', name: 'A')],
        tokens: {'a': tok('')},
      );

      expect(entries(result).single.containsKey('token'), isFalse);
    });
  });

  test('a server with no monitor agent is not published at all', () {
    // A widget speaks HTTP to an agent and has no SSH client, so an SSH-only
    // server would be an entry it could never load.
    final result = payload(
      servers: [
        spiFixture(name: 'SSH only', id: 'ssh', ip: '10.0.0.9'),
        monitorSpi(id: 'a', name: 'A'),
      ],
      tokens: {'a': tok('t')},
    );

    expect(entries(result).single['id'], 'a');
  });

  group('the client id a widget token is scoped to', () {
    test('names the server', () {
      expect(WidgetSync.widgetClientId('abc'), 'widget:abc');
    });

    test('is not the watch app\'s', () {
      // The agent keys `watch_tokens` by (subject, client_id), so these being
      // different strings is the whole reason unpairing a watch leaves the
      // widgets working, and removing a widget does not log a watch out. One
      // shared id would make either action revoke both.
      expect(
        WidgetSync.widgetClientId('abc'),
        isNot(WatchSync.watchClientId('abc')),
      );
    });

    test('and both are in the list revocation walks', () {
      // `revokeScopedTokensLeftBehind` hands an agent back every credential
      // this app minted there, and it is the only chance to do so — after the
      // edit the login that would authenticate the call is gone. A client id
      // missing from that list is a token nobody can ever revoke.
      final ids = scopedClientIdsFor('abc');

      expect(ids, contains(WidgetSync.widgetClientId('abc')));
      expect(ids, contains(WatchSync.watchClientId('abc')));
      expect(ids, hasLength(2));
    });
  });
}
