/// Both PVE consoles end to end against a fake PVE over real TLS on loopback:
/// the ticket request, then `vncwebsocket` through the same connection
/// factory and certificate pin as the API calls, then what runs on it —
/// termproxy's protocol for the text console, the RFB stream through the
/// loopback adapter for the graphical one.
///
/// Certificates are `pve_tls_test.dart`'s fixtures.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/pve_termproxy.dart';
import 'package:server_box/core/utils/websocket_tunnel.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/provider/virt/pve_backend.dart';

const _dir = 'test/fixtures/virt_tls';

String _leafFingerprint() {
  final pem = File('$_dir/leaf.pem').readAsStringSync();
  final body = pem
      .split('\n')
      .where((l) => !l.startsWith('-----') && l.trim().isNotEmpty)
      .join();
  return sha256.convert(base64.decode(body)).toString();
}

const _lxc = VirtGuest(
  id: 'lxc/100',
  name: 'ct',
  kind: VirtGuestKind.lxc,
  state: VirtGuestState.running,
  node: 'pve',
  vmid: 100,
);

const _qemu = VirtGuest(
  id: 'qemu/101',
  name: 'vm',
  kind: VirtGuestKind.qemu,
  state: VirtGuestState.running,
  node: 'pve',
  vmid: 101,
);

