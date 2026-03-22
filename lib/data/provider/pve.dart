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

enum PveLoadingStep {
  none,
  forwarding,
  loggingIn,
  fetchingData,
}

@freezed
abstract class PveState with _$PveState {
  const factory PveState({
    @Default(null) PveErr? error,
    @Default(null) PveRes? data,
    @Default(null) String? release,
    @Default(false) bool isBusy,
    @Default(false) bool isConnected,
    @Default(PveLoadingStep.none) PveLoadingStep loadingStep,
  }) = _PveState;
}

@riverpod
class PveNotifier extends _$PveNotifier {
  late String addr;
  late final ServerSocket _serverSocket;
  final List<SSHForwardChannel> _forwards = [];
  int _localPort = 0;
  late final Dio session;
  late final bool _ignoreCert;

  SSHClient get _client {
    final serverState = ref.read(serverProvider(spiParam.id));
    final client = serverState.client;
    if (client == null) {
      throw PveErr(type: PveErrType.net, message: 'Server client is null');
    }
    return client;
  }

  @override
  PveState build(Spi spiParam) {
    ref.onDispose(() => dispose());
    final serverState = ref.read(serverProvider(spiParam.id));
    if (serverState.client == null) {
      return const PveState(error: PveErr(type: PveErrType.net, message: 'Server client is null'));
    }
    final addr = spiParam.custom?.pveAddr;
    if (addr == null) {
      return PveState(error: PveErr(type: PveErrType.net, message: 'PVE address is null'));
    }
    this.addr = addr;
    _ignoreCert = spiParam.custom?.pveIgnoreCert ?? false;
    _initSession();
    Future.microtask(() => _init());
    return const PveState(loadingStep: PveLoadingStep.forwarding);
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
      if (!ref.mounted) return;
      state = state.copyWith(loadingStep: PveLoadingStep.forwarding);
      await _forward();
      if (!ref.mounted) return;
      state = state.copyWith(loadingStep: PveLoadingStep.loggingIn);
      await _login();
      if (!ref.mounted) return;
      state = state.copyWith(loadingStep: PveLoadingStep.fetchingData);
      await _getRelease();
      if (!ref.mounted) return;
      state = state.copyWith(isConnected: true);
      await list();
      if (!ref.mounted) return;
      state = state.copyWith(loadingStep: PveLoadingStep.none);
    } on PveErr {
      if (!ref.mounted) return;
      state = state.copyWith(error: PveErr(type: PveErrType.loginFailed, message: l10n.pveLoginFailed), loadingStep: PveLoadingStep.none);
    } catch (e, s) {
      if (!ref.mounted) return;
      Loggers.app.warning('PVE init failed', e, s);
      state = state.copyWith(error: PveErr(type: PveErrType.unknown, message: e.toString()), loadingStep: PveLoadingStep.none);
    }
  }

  Future<void> _forward() async {
    final url = Uri.parse(addr);
    if (_localPort == 0) {
      _serverSocket = await ServerSocket.bind('localhost', 0);
      _localPort = _serverSocket.port;
      _serverSocket.listen((socket) async {
        try {
          final forward = await _client.forwardLocal(url.host, url.port);
          _forwards.add(forward);
          forward.stream.cast<List<int>>().pipe(socket);
          socket.cast<List<int>>().pipe(forward.sink);
        } catch (e, s) {
          Loggers.app.warning('PVE forward failed', e, s);
          socket.destroy();
        }
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
        'username': spiParam.user,
        'password': spiParam.pwd,
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
    if (version != null && ref.mounted) {
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
      if (!ref.mounted) return;
      state = state.copyWith(data: result, error: null);
    } catch (e) {
      if (!ref.mounted) return;
      Loggers.app.warning('PVE list failed', e);
      state = state.copyWith(error: PveErr(type: PveErrType.unknown, message: e.toString()));
    } finally {
      if (ref.mounted) {
        state = state.copyWith(isBusy: false);
      }
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
