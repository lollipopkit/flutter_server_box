import 'dart:convert';

import 'package:meta/meta.dart';

/// Chat message exchanged with the Ask AI service.
enum AskAiMessageRole { user, assistant, tool }

@immutable
class AskAiMessage {
  const AskAiMessage({
    required this.role,
    required this.content,
    this.toolCalls = const [],
    this.toolCallId,
    this.reasoningContent,
  });

  const AskAiMessage.user(String content)
    : this(role: AskAiMessageRole.user, content: content);

  const AskAiMessage.assistant(
    String content, {
    List<AskAiCommand> toolCalls = const [],
    String? reasoningContent,
  }) : this(
         role: AskAiMessageRole.assistant,
         content: content,
         toolCalls: toolCalls,
         reasoningContent: reasoningContent,
       );

  const AskAiMessage.tool({required String toolCallId, required String content})
    : this(
        role: AskAiMessageRole.tool,
        content: content,
        toolCallId: toolCallId,
      );

  final AskAiMessageRole role;
  final String content;
  final List<AskAiCommand> toolCalls;
  final String? toolCallId;
  final String? reasoningContent;

  String get apiRole => role.name;

  Map<String, dynamic> toApiJson() {
    return switch (role) {
      AskAiMessageRole.user => {'role': apiRole, 'content': content},
      AskAiMessageRole.assistant => {
        'role': apiRole,
        'content': content.isEmpty ? null : content,
        if (reasoningContent?.isNotEmpty == true)
          'reasoning_content': reasoningContent,
        if (toolCalls.isNotEmpty)
          'tool_calls': toolCalls.map((call) => call.toToolCallJson()).toList(),
      },
      AskAiMessageRole.tool => {
        'role': apiRole,
        'tool_call_id': toolCallId,
        'content': content,
      },
    };
  }
}

enum AskAiCommandRisk { readOnly, caution, destructive }

/// A command proposal returned by the AI tool call.
@immutable
class AskAiCommand {
  const AskAiCommand({
    required this.command,
    this.id = 'run-shell-command',
    this.description = '',
    this.toolName = 'run_shell_command',
    this.rawArguments = '',
    this.modelSafeToRun = false,
  });

  final String id;
  final String command;
  final String description;
  final String toolName;
  final String rawArguments;

  /// This is advisory only. Local risk classification must also consider the
  /// command safe before the app may auto-run it.
  final bool modelSafeToRun;

  AskAiCommandRisk get risk => classifyRisk(command);

  bool get canAutoRun => modelSafeToRun && risk == AskAiCommandRisk.readOnly;

  Map<String, dynamic> toToolCallJson() {
    final arguments = rawArguments.isNotEmpty
        ? rawArguments
        : jsonEncode({
            'command': command,
            'description': description,
            'safe_to_run': modelSafeToRun,
          });
    return {
      'id': id,
      'type': 'function',
      'function': {'name': toolName, 'arguments': arguments},
    };
  }

