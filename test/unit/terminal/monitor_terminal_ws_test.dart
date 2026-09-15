/// How the app opens the agent's terminal WebSocket.
///
/// One half of a contract whose other half is in another language: the agent
/// reads the ticket in `monitor/src/api/ws/terminal.rs`, and the panel sends it
/// from `monitor/frontend/src/lib/terminal.svelte.ts`. The panel has had
/// `carries the ticket only in the websocket subprotocol` under test all along;
/// this side had the same code inline and untested, and went on sending
/// `?ticket=` for a release after the agent stopped reading it — every terminal
/// and every snippet on a monitor server answered 401.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

void main() {
  group('the terminal upgrade', () {
    test('carries the ticket only in the subprotocol', () {
      // The panel asserts exactly this pair, in
      // `frontend/src/tests/terminal.test.ts`.
      expect(
        MonitorHttpClient.terminalWsUrl('https://a.example:3770').toString(),
        isNot(contains('ticket')),
      );
      expect(
        MonitorHttpClient.terminalWsProtocol('id.secret'),
        'sbm-ticket.id.secret',
      );
    });

    test('and matches the prefix the agent looks for', () {
      // `TICKET_PROTOCOL_PREFIX` in `monitor/src/api/ws/terminal.rs`. A
      // subprotocol that does not start with it is refused as "no ticket".
      expect(
        MonitorHttpClient.terminalWsProtocol('x'),
        startsWith('sbm-ticket.'),
      );
    });

    test('upgrades the scheme, whatever case it was typed in', () {
      // A `wss://` dial at a plaintext port fails; a `ws://` dial at a TLS port
      // hangs. `Uri.parse` lowercases the scheme, the stored address does not.
      for (final addr in ['https://a.example', 'HTTPS://a.example']) {
        expect(
          MonitorHttpClient.terminalWsUrl(addr).scheme,
          'wss',
          reason: addr,
        );
      }
      for (final addr in ['http://a.example', 'HTTP://a.example']) {
        expect(
          MonitorHttpClient.terminalWsUrl(addr).scheme,
          'ws',
          reason: addr,
        );
      }
    });

    test('keeps the host and port, and lands on the right path', () {
      final url = MonitorHttpClient.terminalWsUrl('https://a.example:3770');

      expect(url.host, 'a.example');
      expect(url.port, 3770);
      expect(url.path, '/api/v1/terminal/ws');
    });

    test('drops a query and a fragment the address arrived with', () {
      // Whatever the user typed is not part of this endpoint, and an empty
      // fragment left a bare `#` on the end of the URL in error messages.
      final url = MonitorHttpClient.terminalWsUrl(
        'https://a.example:3770/panel?a=1#top',
      );

      expect(url.hasFragment, isFalse);
      expect(url.toString(), isNot(contains('#')));
      expect(url.toString(), isNot(contains('a=1')));
    });
  });
}
