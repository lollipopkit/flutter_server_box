/// The one part of the BMC path that touches the network.
///
/// Everything it decides is decided elsewhere and tested there: which
/// certificate to accept is `PinnedCert`, where to look next is
/// `RedfishDiscovery`, which reset type to send is `ResetRequest`. What is left
/// here is the two things only a live connection has — a TLS handshake, and a
/// session that has to be given back.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/cert_pin.dart';
import 'package:server_box/data/model/server/bmc/redfish_service.dart';
import 'package:server_box/data/model/server/bmc_cfg.dart';
import 'package:server_box/data/model/server/bmc_credential.dart';

/// Reaches one BMC's Redfish service.
///
/// Holds a session, so it is worth keeping and it must be [close]d. See the
/// note on [_login] for what happens if it is not.
class RedfishClient implements RedfishTransport {
  RedfishClient(this.cfg, this.cred);

  /// Where this device is, and which certificate it is allowed to present.
  final BmcCfg cfg;

  /// The account to log in with, which several servers may share — so it
  /// arrives beside [cfg] rather than inside it. See `BmcCredential`.
  final BmcCredential cred;

  Dio? _dio;

  /// The `X-Auth-Token` a login returned, and where to send its funeral.
  String? _token;
  String? _sessionPath;

  /// The login in flight, so that concurrent requests share one.
  ///
  /// Without this, a page that fetches two resources at once creates two
  /// sessions and gives back one. BMCs allow few — enough leaked sessions lock
  /// the management interface out until they time out or someone resets the
  /// device by hand — so the arithmetic matters more here than the round trip.
  Future<void>? _login;

  var _closed = false;

