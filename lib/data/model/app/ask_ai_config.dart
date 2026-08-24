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

  Map<String, dynamic> toJson() => _$AskAiConfigToJson(this);

  AskAiConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    String? protocol,
    bool? autoRunSafeCommands,
    bool? sendOnEnter,
  }) => AskAiConfig(
    baseUrl: baseUrl ?? this.baseUrl,
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
    protocol: protocol ?? this.protocol,
    autoRunSafeCommands: autoRunSafeCommands ?? this.autoRunSafeCommands,
    sendOnEnter: sendOnEnter ?? this.sendOnEnter,
  );

  @override
  bool operator ==(Object other) =>
      other is AskAiConfig &&
      baseUrl == other.baseUrl &&
      apiKey == other.apiKey &&
      model == other.model &&
      protocol == other.protocol &&
      autoRunSafeCommands == other.autoRunSafeCommands &&
      sendOnEnter == other.sendOnEnter;

  @override
  int get hashCode => Object.hash(
    baseUrl,
    apiKey,
    model,
    protocol,
    autoRunSafeCommands,
    sendOnEnter,
  );
}
