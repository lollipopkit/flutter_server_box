import 'package:collection/collection.dart';

/// An app installed on a `monitor` agent's desk (`GET /api/v1/apps`): a
/// package from its App Store (Kernels, Tailscale, Local inference, …) or
/// uploaded. It runs in the panel; the app opens the panel at it in the
/// device's browser ([uri]).
class MonitorDeskApp {
  const MonitorDeskApp({required this.id, required this.title});

  /// `<publisher>.<name>`.
  final String id;

  /// The manifest's title by locale (`en` at least).
  final Map<String, String> title;

  /// The approved apps of an `/apps` answer, in its order: one waiting for
  /// approval cannot be opened.
  static List<MonitorDeskApp> approved(Map<String, dynamic> json) => [
    for (final app in json['apps'] as List? ?? const [])
      if (app is Map<String, dynamic>) ?fromJson(app),
  ];

  static MonitorDeskApp? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final manifest = json['manifest'];
    if (id is! String || manifest is! Map || json['approved_permissions'] is! List) return null;
    return MonitorDeskApp(
      id: id,
      title: switch (manifest['title']) {
        final String t => {'en': t},
        final Map t => {
          for (final MapEntry(:key, :value) in t.entries)
            if (key is String && value is String) key: value,
        },
        _ => const {},
      },
    );
  }

  /// [title] in [locale] (`zh-CN`), else its language, else English.
  String titleIn(String locale) =>
      title[locale] ?? title[locale.split(RegExp('[-_]')).first] ?? title['en'] ?? title.values.firstOrNull ?? id;

  /// The panel at [agent] (under its path, behind a proxy that serves it
  /// there), opening this app once signed in (`?app=`).
  Uri uri(Uri agent) => Uri(
    scheme: agent.scheme,
    host: agent.host,
    port: agent.port,
    path: agent.path.endsWith('/') ? agent.path : '${agent.path}/',
    queryParameters: {'app': id},
  );
}