  /// Rejects anything that is not the certificate the user reviewed.
  ///
  /// Two hooks, because they run at different moments and only one of them is
  /// early enough:
  ///
  /// - `badCertificateCallback` runs during the handshake, before a single byte
  ///   of the request exists. This is the one that matters: a password must not
  ///   reach a certificate nobody vouched for.
  /// - dio's `validateCertificate` runs *after* the response arrives, so it is
  ///   too late to protect a credential. It is set anyway for the case the
  ///   first one never sees — a chain that validates against a real CA but is
  ///   not the pinned certificate.
  Dio _session() {
    final existing = _dio;
    if (existing != null) return existing;

    final pin = PinnedCert(cfg.certSha256);
    final dio =
        Dio(
            BaseOptions(
              baseUrl: cfg.addr,
              // A BMC is slow. This is the ceiling on one request, not on a
              // fetch — discovery makes several.
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              // Statuses are read rather than thrown on: 401 and 403 carry
              // meaning here, and licensing makes 403 an ordinary answer.
              validateStatus: (_) => true,
            ),
          )
          ..httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: () =>
                HttpClient()..badCertificateCallback = (cert, _, _) =>
                    pin.accepts(cert),
            validateCertificate: (cert, _, _) => pin.accepts(cert),
          );
    _dio = dio;
    return dio;
  }

  /// Logs in once, and remembers where the session lives so [close] can end it.
  ///
  /// Basic auth is not used for the fetches: a session is one credential
  /// exchange instead of one per request, and this makes several requests per
  /// poll. [probe] is the exception and needs no session at all.
  ///
  /// A *failed* login is not remembered. The field holds the login in flight so
  /// that concurrent requests share one; a future that has already completed
  /// with an error is not one in flight, and keeping it made the first failure
  /// permanent — this client is held across polls, so every minute for the rest
  /// of its life would re-throw that first error without a request being made.
  /// One timeout on a device that takes seconds to answer was enough.
  Future<void> _ensureLogin() {
    final existing = _login;
    if (existing != null) return existing;
    // The field holds the *derived* future, so that is what the handler has to
    // compare against before clearing it — comparing against the raw
    // `_doLogin()` never matches, and the field is then never cleared at all.
    late final Future<void> attempt;
    attempt = _doLogin().catchError((Object e) {
      if (identical(_login, attempt)) _login = null;
      throw e;
    });
    return _login = attempt;
  }

  Future<void> _doLogin() async {
    final sessions = await _sessionsPath();
    final Response<Map<String, dynamic>> res;
    try {
      res = await _session().postUri<Map<String, dynamic>>(
        Uri.parse(sessions),
        data: {'UserName': cred.user, 'Password': cred.pwd ?? ''},
      );
    } on DioException catch (e) {
      throw _asRedfish(e, sessions);
    }

    final code = res.statusCode ?? 0;
    if (code == 401 || code == 403) {
      throw const RedfishException(RedfishFailure.unauthorized);
    }
    // Anything else that is not a success is the service's problem, not the
    // account's. Reporting a 500 as `unauthorized` told the user their password
    // was wrong while the BMC was having a bad day — and it is the answer they
    // would act on, by changing a password that was fine.
    if (code >= 400) {
      throw RedfishException(RedfishFailure.unreachable, 'HTTP $code at login');
    }
    final token = res.headers.value('x-auth-token');
    if (token == null) {
      throw RedfishException(
        RedfishFailure.unreachable,
        'the service returned no token (HTTP $code)',
      );
    }
    _token = token;
    // `Location` is where the session resource is. Falling back to the body's
    // own `@odata.id` because some services fill in only one of the two.
    _sessionPath =
        res.headers.value('location') ??
        (res.data?['@odata.id'] as String?);
  }

  /// Where sessions are created, asked of the service rather than assumed.
  Future<String> _sessionsPath() async {
    final root = await _getJson(RedfishDiscovery.rootPath, authenticated: false);
    final sessions = root['Links'] is Map
        ? (root['Links'] as Map)['Sessions']
        : null;
    final path =
        (sessions is Map ? sessions['@odata.id'] as String? : null) ??
        '${RedfishDiscovery.rootPath}SessionService/Sessions';
    return path;
  }

  /// Whether there is a Redfish service here at all, without logging in.
  ///
  /// The service root is unauthenticated by specification, so this costs no
  /// session — which is the point. Answering "is this a BMC" should not leave
  /// anything behind on a device that allows four of them.
  Future<Map<String, dynamic>> probe() =>
      _getJson(RedfishDiscovery.rootPath, authenticated: false);

  @override
  Future<Map<String, dynamic>> get(String path) => _getJson(path);

  @override
  Future<void> post(String path, Map<String, dynamic> body) async {
    if (_closed) throw StateError('This RedfishClient is closed');
    await _ensureLogin();
    final Response<Map<String, dynamic>> res;
    try {
      res = await _session().postUri<Map<String, dynamic>>(
        Uri.parse(path),
        data: body,
        options: Options(headers: {'X-Auth-Token': _token}),
      );
    } on DioException catch (e) {
      // The same translation `_getJson` does. Without it a reset request that
      // met a rejected certificate came back as a bare `DioException`, and the
      // one failure worth naming reached the UI as an unrecognised error on the
      // one path where the user is waiting for an answer.
      throw _asRedfish(e, path);
    }
    _throwForStatus(res.statusCode ?? 0, path);
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    bool authenticated = true,
  }) async {
    if (_closed) throw StateError('This RedfishClient is closed');
    if (authenticated) await _ensureLogin();

    final Response<Map<String, dynamic>> res;
    try {
      res = await _session().getUri<Map<String, dynamic>>(
        Uri.parse(path),
        options: authenticated
            ? Options(headers: {'X-Auth-Token': _token})
            : null,
      );
    } on DioException catch (e) {
      throw _asRedfish(e, path);
    }

    _throwForStatus(res.statusCode ?? 0, path);
    final data = res.data;
    if (data == null) {
      throw RedfishException(RedfishFailure.notAService, 'no JSON at $path');
    }
    return data;
  }

  /// What a transport failure means, in the terms the rest of the app uses.
  ///
  /// A rejected certificate is the one worth naming: everything else about it
  /// reads as an ordinary network fault, and the fix is a person looking at a
  /// fingerprint rather than a network.
  static RedfishException _asRedfish(DioException e, String path) {
    if (e.type == DioExceptionType.badCertificate ||
        e.error is HandshakeException) {
      return const RedfishException(RedfishFailure.certificateRejected);
    }
    return RedfishException(RedfishFailure.unreachable, e.message ?? path);
  }

  static void _throwForStatus(int code, String path) {
    if (code == 401) {
      throw const RedfishException(RedfishFailure.unauthorized);
    }
    // Licensing gates parts of some services, so this is an answer about this
    // resource and the caller decides what it costs
    if (code == 403) {
      throw RedfishException(RedfishFailure.forbidden, path);
    }
    if (code >= 400) {
      throw RedfishException(RedfishFailure.unreachable, 'HTTP $code at $path');
    }
  }

  /// Ends the session and drops the client.
  ///
  /// Best-effort and never throws: this runs on the failure path as much as the
  /// normal one, and a client that refused to be closed because the DELETE
  /// failed would leak the very thing it was trying not to.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    // A login still in flight is a session about to exist. Closing without
    // waiting for it read `_sessionPath` as null, sent no DELETE, and left
    // behind exactly the session this method exists to give back — on a device
    // that allows about four of them. Its own failure is not this method's
    // problem: there is then no session to release.
    try {
      await _login;
    } catch (_) {}

    final path = _sessionPath;
    final token = _token;
    if (path != null && token != null) {
      try {
        await _session().deleteUri<void>(
          Uri.parse(path),
          options: Options(headers: {'X-Auth-Token': token}),
        );
      } catch (e) {
        // Worth a line: a session that outlives its client is what eventually
        // locks somebody out of their own BMC.
        Loggers.app.warning('BMC session not released ($path)', e);
      }
    }
    _dio?.close(force: true);
    _dio = null;
    _token = null;
    _sessionPath = null;
  }
}