  @visibleForTesting
  static AskAiCommandRisk classifyRisk(String command) {
    var normalized = command.trim().toLowerCase();
    if (normalized.isEmpty) return AskAiCommandRisk.caution;

    // Read-only inspection commands commonly silence expected errors. Ignore
    // only these exact redirections before checking for writes.
    normalized = normalized.replaceAll(
      RegExp(r'\b[012]?>>?\s*/dev/null\b'),
      '',
    );

    final destructivePatterns = <RegExp>[
      RegExp(r'(^|[;&|]\s*)(sudo\s+)?rm\s'),
      RegExp(r'(^|[;&|]\s*)(sudo\s+)?(shred|wipefs|mkfs(\.[a-z0-9]+)?)\b'),
      RegExp(r'(^|[;&|]\s*)(sudo\s+)?dd\s+.*\bof='),
      RegExp(r'\b(find|xargs)\b.*\b-delete\b'),
      RegExp(r'\b(find|xargs)\b.*\brm\b'),
      RegExp(r'\b(git\s+reset\s+--hard|git\s+clean\s+-[^\s]*f)\b'),
      RegExp(r'\b(docker|podman)\s+(system\s+)?prune\b'),
      RegExp(r'\bkubectl\s+delete\b'),
      RegExp(r'\b(drop|truncate)\s+(database|table)\b'),
      RegExp(r'\bdelete\s+from\b'),
      RegExp(r'(^|[;&|]\s*)(shutdown|reboot|poweroff|halt)\b'),
      RegExp(r'\b(remove-item|format-volume|clear-disk)\b'),
      RegExp(r'(^|[;&|]\s*)(del|rmdir)\s'),
      RegExp(r':\s*\(\s*\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:'),
    ];
    if (destructivePatterns.any((pattern) => pattern.hasMatch(normalized))) {
      return AskAiCommandRisk.destructive;
    }

    final mutatingPatterns = <RegExp>[
      RegExp(r'(^|[^<])>>?\s*[^&]'),
      RegExp(
        r'\|\s*(sudo\s+)?(sh|bash|zsh|fish|python\d*|perl|ruby|node|pwsh|powershell|cmd)\b',
      ),
      RegExp(r'(^|[;&|]\s*)(eval|source)\b|(^|[;&|]\s*)\.\s+'),
      RegExp(r'\$\(|`'),
      RegExp(r'(^|[;&|]\s*)(sh|bash|zsh|fish)\s+-c\b'),
      RegExp(r'\bfind\b.*\s-exec(dir)?\b'),
      RegExp(r'\bawk\b.*\bsystem\s*\('),
      RegExp(r'(^|[;&|]\s*)(sudo\s+)?(mv|cp|touch|mkdir|chmod|chown|ln)\s'),
      RegExp(r'(^|[;&|]\s*)(sudo\s+)?tee\b'),
      RegExp(r'\bsed\s+[^;&|]*\s-i([.\s]|$)'),
      RegExp(
        r'\b(systemctl|service)\s+(start|stop|restart|reload|enable|disable|mask|unmask)\b',
      ),
      RegExp(r'(^|[;&|]\s*)(sudo\s+)?(kill|pkill|killall)\b'),
      RegExp(
        r'\b(apt|apt-get|dnf|yum|pacman|zypper|apk|brew)\s+(install|remove|erase|upgrade|update)\b',
      ),
      RegExp(
        r'\b(docker|podman)\s+(start|stop|restart|rm|rmi|pull|push|build|run|exec)\b',
      ),
      RegExp(r'\b(docker|podman)\s+compose\s+(up|down|restart|pull|build)\b'),
      RegExp(
        r'\bkubectl\s+(apply|create|edit|patch|replace|scale|rollout|set)\b',
      ),
      RegExp(
        r'\bgit\s+(add|commit|push|pull|merge|rebase|checkout|switch|restore|tag)\b',
      ),
      RegExp(
        r'\b(curl|wget)\b.*\s(-o|--output|-x\s+(post|put|patch|delete)|--request\s+(post|put|patch|delete))\b',
      ),
      RegExp(
        r'\b(set-content|add-content|new-item|copy-item|move-item|rename-item|start-service|stop-service|restart-service)\b',
      ),
    ];
    if (mutatingPatterns.any((pattern) => pattern.hasMatch(normalized))) {
      return AskAiCommandRisk.caution;
    }

    final stripped = normalized
        .replaceFirst(RegExp(r'^sudo\s+'), '')
        .replaceFirst(RegExp(r'^(env\s+)?([a-z_][a-z0-9_]*=[^\s]+\s+)+'), '');
    final readOnlyStarts = <RegExp>[
      RegExp(r'^(ls|pwd|whoami|id|groups|uname|hostname|uptime|date|cal)\b'),
      RegExp(
        r'^(cat|head|tail|less|more|grep|egrep|fgrep|rg|awk|cut|sort|uniq|wc|tr|sed\s+(?!.*\s-i))\b',
      ),
      RegExp(
        r'^(df|du|free|vmstat|iostat|mpstat|top|ps|pgrep|lsof|stat|file|readlink|realpath)\b',
      ),
      RegExp(r'^(find|locate|which|whereis|type|command\s+-v)\b'),
      RegExp(
        r'^(ip|ss|netstat|ifconfig|route|ping|traceroute|tracepath|dig|nslookup|host)\b',
      ),
      RegExp(
        r'^(journalctl|dmesg|systemctl\s+(status|show|is-active|is-enabled|list-)|service\s+[^\s]+\s+status)\b',
      ),
      RegExp(
        r'^(docker|podman)\s+(ps|images|inspect|logs|stats|info|version)\b',
      ),
      RegExp(r'^(docker|podman)\s+compose\s+(ps|logs|config|ls)\b'),
      RegExp(
        r'^kubectl\s+(get|describe|logs|api-resources|api-versions|cluster-info|version)\b',
      ),
      RegExp(
        r'^git\s+(status|diff|log|show|branch|remote|rev-parse|ls-files|ls-tree)\b',
      ),
      RegExp(
        r'^(get-[a-z0-9-]+|test-[a-z0-9-]+|select-[a-z0-9-]+|where-object|measure-object|compare-object|tasklist|systeminfo|dir|type)\b',
      ),
    ];
    if (readOnlyStarts.any((pattern) => pattern.hasMatch(stripped))) {
      return AskAiCommandRisk.readOnly;
    }
    return AskAiCommandRisk.caution;
  }
}

@immutable
class AskAiCommandResult {
  const AskAiCommandResult({
    required this.command,
    required this.stdout,
    required this.stderr,
    required this.duration,
    this.exitCode,
    this.cancelled = false,
    this.timedOut = false,
    this.truncated = false,
  });

  final String command;
  final int? exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;
  final bool cancelled;
  final bool timedOut;
  final bool truncated;

  bool get succeeded => !cancelled && !timedOut && exitCode == 0;

  String get displayOutput {
    final buffer = StringBuffer();
    if (stdout.trim().isNotEmpty) buffer.write(stdout.trimRight());
    if (stderr.trim().isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write(stderr.trimRight());
    }
    return buffer.toString();
  }

  String toToolMessage() {
    return jsonEncode({
      'command': command,
      'exit_code': exitCode,
      'cancelled': cancelled,
      'timed_out': timedOut,
      'output_truncated': truncated,
      'stdout': stdout,
      'stderr': stderr,
    });
  }
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

/// Emits when a tool call returns a runnable command proposal.
class AskAiToolSuggestion extends AskAiEvent {
  const AskAiToolSuggestion(this.command);
  final AskAiCommand command;
}

/// Signals that the stream finished successfully.
class AskAiCompleted extends AskAiEvent {
  const AskAiCompleted({
    required this.fullText,
    required this.commands,
    this.reasoningContent,
  });

  final String fullText;
  final List<AskAiCommand> commands;
  final String? reasoningContent;
}

/// Signals that the stream terminated with an error before completion.
class AskAiStreamError extends AskAiEvent {
  const AskAiStreamError(this.error, this.stackTrace);

  final Object error;
  final StackTrace? stackTrace;
}
