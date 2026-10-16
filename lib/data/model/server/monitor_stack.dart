import 'package:collection/collection.dart';

/// A web app a `monitor` agent deployed (`GET /api/v1/stacks`): what the app
/// lists and opens through the agent's proxy. The catalog's other apps, and
/// deploying, stay in the panel.
class MonitorWebApp {
  const MonitorWebApp({
    required this.id,
    required this.title,
    required this.state,
    this.description = const {},
    this.homepage,
    this.version,
    this.latest,
    this.health,
    this.failing = const [],
    this.proxy = false,
  });

  /// `<publisher>.<name>`.
  final String id;

  /// The manifest's title by locale (`en` at least).
  final Map<String, String> title;

  /// The deployment's: `installing`, `installed` or `failed`.
  final String state;

  /// The manifest's description by locale.
  final Map<String, String> description;

  /// The project's site.
  final String? homepage;

  /// The version deployed, and the catalog's now: an update is the panel's
  /// to make when they differ.
  final String? version;
  final String? latest;

  /// The agent's last look at its containers (`healthy`, `starting`,
  /// `unhealthy`, `down`, `stopped`); null before the first.
  final String? health;

  /// The services that are not well.
  final List<String> failing;

  /// Whether the agent's proxy is in front of it now, so it can be opened.
  final bool proxy;

  /// The deployed apps of a `/stacks` answer, in its order; the catalog's
  /// others are left out.
  static List<MonitorWebApp> deployed(Map<String, dynamic> json) => [
    for (final app in json['apps'] as List? ?? const [])
      if (app is Map<String, dynamic>) ?fromJson(app),
  ];

  /// Null for a catalog entry that is not deployed.
  static MonitorWebApp? fromJson(Map<String, dynamic> json) {
    final manifest = json['manifest'];
    final stack = json['stack'];
    if (manifest is! Map || stack is! Map) return null;
    final id = manifest['id'];
    if (id is! String) return null;
    final health = json['health'];
    return MonitorWebApp(
      id: id,
      title: _text(manifest['title']),
      description: _text(manifest['description']),
      homepage: switch (manifest['homepage']) {
        final String url when url.isNotEmpty => url,
        _ => null,
      },
      version: stack['version'] as String?,
      latest: manifest['version'] as String?,
      state: stack['state'] as String? ?? 'installed',
      health: health is Map ? health['state'] as String? : null,
      failing: health is Map ? [...?(health['failing'] as List?)?.whereType<String>()] : const [],
      proxy: json['proxy'] == true,
    );
  }

  static Map<String, String> _text(Object? json) => {
    if (json case final Map text)
      for (final MapEntry(:key, :value) in text.entries)
        if (key is String && value is String) key: value,
  };

  /// [title] in [locale] (`zh-CN`), else its language, else English, as the
  /// panel picks it.
  String titleIn(String locale) => _pick(title, locale) ?? id;

  String? descriptionIn(String locale) => _pick(description, locale);

  /// Whether the catalog has another version than the one deployed.
  bool get updatable => version != null && latest != null && version != latest;

  static String? _pick(Map<String, String> text, String locale) =>
      text[locale] ?? text[locale.split(RegExp('[-_]')).first] ?? text['en'] ?? text.values.firstOrNull;
}

/// A ticket for a web app's proxy (`POST /api/v1/stacks/{id}/enter`).
class MonitorStackEntry {
  const MonitorStackEntry({
    required this.ticket,
    required this.port,
    required this.tls,
    required this.path,
    required this.enter,
    this.url,
  });

  final String ticket;

  /// The proxy's own port on the agent's host.
  final int port;
  final bool tls;

  /// Where the app starts, within its own origin.
  final String path;

  /// The proxy's path that takes the ticket.
  final String enter;

  /// The app's own address when the agent takes apps by host
  /// (`[stacks] apps_url`), instead of the agent's host on [port].
  final String? url;

  factory MonitorStackEntry.fromJson(Map<String, dynamic> json) => MonitorStackEntry(
    ticket: json['ticket'] as String,
    port: (json['port'] as num).toInt(),
    tls: json['tls'] == true,
    path: json['path'] as String? ?? '/',
    enter: json['enter'] as String,
    url: json['url'] as String?,
  );

  /// Where a browser enters the app, for the agent reached at [agent]: the
  /// app's own host when there is one, else the agent's host on the proxy's
  /// port.
  Uri uri(Uri agent) {
    final base = switch (url) {
      final url? => Uri.parse(url).resolve(enter),
      null => Uri(scheme: tls ? 'https' : 'http', host: agent.host, port: port, path: enter),
    };
    return base.replace(queryParameters: {'ticket': ticket, 'next': path});
  }
}
