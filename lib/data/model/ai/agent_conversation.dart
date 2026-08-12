import 'package:meta/meta.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';

@immutable
class AgentConversation {
  const AgentConversation({
    required this.id,
    required this.serverId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.protocol,
    required this.providerBaseUrl,
    required this.model,
    required this.items,
  });

  factory AgentConversation.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .map(AskAiConversationItem.fromJson)
              .whereType<AskAiConversationItem>()
              .toList(growable: false)
        : const <AskAiConversationItem>[];
    return AgentConversation(
      id: json['id'] as String? ?? '',
      serverId: json['server_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
      protocol: parseAskAiProtocol(json['protocol']),
      providerBaseUrl: json['provider_base_url'] as String? ?? '',
      model: json['model'] as String? ?? '',
      items: items,
    );
  }

  final String id;
  final String serverId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AskAiProtocol protocol;
  final String providerBaseUrl;
  final String model;
  final List<AskAiConversationItem> items;

  AgentConversation copyWith({
    String? title,
    DateTime? updatedAt,
    AskAiProtocol? protocol,
    String? providerBaseUrl,
    String? model,
    List<AskAiConversationItem>? items,
  }) {
    return AgentConversation(
      id: id,
      serverId: serverId,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      protocol: protocol ?? this.protocol,
      providerBaseUrl: providerBaseUrl ?? this.providerBaseUrl,
      model: model ?? this.model,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': 1,
    'id': id,
    'server_id': serverId,
    'title': title,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'protocol': protocol.name,
    'provider_base_url': providerBaseUrl,
    'model': model,
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };
}

DateTime _dateTimeFromJson(Object? value) {
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}
