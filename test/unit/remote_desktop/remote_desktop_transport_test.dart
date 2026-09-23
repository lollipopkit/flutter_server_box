/// Which transport a remote desktop session is carried by.
///
/// This is the fix for the case the feature had no answer for: a server whose
/// only door is a `monitor` agent. The session used to ask for an SSH client
/// unconditionally, so on such a server it failed before it started — and the
/// entry that opens it was hidden besides, because it was gated on
/// `byteStream`, which an agent never answers true to.
///
/// Asserted through the provider rather than the page: what is under test is
/// the decision, not the pixels, and the page's own layout is covered in
/// `test/widget/remote_desktop_profiles_test.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/remote_desktop.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/src/rust/api/remote_desktop.dart' as ffi;

import '../../helpers/rust_lib_helper.dart';
import '../../helpers/test_db.dart';

/// An agent that answers the login, mints a ticket, and then accepts the relay
/// — recording that it was reached, which is the whole assertion.
class _FakeAgent {
  _FakeAgent._(this._server, this._refuseTickets);

  final HttpServer _server;

  /// Answer 403 to every ticket request, standing in for an agent that will
  /// not relay — the failure that has to end up reported rather than retried
  /// for ever.
  final bool _refuseTickets;

  /// The addresses the relay was asked to dial.
  final List<String> dialled = [];

  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}');

  static Future<_FakeAgent> start({bool refuseTickets = false}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final agent = _FakeAgent._(server, refuseTickets);
    agent._serve();
    return agent;
  }

  void _serve() {
    _server.listen((request) async {
      if (request.uri.path == '/api/v1/login') {
        await request.drain<void>();
        return _json(request, {'token': 'test-token'});
      }
      if (request.uri.path == '/api/v1/ws-ticket') {
        await request.drain<void>();
        if (_refuseTickets) {
          request.response.statusCode = HttpStatus.forbidden;
          return request.response.close();
        }
        return _json(request, {'ticket': 'id.secret', 'expires_in': 30});
      }
      final socket = await WebSocketTransformer.upgrade(
        request,
        protocolSelector: (protocols) => protocols.first,
      );
      socket.listen((frame) {
        if (frame is! String) return;
        final msg = jsonDecode(frame) as Map<String, dynamic>;
        if (msg['type'] != 'open') return;
        dialled.add('${msg['host']}:${msg['port']}');
        socket.add(jsonEncode({'type': 'ready'}));
      });
    });
  }

  Future<void> _json(HttpRequest request, Map<String, Object?> body) async {
    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }

  Future<void> close() => _server.close(force: true);
}

/// The default `HttpOverrides`, which is to say none at all.
///
/// `flutter_test` installs overrides that answer every request with a 400
/// without opening a socket, so a test that talks to a real local server has to
/// say so.
class _RealHttp extends HttpOverrides {}

Future<void> realHttp(Future<void> Function() body) =>
    HttpOverrides.runWithHttpOverrides(body, _RealHttp());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-rdp-transport-');
    await openTestDb();
    // The session dials the loopback the Rust client connects to, so the
    // client has to be loaded before there is anything to observe.
    await initRustLibForTest();
    await getIt.reset();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test')..init());
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<RemoteDesktopStore>(RemoteDesktopStore());
  });

  tearDownAll(() async {
    await getIt.reset();
    await closeTestDb();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    for (final spi in Stores.server.fetch()) {
      Stores.server.delete(spi);
    }
  });

  RemoteDesktopProfile profileFor(String serverId) => RemoteDesktopProfile(
    id: 'rdp-1',
    serverId: serverId,
    name: 'Windows',
    protocol: RemoteDesktopProtocol.vnc,
    host: '127.0.0.1',
    port: 5900,
    password: 'secret',
  );

  test('a monitor-only server is served by the agent relay', () async {
    final agent = await _FakeAgent.start();
    addTearDown(agent.close);

    final spi = Spi(
      name: 'agent-only',
      id: 'srv-agent',
      monitorHttp: MonitorHttpCredential(addr: agent.url.toString()),
    );
    Stores.server.put(spi);

    await realHttp(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(serversProvider);

      final sessions = container.read(remoteDesktopSessionsProvider.notifier);
      final profile = profileFor(spi.id);
      sessions.open(profile, sessionPassword: 'secret');
      addTearDown(() => sessions.close(profile.id));

      // The dial is what proves the transport: an SSH tunnel would never reach
      // the agent's relay, and would have failed before opening anything.
      await _until(() {
        if (agent.dialled.isNotEmpty) return true;
        final view =
            container.read(remoteDesktopSessionsProvider).sessions[profile.id];
        if (view?.error != null) {
          fail('the session failed before dialling: ${view!.error}');
        }
        return false;
      });
      expect(agent.dialled, ['127.0.0.1:5900']);
    });
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('the entry is offered exactly when the relay is', () {
    // The pair that has to agree: the button's gate and the session's ability.
    const withRelay = MonitorHttpCapabilities(
      MonitorRemoteAccess(fullAccess: true, stream: true),
    );
    const withoutRelay = MonitorHttpCapabilities(
      MonitorRemoteAccess(fullAccess: true),
    );

    expect(ServerFuncBtn.remoteDesktop.availableWith(withRelay), isTrue);
    expect(ServerFuncBtn.remoteDesktop.availableWith(withoutRelay), isFalse);
  });

  test('a session that cannot open is reported, not left connecting', () async {
    // An agent that refuses the ticket. What is asserted is that the failure
    // reaches the session as an error: a page that only ever saw "connecting"
    // would draw an empty desktop and say nothing about why. The agent's
    // refusal of the *target*, the other way this fails, is
    // `monitor_tunnel_test.dart`'s subject.
    final agent = await _FakeAgent.start(refuseTickets: true);
    addTearDown(agent.close);

    final spi = Spi(
      name: 'unreachable',
      id: 'srv-dead',
      monitorHttp: MonitorHttpCredential(addr: agent.url.toString()),
    );
    Stores.server.put(spi);

    await realHttp(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(serversProvider);

      final sessions = container.read(remoteDesktopSessionsProvider.notifier);
      final profile = profileFor(spi.id);
      sessions.open(profile, sessionPassword: 'secret');
      addTearDown(() => sessions.close(profile.id));

      await _until(
        () =>
            container
                .read(remoteDesktopSessionsProvider)
                .sessions[profile.id]
                ?.error !=
            null,
      );
      expect(
        container
            .read(remoteDesktopSessionsProvider)
            .sessions[profile.id]!
            .connectionState,
        isNot(ffi.RemoteDesktopConnectionState.connected),
      );
      // Nothing was ever dialled, because there was never a socket to dial
      // through.
      expect(agent.dialled, isEmpty);
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}

/// Pumps until [predicate], or fails after a while.
///
/// The provider does its work on real async: a tunnel is dialled through a real
/// socket, and there is no frame here to pump. The deadline is generous because
/// `flutter test` runs a whole suite's files at once, and a login plus a ticket
/// plus an upgrade is three round trips against a machine that is busy with
/// thirty other test processes.
Future<void> _until(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(minutes: 2));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('the condition never became true');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