void main() {
  late HttpServer server;

  /// Form bodies of the POSTs, by path.
  final posts = <String, String>{};

  /// The websocket upgrades: path and query, and the headers that matter.
  final upgrades = <Map<String, String?>>[];

  /// Whether this PVE refuses `generate-password` (before 7.2).
  var oldPve = false;

  /// What the websocket's far end does, set per test.
  late void Function(WebSocket ws, Uri uri) onSocket;

  setUp(() async {
    posts.clear();
    upgrades.clear();
    oldPve = false;
    final ctx = SecurityContext()
      ..useCertificateChain('$_dir/leaf.pem')
      ..usePrivateKey('$_dir/leaf.key');
    server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, ctx);
    server.listen((req) async {
      final path = req.uri.path.replaceFirst('/api2/json', '');
      if (path.endsWith('/vncwebsocket')) {
        upgrades.add({
          'uri': '${req.uri.path}?${req.uri.query}',
          'auth': req.headers.value('authorization'),
          'protocol': req.headers.value('sec-websocket-protocol'),
        });
        final ws = await WebSocketTransformer.upgrade(
          req,
          protocolSelector: (p) => p.first,
        );
        onSocket(ws, req.uri);
        return;
      }
      final body = await utf8.decodeStream(req);
      Object? data;
      var status = 200;
      String? message;
      if (req.method == 'POST') posts[path] = body;
      switch (path) {
        case '/version':
          data = {'version': '8.2.4'};
        case '/nodes/pve/qemu/101/config':
          data = {'serial1': 'socket', 'serial3': 'socket', 'vga': 'std'};
        case '/nodes/pve/lxc/100/termproxy' || '/nodes/pve/qemu/101/termproxy':
          data = {'port': 5901, 'ticket': 'PVEVNC:T1', 'user': 'root@pam!sb'};
        case '/nodes/pve/qemu/101/vncproxy':
          if (oldPve && body.contains('generate-password')) {
            status = 400;
            message = 'Parameter verification failed.';
            data = null;
            req.response
              ..statusCode = status
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode({
                  'data': null,
                  'message': message,
                  'errors': {
                    'generate-password':
                        'property is not defined in schema and the schema '
                        'does not allow additional properties',
                  },
                }),
              );
            await req.response.close();
            return;
          }
          data = {
            'port': 5902,
            'ticket': 'PVEVNC:VT',
            'user': 'root@pam!sb',
            if (body.contains('generate-password=1')) 'password': 'Ab3dE6gH',
          };
        default:
          status = 404;
      }
      req.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'data': data}));
      await req.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  PveBackend backend({String? pin}) => PveBackend(
    serverId: 'srv',
    config: PveConfig(
      addr: 'https://localhost:8006',
      auth: PveAuth.token,
      tokenId: 'root@pam!sb',
      tokenSecret: 'secret',
      certSha256: pin,
    ),
    connect: (_, _) => ConnectionTask.fromSocket(
      Socket.connect(InternetAddress.loopbackIPv4, server.port),
      () {},
    ),
    securityContext: SecurityContext(withTrustedRoots: false),
  );

  test('text: termproxy over the pinned websocket', () async {
    final pve = backend(pin: _leafFingerprint());
    addTearDown(pve.close);
    final fromClient = StreamController<String>.broadcast();
    addTearDown(fromClient.close);
    onSocket = (ws, _) {
      var first = true;
      ws.listen((frame) {
        final text = utf8.decode(frame as List<int>);
        if (!fromClient.isClosed) fromClient.add(text);
        if (first) {
          first = false;
          ws.add(Uint8List.fromList(ascii.encode('OKroot@ct:~# ')));
        }
      });
    };

    final console = await pve.console(_lxc, VirtConsoleKind.text);
    expect(console, isA<PveTermConsole>());
    console as PveTermConsole;
    final seen = fromClient.stream.toList();
    final ws = await pve.openConsoleSocket(console);
    final term = await PveTermShellBackend.start(
      ws,
      user: console.user,
      ticket: console.ticket,
    );
    addTearDown(term.close);

    expect(upgrades.single, {
      'uri':
          '/api2/json/nodes/pve/lxc/100/vncwebsocket'
          '?port=5901&vncticket=PVEVNC%3AT1',
      'auth': 'PVEAPIToken=root@pam!sb=secret',
      'protocol': 'binary',
    });

    final shell = await term.openShell(width: 90, height: 30);
    final prompt = await shell.stdout!.first;
    expect(utf8.decode(prompt), 'root@ct:~# ');
    shell.write(utf8.encode('id\r'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    shell.close();
    await fromClient.close();
    expect(await seen, [
      'root@pam!sb:PVEVNC:T1\n',
      '1:90:30:',
      '0:3:id\r',
    ]);
  });

  test('text on a VM attaches to its first serial port', () async {
    final pve = backend(pin: _leafFingerprint());
    addTearDown(pve.close);
    await pve.console(_qemu, VirtConsoleKind.text);
    expect(posts['/nodes/pve/qemu/101/termproxy'], 'serial=serial1');
  });

  test('the console socket keeps the API\'s certificate policy', () async {
    final pve = backend(pin: 'ab' * 32);
    addTearDown(pve.close);
    const console = PveTermConsole(
      node: 'pve',
      guestKind: VirtGuestKind.lxc,
      vmid: 100,
      port: 5901,
      ticket: 'PVEVNC:T1',
      user: 'root@pam',
    );
    await expectLater(
      pve.openConsoleSocket(console),
      throwsA(
        isA<VirtErr>().having((e) => e.type, 'type', VirtErrType.certChanged),
      ),
    );
    expect(upgrades, isEmpty, reason: 'nothing was sent past the handshake');
  });

  group('graphical', () {
    Future<void> rfbThroughTunnel(PveVncConsole console, PveBackend pve) async {
      final fromClient = BytesBuilder();
      final gotClientBytes = Completer<void>();
      onSocket = (ws, _) {
        ws.add(Uint8List.fromList(ascii.encode('RFB 003.008\n')));
        ws.listen((frame) {
          fromClient.add(frame as List<int>);
          if (!gotClientBytes.isCompleted) gotClientBytes.complete();
        });
      };
      final tunnel = await WebSocketTunnelChannel.loopbackOnce(
        WebSocketTunnelChannel(await pve.openConsoleSocket(console)),
      );
      addTearDown(tunnel.close);
      final vnc = await Socket.connect(tunnel.address, tunnel.port);
      addTearDown(vnc.destroy);
      final greeting = await vnc.first.timeout(const Duration(seconds: 5));
      expect(ascii.decode(greeting), 'RFB 003.008\n');
      vnc.add(ascii.encode('RFB 003.008\n'));
      await gotClientBytes.future.timeout(const Duration(seconds: 5));
      expect(ascii.decode(fromClient.takeBytes()), 'RFB 003.008\n');
    }

    test('vncproxy with a generated password, RFB through the adapter', () async {
      final pve = backend(pin: _leafFingerprint());
      addTearDown(pve.close);
      final console = await pve.console(_qemu, VirtConsoleKind.vnc);
      expect(posts['/nodes/pve/qemu/101/vncproxy'], contains('websocket=1'));
      expect(
        posts['/nodes/pve/qemu/101/vncproxy'],
        contains('generate-password=1'),
      );
      console as PveVncConsole;
      expect(console.rfbPassword, 'Ab3dE6gH');
      await rfbThroughTunnel(console, pve);
      expect(upgrades.single['uri'], contains('/qemu/101/vncwebsocket'));
      expect(upgrades.single['uri'], contains('vncticket=PVEVNC%3AVT'));
    });

    test('before PVE 7.2 the ticket is the password, cut to 8', () async {
      oldPve = true;
      final pve = backend(pin: _leafFingerprint());
      addTearDown(pve.close);
      final console = await pve.console(_qemu, VirtConsoleKind.vnc);
      console as PveVncConsole;
      expect(posts['/nodes/pve/qemu/101/vncproxy'], isNot(contains('generate')));
      expect(console.password, 'PVEVNC:VT');
      expect(console.rfbPassword, 'PVEVNC:V');
    });
  });
}
