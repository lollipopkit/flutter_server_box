import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/monitor_desktop_channel.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

void main() {
  test(
    'desktop relay authenticates and carries bytes in both directions',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <String>[];
      server.listen((request) async {
        requests.add(request.uri.path);
        switch (request.uri.path) {
          case '/api/v1/login':
            request.response.headers.contentType = ContentType.json;
            request.response.write('{"token":"test"}');
            await request.response.close();
          case '/api/v1/ws-ticket':
            final body = jsonDecode(await utf8.decoder.bind(request).join());
            expect(body['purpose'], 'desktop');
            request.response.headers.contentType = ContentType.json;
            request.response.write('{"ticket":"id.secret"}');
            await request.response.close();
          case '/api/v1/desktop/ws':
            expect(
              request.headers.value('sec-websocket-protocol'),
              'sbm-ticket.id.secret',
            );
            final socket = await WebSocketTransformer.upgrade(
              request,
              protocolSelector: (protocols) => protocols.single,
            );
            socket.listen((message) {
              if (message is String) {
                expect(jsonDecode(message), {
                  'host': '127.0.0.1',
                  'port': 3389,
                });
                socket.add('{"type":"ready"}');
              } else {
                socket.add(message);
              }
            });
        }
      });
      final client = MonitorHttpClient(
        MonitorHttpCredential(addr: 'http://127.0.0.1:${server.port}'),
      );
      try {
        final channel = await MonitorDesktopChannel.open(
          client,
          host: '127.0.0.1',
          port: 3389,
        );
        channel.sink.add([1, 2, 3]);
        expect(await channel.stream.first, [1, 2, 3]);
        await channel.close();
        expect(requests, [
          '/api/v1/login',
          '/api/v1/ws-ticket',
          '/api/v1/desktop/ws',
        ]);
      } finally {
        client.dispose();
        await server.close(force: true);
      }
    },
  );
}
