import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';

enum AgentConversationReplayEntryType {
  user,
  assistant,
  commandResult,
  declined,
  inserted,
  notice,
}

@immutable
class AgentConversationReplayEntry {
  const AgentConversationReplayEntry._({
    required this.type,
    this.content,
    this.command,
    this.result,
  });

  const AgentConversationReplayEntry.user(String content)
    : this._(type: AgentConversationReplayEntryType.user, content: content);

  const AgentConversationReplayEntry.assistant(String content)
    : this._(
        type: AgentConversationReplayEntryType.assistant,
        content: content,
      );

  const AgentConversationReplayEntry.commandResult(
    AskAiCommand command,
    AskAiCommandResult result,
  ) : this._(
        type: AgentConversationReplayEntryType.commandResult,
        command: command,
        result: result,
      );

  const AgentConversationReplayEntry.declined()
    : this._(type: AgentConversationReplayEntryType.declined);

  const AgentConversationReplayEntry.inserted()
    : this._(type: AgentConversationReplayEntryType.inserted);

  const AgentConversationReplayEntry.notice(String content)
    : this._(type: AgentConversationReplayEntryType.notice, content: content);

  final AgentConversationReplayEntryType type;
  final String? content;
  final AskAiCommand? command;
  final AskAiCommandResult? result;
}

@immutable
class AgentConversationReplay {
  const AgentConversationReplay({
    required this.entries,
    required this.pendingCommand,
  });

  factory AgentConversationReplay.fromItems(List<AskAiConversationItem> items) {
    final entries = <AgentConversationReplayEntry>[];
    final calls = <String, AskAiCommand>{};
    final callOrder = <String>[];
    final completedCalls = <String>{};

    for (final item in items) {
      switch (item) {
        case AskAiMessageItem(:final role, :final content):
          if (content.trim().isEmpty) continue;
          entries.add(
            role == AskAiMessageRole.user
                ? AgentConversationReplayEntry.user(content)
                : AgentConversationReplayEntry.assistant(content),
          );
        case AskAiFunctionCallItem(:final command):
          calls[command.id] = command;
          callOrder.add(command.id);
        case AskAiFunctionOutputItem(:final callId, :final output):
          completedCalls.add(callId);
          final command = calls[callId];
          if (command == null) continue;
          final result = AskAiCommandResult.tryFromToolMessage(
            output,
            fallbackCommand: command.command,
          );
          if (result != null) {
            entries.add(
              AgentConversationReplayEntry.commandResult(command, result),
            );
            continue;
          }
          switch (_decodeToolAction(output)) {
            case AgentConversationToolAction.declined:
              entries.add(const AgentConversationReplayEntry.declined());
            case AgentConversationToolAction.inserted:
              entries.add(const AgentConversationReplayEntry.inserted());
            case null:
              if (output.trim().isNotEmpty) {
                entries.add(AgentConversationReplayEntry.notice(output));
              }
          }
        case AskAiReasoningItem() || AskAiRawResponseItem():
          break;
      }
    }

    AskAiCommand? pendingCommand;
    for (final callId in callOrder.reversed) {
      if (completedCalls.contains(callId)) continue;
      pendingCommand = calls[callId];
      break;
    }
    return AgentConversationReplay(
      entries: List.unmodifiable(entries),
      pendingCommand: pendingCommand,
    );
  }

  final List<AgentConversationReplayEntry> entries;
  final AskAiCommand? pendingCommand;
}

enum AgentConversationToolAction { declined, inserted }

bool shouldAutoRunAgentCommand({
  required AskAiCommand command,
  required bool enabled,
  required bool restored,
  required int runCount,
}) {
  return enabled && !restored && command.canAutoRun && runCount < 3;
}

String encodeAgentConversationToolAction(AgentConversationToolAction action) {
  final message = switch (action) {
    AgentConversationToolAction.declined =>
      'The user declined this command. Do not assume it was executed.',
    AgentConversationToolAction.inserted =>
      'The command was inserted into the interactive terminal. Its execution result is unknown.',
  };
  return jsonEncode({'server_box_action': action.name, 'message': message});
}

AgentConversationToolAction? _decodeToolAction(String output) {
  try {
    final value = jsonDecode(output);
    if (value is! Map) return null;
    final action = value['server_box_action'];
    return AgentConversationToolAction.values.firstWhere(
      (item) => item.name == action,
      orElse: () => throw const FormatException(),
    );
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}
