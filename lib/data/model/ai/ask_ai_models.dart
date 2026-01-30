import 'package:meta/meta.dart';

/// Chat message exchanged with the Ask AI service.
enum AskAiMessageRole { user, assistant }

@immutable
class AskAiMessage {
  const AskAiMessage({
    required this.role,
    required this.content,
  });

  final AskAiMessageRole role;
  final String content;

  String get apiRole {
    switch (role) {
      case AskAiMessageRole.user:
        return 'user';
      case AskAiMessageRole.assistant:
        return 'assistant';
    }
  }
}

/// Recommended command returned by the AI tool call.
@immutable
class AskAiCommand {
  const AskAiCommand({
    required this.command,
    this.description = '',
    this.toolName,
    this.risk,
    this.needsConfirmation,
    this.why,
    this.prechecks,
  });

  final String command;
  final String description;
  final String? toolName;

  /// Optional risk hint returned by the model/tool, e.g. `low|medium|high`.
  final String? risk;

  /// Optional explicit confirmation requirement returned by the model/tool.
  final bool? needsConfirmation;

  /// Optional explanation for why this command is suggested.
  final String? why;

  /// Optional pre-check commands / steps.
  final List<String>? prechecks;
}

@immutable
sealed class AskAiEvent {
  const AskAiEvent();
}

/// Incremental text delta emitted while streaming the AI response.
class AskAiContentDelta extends AskAiEvent {
  const AskAiContentDelta(this.delta);
  final String delta;
}

/// Emits when a tool call returns a runnable command suggestion.
class AskAiToolSuggestion extends AskAiEvent {
  const AskAiToolSuggestion(this.command);
  final AskAiCommand command;
}

/// Signals that the stream finished successfully.
class AskAiCompleted extends AskAiEvent {
  const AskAiCompleted({
    required this.fullText,
    required this.commands,
  });

  final String fullText;
  final List<AskAiCommand> commands;
}

/// Signals that the stream terminated with an error before completion.
class AskAiStreamError extends AskAiEvent {
  const AskAiStreamError(this.error, this.stackTrace);

  final Object error;
  final StackTrace? stackTrace;
}
