import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/tab.dart';

/// A `serverbox://` link, parsed.
///
/// Says where to go and nothing more. Any web page or app can open one, so
/// what a link may *do* is decided by whoever acts on it: going somewhere
/// happens at once, anything with a side effect asks first, and a new server
/// is only ever a filled-in form. That is why [AddServerLink] carries no
/// password or key — a URL ends up in browser history and clipboard managers.
///
/// Parsing never throws: a link is outside input, and one this build does not
/// understand is `null`, not an error.
sealed class AppLink {
  const AppLink();

  static const scheme = 'serverbox';

  static AppLink? parse(String raw) {
    // The whole of it, not only `Uri.parse`: `pathSegments` and
    // `queryParameters` decode on first read, and a bad escape throws there.
    try {
      return _parse(Uri.parse(raw.trim()));
    } on FormatException {
      return null;
    }
  }

  static AppLink? _parse(Uri uri) {
    if (uri.scheme.toLowerCase() != scheme) return null;
    var segs = uri.pathSegments;
    // One trailing slash is how a link typed by hand often ends. An empty
    // segment anywhere else is a malformed link, not a shorter one: dropping
    // it read `server//files` as the server whose id is `files`.
    if (segs.isNotEmpty && segs.last.isEmpty) {
      segs = segs.sublist(0, segs.length - 1);
    }
    if (segs.any((seg) => seg.isEmpty)) return null;
    final query = uri.queryParameters;
    return switch (uri.host.toLowerCase()) {
      ServerLink._host => ServerLink._parse(segs),
      AddServerLink._host when segs.isEmpty => AddServerLink._parse(query),
      TabLink._host when segs.length == 1 => TabLink._parse(segs.single),
      SnippetLink._host when segs.length == 1 => SnippetLink(
        segs.single,
        serverId: _nonEmpty(query['server']),
      ),
      _ => null,
    };
  }

  Uri toUri();

  @override
  String toString() => toUri().toString();

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// A saved server's page, or one of its functions: the same set, under the
/// same names, as its function row ([ServerFuncBtn]).
final class ServerLink extends AppLink {
  const ServerLink(this.id, {this.func});

  static const _host = 'server';

  final String id;

  /// Null opens the server's page.
  final ServerFuncBtn? func;

  static ServerLink? _parse(List<String> segs) {
    switch (segs) {
      case [final id]:
        return ServerLink(id);
      case [final id, final name]:
        final func = ServerFuncBtn.values.asNameMap()[name];
        return func == null ? null : ServerLink(id, func: func);
    }
    return null;
  }

  @override
  Uri toUri() => Uri(
    scheme: AppLink.scheme,
    host: _host,
    pathSegments: [id, ?func?.name],
  );
}

/// The add-server form, filled in. Saved only by the user.
final class AddServerLink extends AppLink {
  const AddServerLink({this.name, this.host, this.port, this.user});

  static const _host = 'add-server';

  final String? name;
  final String? host;
  final int? port;
  final String? user;

  static AddServerLink? _parse(Map<String, String> query) {
    final port = int.tryParse(query['port'] ?? '');
    final link = AddServerLink(
      name: AppLink._nonEmpty(query['name']),
      host: AppLink._nonEmpty(query['host']),
      // Out of range is dropped rather than refused: the rest of the form is
      // still worth filling in, and the field shows its own default.
      port: port != null && port > 0 && port < 65536 ? port : null,
      user: AppLink._nonEmpty(query['user']),
    );
    return link.host == null ? null : link;
  }

  @override
  Uri toUri() => Uri(
    scheme: AppLink.scheme,
    host: _host,
    queryParameters: {
      'host': ?host,
      if (port case final port?) 'port': '$port',
      'user': ?user,
      'name': ?name,
    },
  );
}

/// One of the home tabs, by its [AppTab] name.
final class TabLink extends AppLink {
  const TabLink(this.tab);

  static const _host = 'tab';

  final AppTab tab;

  static TabLink? _parse(String name) {
    final tab = AppTab.values.asNameMap()[name];
    return tab == null ? null : TabLink(tab);
  }

  @override
  Uri toUri() =>
      Uri(scheme: AppLink.scheme, host: _host, pathSegments: [tab.name]);
}

/// A saved snippet, run on [serverId] — or on a server picked when it is null.
/// Always shown and confirmed before it runs.
final class SnippetLink extends AppLink {
  const SnippetLink(this.id, {this.serverId});

  static const _host = 'snippet';

  final String id;
  final String? serverId;

  @override
  Uri toUri() => Uri(
    scheme: AppLink.scheme,
    host: _host,
    pathSegments: [id],
    queryParameters: serverId == null ? null : {'server': serverId},
  );
}
