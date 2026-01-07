import 'dart:async';
import 'dart:io';

import 'package:computer/computer.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';

part 'pve.freezed.dart';
part 'pve.g.dart';

typedef PveCtrlFunc = Future<bool> Function(String node, String id);

@freezed
abstract class PveState with _$PveState {
  const factory PveState({
    @Default(null) PveErr? error,
    @Default(null) PveRes? data,
    @Default(null) String? release,
    @Default(false) bool isBusy,
    @Default(false) bool isConnected,
  }) = _PveState;
}

@riverpod
class PveNotifier extends _$PveNotifier {
  late final Spi spi;
  late String addr;
  late final SSHClient _client;
  late final ServerSocket _serverSocket;
  final List<SSHForwardChannel> _forwards = [];
  int _localPort = 0;
  late final Dio session;
  late final bool _ignoreCert;

  @override
  PveState build(Spi spiParam) {
    spi = spiParam;
    final serverState = ref.watch(serverProvider(spi.id));
    final client = serverState.client;
    if (client == null) {
      return const PveState(error: PveErr(type: PveErrType.net, message: 'Server client is null'));
    }
    _client = client;
    final addr = spi.custom?.pveAddr;
    if (addr == null) {
      return PveState(error: PveErr(type: PveErrType.net, message: 'PVE address is null'));
    }
    this.addr = addr;
    _ignoreCert = spi.custom?.pveIgnoreCert ?? false;
    _initSession();
    // Async initialization
    Future.microtask(() => _init());
    return const PveState();
  }

  void _initSession() {
    session = Dio()
      ..httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.connectionFactory = cf;
          if (_ignoreCert) {
            client.badCertificateCallback = (_, _, _) => true;
          }
          return client;
        },
        validateCertificate: _ignoreCert ? (_, _, _) => true : null,
      );
  }

  bool get onlyOneNode => state.data?.nodes.length == 1;

  Future<void> _init() async {
    try {
      await _forward();
      await _login();
      await _getRelease();
      state = state.copyWith(isConnected: true);
    } on PveErr {
      state = state.copyWith(error: PveErr(type: PveErrType.loginFailed, message: l10n.pveLoginFailed));
    } catch (e, s) {
      Loggers.app.warning('PVE init failed', e, s);
      state = state.copyWith(error: PveErr(type: PveErrType.unknown, message: e.toString()));
    }
  }

  Future<void> _forward() async {
    final url = Uri.parse(addr);
    if (_localPort == 0) {
      _serverSocket = await ServerSocket.bind('localhost', 0);
      _localPort = _serverSocket.port;
      _serverSocket.listen((socket) async {
        final forward = await _client.forwardLocal(url.host, url.port);
        _forwards.add(forward);
        forward.stream.cast<List<int>>().pipe(socket);
        socket.cast<List<int>>().pipe(forward.sink);
      });
      final newUrl = Uri.parse(
        addr,
      ).replace(host: 'localhost', port: _localPort).toString();
      dprint('Forwarding $newUrl to $addr');
    }
  }

  Future<ConnectionTask<Socket>> cf(
    Uri url,
    String? proxyHost,
    int? proxyPort,
  ) async {
    /* final serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final _localPort = serverSocket.port;
    serverSocket.listen((socket) async {
      final forward = await _client.forwardLocal(url.host, url.port);
      forwards.add(forward);
      forward.stream.cast<List<int>>().pipe(socket);
      socket.cast<List<int>>().pipe(forward.sink);
    });*/

    if (url.isScheme('https')) {
      return SecureSocket.startConnect(
        'localhost',
        _localPort,
        onBadCertificate: (_) => true,
      );
    } else {
      return Socket.startConnect('localhost', _localPort);
    }
  }

  Future<void> _login() async {
    final resp = await session.post(
      '$addr/api2/extjs/access/ticket',
      data: {
        'username': spi.user,
        'password': spi.pwd,
        'realm': 'pam',
        'new-format': '1',
      },
      options: Options(
        headers: {HttpHeaders.contentTypeHeader: Headers.jsonContentType},
      ),
    );
    try {
      final ticket = resp.data['data']['ticket'];
      session.options.headers['CSRFPreventionToken'] =
          resp.data['data']['CSRFPreventionToken'];
      session.options.headers['Cookie'] = 'PVEAuthCookie=$ticket';
    } catch (e) {
      throw PveErr(type: PveErrType.loginFailed, message: e.toString());
    }
  }

  /// Returns true if the PVE version is 8.0 or later
  Future<void> _getRelease() async {
    final resp = await session.get('$addr/api2/extjs/version');
    final version = resp.data['data']['release'] as String?;
    if (version != null) {
      state = state.copyWith(release: version);
    }
  }

  Future<void> list() async {
    if (!state.isConnected || state.isBusy) return;
    state = state.copyWith(isBusy: true);
    try {
      final resp = await session.get('$addr/api2/json/cluster/resources');
      final res = resp.data['data'] as List;
      final result = await Computer.shared.start(PveRes.parse, (
        res,
        state.data,
      ));
      state = state.copyWith(data: result, error: null);
    } catch (e) {
      Loggers.app.warning('PVE list failed', e);
      state = state.copyWith(error: PveErr(type: PveErrType.unknown, message: e.toString()));
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<bool> reboot(String node, String id) async {
    if (!state.isConnected) return false;
    final resp = await session.post(
      '$addr/api2/json/nodes/$node/$id/status/reboot',
    );
    final success = _isCtrlSuc(resp);
    if (success) await list(); // Refresh data
    return success;
  }

  Future<bool> start(String node, String id) async {
    if (!state.isConnected) return false;
    final resp = await session.post(
      '$addr/api2/json/nodes/$node/$id/status/start',
    );
    final success = _isCtrlSuc(resp);
    if (success) await list(); // Refresh data
    return success;
  }

  Future<bool> stop(String node, String id) async {
    if (!state.isConnected) return false;
    final resp = await session.post(
      '$addr/api2/json/nodes/$node/$id/status/stop',
    );
    final success = _isCtrlSuc(resp);
    if (success) await list(); // Refresh data
    return success;
  }

  Future<bool> shutdown(String node, String id) async {
    if (!state.isConnected) return false;
    final resp = await session.post(
      '$addr/api2/json/nodes/$node/$id/status/shutdown',
    );
    final success = _isCtrlSuc(resp);
    if (success) await list(); // Refresh data
    return success;
  }

  bool _isCtrlSuc(Response resp) {
    return resp.statusCode == 200;
  }

  Future<void> dispose() async {
    try {
      await _serverSocket.close();
    } catch (e, s) {
      Loggers.app.warning('Failed to close server socket', e, s);
    }
    for (final forward in _forwards) {
      try {
        forward.close();
      } catch (e, s) {
        Loggers.app.warning('Failed to close forward', e, s);
      }
    }
  }
}
