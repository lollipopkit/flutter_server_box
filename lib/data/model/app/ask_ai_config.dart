import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ask_ai_config.g.dart';

/// How the app talks to a model, as one stored value.
///
/// Six `kv` rows before this — `askAiBaseUrl`, `askAiApiKey`, `askAiModel` and
/// the rest — which is six rows in a backup, six entries in the sync
/// timestamps, and six lines in the raw settings editor for one provider
/// configuration.
///
/// Flat, unlike `AgentShellConfig`: these are six answers to the same
/// question, and every device reads all of them.
///
/// [apiKey] rides in here with the rest. It was already stored in the clear in
/// the same table and exported by the same backup — the database is encrypted
/// and that is what protects it — so this changes where it is written and not
/// what protects it. It is more visible in the raw settings editor than it was
/// as its own row.
///
/// Hand-written `toJson`, like the rest of the models here that have one:
/// `SqliteStore.set` encodes with it and answers `false` rather than throwing
/// when it is missing, so a model without one is dropped silently on every
/// write.
@JsonSerializable()
class AskAiConfig {
  const AskAiConfig({
    this.baseUrl = 'https://api.openai.com',
    this.apiKey = '',
    this.model = 'gpt-5.6-luna',
    this.protocol = 'auto',
    this.autoRunSafeCommands = false,
    this.sendOnEnter = true,
    this.allowInsecure = false,
    this.compactAtPercent = 90,
    this.contextOverrides = const {},
  });

  factory AskAiConfig.fromJson(Map<String, dynamic> json) =>
      _$AskAiConfigFromJson(json);

  final String baseUrl;
  final String apiKey;
  final String model;

  /// One of `AskAiProtocol`'s names, or `auto`. By name, never by index.
  final String protocol;

  /// Whether a command the model proposes may run on a *server* without being
  /// asked. Running on this device is a separate setting and stays off — see
  /// `SettingStore.agentLocalExec`.
  final bool autoRunSafeCommands;

  /// Enter sends the prompt and Shift+Enter starts a line. Off swaps them.
  final bool sendOnEnter;

  /// Whether [baseUrl] may be plain `http` to a host that is not loopback.
  ///
  /// Off, and asked for per configuration rather than inferred from the
  /// address. `http://localhost` is allowed without it — nothing leaves the
  /// device — but a model served over the LAN is still an address this app
  /// sends an API key and the contents of a terminal to in the clear, and the
  /// network it is on is not something the app can judge. Same shape and same
  /// reasoning as `MonitorHttpCredential.allowInsecure`.
  final bool allowInsecure;

  /// How full the context has to get before the conversation is summarised.
  ///
  /// A percentage of what the model holds. Below 100 because the summary is
  /// only useful while there is still room to send it and the turn it is for;
  /// at the limit itself the request has already been refused.
  ///
  /// Configurable because the cost of being wrong is asymmetric and the two
  /// sides are the user's to weigh: too early loses detail that was still
  /// affordable, too late loses the turn.
  final int compactAtPercent;

  /// What a model holds, where the user knows better than the table.
  ///
  /// Keyed by endpoint host *and* model, because either alone is wrong: one
  /// provider serves many models with different windows, and one model name is
  /// served by many providers with different windows — an aggregator's
  /// `gpt-5-nano` may be shorter than OpenAI's. A number typed for one is not
  /// an answer for the other, and switching model used to carry it over.
  ///
  /// Absent means "look it up" — see `ModelContextTable`.
  final Map<String, int> contextOverrides;

  /// How an override is keyed. Host rather than the whole address: a path or a
  /// trailing slash is the same provider.
  static String contextKey(String baseUrl, String model) {
    final trimmed = baseUrl.trim();
    final host = Uri.tryParse(trimmed)?.host ?? '';
    final where = (host.isEmpty ? trimmed : host).toLowerCase();
    return '$where|${model.trim().toLowerCase()}';
  }

  /// The override for one endpoint and model, or zero where there is none.
  int contextOverrideFor(String baseUrl, String model) =>
      contextOverrides[contextKey(baseUrl, model)] ?? 0;

  /// [contextOverrides] with one entry set, or removed when [tokens] is not
  /// positive — "automatic" is the absence of an answer, not a zero stored
  /// forever for every model the user ever opened this dialog on.
  Map<String, int> withContextOverride(
    String baseUrl,
    String model,
    int tokens,
  ) {
    final key = contextKey(baseUrl, model);
    final next = Map<String, int>.from(contextOverrides);
    if (tokens > 0) {
      next[key] = tokens;
    } else {
      next.remove(key);
    }
    return next;
  }

  Map<String, dynamic> toJson() => _$AskAiConfigToJson(this);

  AskAiConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    String? protocol,
    bool? autoRunSafeCommands,
    bool? sendOnEnter,
    bool? allowInsecure,
    int? compactAtPercent,
    Map<String, int>? contextOverrides,
  }) => AskAiConfig(
    baseUrl: baseUrl ?? this.baseUrl,
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
    protocol: protocol ?? this.protocol,
    autoRunSafeCommands: autoRunSafeCommands ?? this.autoRunSafeCommands,
    sendOnEnter: sendOnEnter ?? this.sendOnEnter,
    allowInsecure: allowInsecure ?? this.allowInsecure,
    compactAtPercent: compactAtPercent ?? this.compactAtPercent,
    contextOverrides: contextOverrides ?? this.contextOverrides,
  );

  @override
  bool operator ==(Object other) =>
      other is AskAiConfig &&
      baseUrl == other.baseUrl &&
      apiKey == other.apiKey &&
      model == other.model &&
      protocol == other.protocol &&
      autoRunSafeCommands == other.autoRunSafeCommands &&
      sendOnEnter == other.sendOnEnter &&
      allowInsecure == other.allowInsecure &&
      compactAtPercent == other.compactAtPercent &&
      // By value: `copyWith` hands back a new map every time, and reference
      // equality here would report a change on every write — which a field
      // listenable reads as "my field changed".
      const MapEquality<String, int>().equals(
        contextOverrides,
        other.contextOverrides,
      );

  @override
  int get hashCode => Object.hash(
    baseUrl,
    apiKey,
    model,
    protocol,
    autoRunSafeCommands,
    sendOnEnter,
    allowInsecure,
    compactAtPercent,
    const MapEquality<String, int>().hash(contextOverrides),
  );
}
