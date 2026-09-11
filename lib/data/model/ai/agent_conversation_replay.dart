import 'dart:convert';

import 'package:server_box/data/model/ai/ask_ai_models.dart';

/// What the app did with a tool call other than run it.
///
/// Stored as the call's output, so the model reads it as the result on the
/// next turn — hence the sentences below, which are protocol rather than
/// anything the user sees. Replaying one is `replayAgentTimeline`, which is
/// where the entry types this file used to carry now live: a conversation is
/// replayed the same way for both Agent surfaces.

enum AgentConversationToolAction { declined, inserted, skipped }

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
    // Answered rather than left empty. A call this app did not run still has
    // to have an output, or the next request carries an assistant message
    // whose `tool_calls` outnumber the `tool` messages answering them, which
    // the API rejects outright.
    AgentConversationToolAction.skipped =>
      'ServerBox reviews one tool call at a time, so this one was not run and '
          'nothing happened on the server. Request it again on its own if it '
          'is still needed.',
  };
  return jsonEncode({'server_box_action': action.name, 'message': message});
}

/// The counterpart of [encodeAgentConversationToolAction]: what the app did
/// with a tool call, read back out of a stored conversation. Null when the
/// output is a tool result or something else entirely.
AgentConversationToolAction? decodeAgentConversationToolAction(String output) {
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
