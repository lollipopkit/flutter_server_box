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
    this.contextTokens = 0,
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

  /// What the model holds, when the user knows better than the table.
  ///
  /// Zero means "look it up" — see `ModelContextTable`, which ships a copy of
  /// models.dev and matches on the end of the name. A proxy that serves a
  /// shorter window than the model has is the case this exists for; so is a
  /// model that is newer than the table.
  final int contextTokens;

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
    int? contextTokens,
  }) => AskAiConfig(
    baseUrl: baseUrl ?? this.baseUrl,
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
    protocol: protocol ?? this.protocol,
    autoRunSafeCommands: autoRunSafeCommands ?? this.autoRunSafeCommands,
    sendOnEnter: sendOnEnter ?? this.sendOnEnter,
    allowInsecure: allowInsecure ?? this.allowInsecure,
    compactAtPercent: compactAtPercent ?? this.compactAtPercent,
    contextTokens: contextTokens ?? this.contextTokens,
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
      contextTokens == other.contextTokens;

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
    contextTokens,
  );
}
