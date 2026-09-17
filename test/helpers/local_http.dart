import 'dart:io';

/// Routes production HTTP clients to a local fixture server and tracks disposal.
final class LocalHttp extends HttpOverrides {
  LocalHttp(this.server);
  final HttpServer server;
  int requests = 0;
  int created = 0;
  int closed = 0;
  final connectionTimeouts = <Duration?>[];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    created++;
    return _Client(super.createHttpClient(context), this);
  }
}

final class _Client implements HttpClient {
  _Client(this.inner, this.owner);
  final HttpClient inner;
  final LocalHttp owner;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    owner.requests++;
    return inner.openUrl(
      method,
      url.replace(
        scheme: 'http',
        host: owner.server.address.address,
        port: owner.server.port,
      ),
    );
  }

  @override
  set connectionTimeout(Duration? value) {
    owner.connectionTimeouts.add(value);
    inner.connectionTimeout = value;
  }

  @override
  Duration? get connectionTimeout => inner.connectionTimeout;
  @override
  set idleTimeout(Duration value) => inner.idleTimeout = value;
  @override
  void close({bool force = false}) {
    owner.closed++;
    inner.close(force: force);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
