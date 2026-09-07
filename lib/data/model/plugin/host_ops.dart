/// What the app can do on a plugin's behalf. PLUGINS.md section 4.3.
///
/// An interface rather than the app's own code called directly, and the reason
/// is what is worth testing: `PluginBridge` is the protocol — which JSON shape
/// means what, and which answer a malformed one gets — and that is checkable
/// only if the app underneath it can be replaced. The app's implementation is
/// `AppPluginHostOps`.
///
/// Nothing here checks a permission. The runtime turns an ungranted function
/// into a throwing stub before a plugin can call it and records a refusal
/// besides, so by the time a request reaches this it has already been allowed
/// — see `sbm_plugin::scope`.
library;

/// What a command on a server answered.
typedef PluginExecResult = ({int code, String stdout, String stderr});

/// What a dialog answered. `values` is empty when it was cancelled.
typedef PluginPromptResult = ({bool cancelled, Map<String, String> values});

/// One field of a dialog.
class PluginPromptField {
  const PluginPromptField({
    required this.key,
    required this.label,
    this.secret = false,
    this.value,
  });

  final String key;
  final String label;
  final bool secret;

  /// What the box starts with.
  ///
  /// Never set for a `secret` field by a plugin that means it: pre-filling one
  /// puts a stored password on screen, which is what marking it secret was
  /// for. An untouched box then reads as "leave it as it was".
  final String? value;

  static PluginPromptField? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['key'];
    if (key is! String || key.isEmpty) return null;
    return PluginPromptField(
      key: key,
      label: '${raw['label'] ?? key}',
      secret: raw['secret'] == true,
      value: raw['value'] is String ? raw['value'] as String : null,
    );
  }
}

/// What a request answered. `cert` is absent where there was no TLS.
typedef PluginFetchResult = ({
  int status,
  Map<String, String> headers,
  String body,
  String bodyEncoding,
  Map<String, Object?>? cert,
});

abstract interface class PluginHostOps {
  /// Runs [script] on [serverId], which the bridge resolved from a handle the
  /// host itself issued.
  Future<PluginExecResult> exec(
    String serverId,
    String script, {
    Duration? timeout,
  });

  /// One HTTP request, or — with [probeCert] — a handshake that sends nothing
  /// and answers with the certificate.
  ///
  /// [pinSha256] is the whole trust decision: absent refuses every
  /// certificate, since the alternative is trusting whatever answers the first
  /// time a request is made, and by then the request carries a password. The
  /// address list and the `probeCert` rules are the runtime's and have already
  /// been checked (`sbm_plugin::scope`).
  Future<PluginFetchResult> fetch({
    required String url,
    required String method,
    Map<String, String> headers,
    String? body,
    String bodyEncoding,
    String? pinSha256,
    bool probeCert,
    Duration? timeout,
  });

  /// [kind] is `info`, `success`, `warn` or `error`.
  void toast(String text, String kind);

  Future<PluginPromptResult> prompt({
    required String title,
    String? message,
    List<PluginPromptField> fields = const [],
    String? confirm,
  });

  /// The server the user chose, or null if they did not choose one.
  Future<String?> pickServer();

  Future<String?> clipboardRead();

  Future<void> clipboardWrite(String text);

  Future<void> openServer(String serverId);

  /// [tab] is an `AppTab` name.
  Future<void> goTab(String tab);

  /// Records that something happened, never what.
  ///
  /// [name] comes from the plugin, so the app keeps it and the level and
  /// decides what else is safe to keep. A plugin that puts a value in the name
  /// has published it, which is why the interface has nowhere else to put one.
  void crumb(String pluginId, String name, String level);
}
