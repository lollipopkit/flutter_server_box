import 'dart:convert';

import 'package:meta/meta.dart';

/// API protocol used for one Agent conversation.
enum AskAiProtocol { auto, chatCompletions, responses }

AskAiProtocol parseAskAiProtocol(Object? value) {
  final name = value?.toString();
  return AskAiProtocol.values.firstWhere(
    (protocol) => protocol.name == name,
    orElse: () => AskAiProtocol.auto,
  );
}

enum AskAiMessageRole { user, assistant }

/// Protocol-neutral item stored in an Agent conversation.
///
/// Chat Completions codecs regroup adjacent assistant messages and function
/// calls into a single message. Responses codecs replay the typed output items
/// directly, including encrypted reasoning data when it is available.
@immutable
sealed class AskAiConversationItem {
  const AskAiConversationItem();

  String get persistenceKind;
  int get estimatedCharacters;
  Map<String, dynamic> toJson();

  static AskAiConversationItem? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    return switch (json['kind']) {
      'message' => AskAiMessageItem.fromJson(json),
      'function_call' => AskAiFunctionCallItem.fromJson(json),
      'function_output' => AskAiFunctionOutputItem.fromJson(json),
      'reasoning' => AskAiReasoningItem.fromJson(json),
      'raw_response' => AskAiRawResponseItem.fromJson(json),
      _ => null,
    };
  }
}

@immutable
class AskAiMessageItem extends AskAiConversationItem {
  const AskAiMessageItem({
    required this.role,
    required this.content,
    this.reasoningContent,
    this.rawResponseItem,
  });

  const AskAiMessageItem.user(String content)
    : this(role: AskAiMessageRole.user, content: content);

  const AskAiMessageItem.assistant(
    String content, {
    String? reasoningContent,
    Map<String, dynamic>? rawResponseItem,
  }) : this(
         role: AskAiMessageRole.assistant,
         content: content,
         reasoningContent: reasoningContent,
         rawResponseItem: rawResponseItem,
       );

  factory AskAiMessageItem.fromJson(Map<String, dynamic> json) {
    return AskAiMessageItem(
      role: AskAiMessageRole.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => AskAiMessageRole.user,
      ),
      content: json['content'] as String? ?? '',
      reasoningContent: json['reasoning_content'] as String?,
      rawResponseItem: _mapOrNull(json['raw_response_item']),
    );
  }

  final AskAiMessageRole role;
  final String content;
  final String? reasoningContent;
  final Map<String, dynamic>? rawResponseItem;

  @override
  String get persistenceKind => 'message';

  @override
  int get estimatedCharacters =>
      content.length + (reasoningContent?.length ?? 0);

  @override
  Map<String, dynamic> toJson() => {
    'kind': persistenceKind,
    'role': role.name,
    'content': content,
    if (reasoningContent?.isNotEmpty == true)
      'reasoning_content': reasoningContent,
    if (rawResponseItem != null) 'raw_response_item': rawResponseItem,
  };
}

@immutable
class AskAiFunctionCallItem extends AskAiConversationItem {
  const AskAiFunctionCallItem({
    required this.command,
    this.responseItemId,
    this.rawResponseItem,
  });

  factory AskAiFunctionCallItem.fromJson(Map<String, dynamic> json) {
    return AskAiFunctionCallItem(
      command: AskAiCommand.fromJson(
        Map<String, dynamic>.from(json['command'] as Map? ?? const {}),
      ),
      responseItemId: json['response_item_id'] as String?,
      rawResponseItem: _mapOrNull(json['raw_response_item']),
    );
  }

  final AskAiCommand command;
  final String? responseItemId;
  final Map<String, dynamic>? rawResponseItem;

  @override
  String get persistenceKind => 'function_call';

  @override
  int get estimatedCharacters =>
      command.rawArguments.length + command.description.length;

  @override
  Map<String, dynamic> toJson() => {
    'kind': persistenceKind,
    'command': command.toJson(),
    if (responseItemId != null) 'response_item_id': responseItemId,
    if (rawResponseItem != null) 'raw_response_item': rawResponseItem,
  };
}

@immutable
class AskAiFunctionOutputItem extends AskAiConversationItem {
  const AskAiFunctionOutputItem({required this.callId, required this.output});

  factory AskAiFunctionOutputItem.fromJson(Map<String, dynamic> json) {
    return AskAiFunctionOutputItem(
      callId: json['call_id'] as String? ?? '',
      output: json['output'] as String? ?? '',
    );
  }

  final String callId;
  final String output;

  @override
  String get persistenceKind => 'function_output';

  @override
  int get estimatedCharacters => output.length;

  @override
  Map<String, dynamic> toJson() => {
    'kind': persistenceKind,
    'call_id': callId,
    'output': output,
  };
}

@immutable
class AskAiReasoningItem extends AskAiConversationItem {
  const AskAiReasoningItem({required this.rawResponseItem, this.summaryText});

  factory AskAiReasoningItem.fromJson(Map<String, dynamic> json) {
    return AskAiReasoningItem(
      rawResponseItem: _mapOrNull(json['raw_response_item']) ?? const {},
      summaryText: json['summary_text'] as String?,
    );
  }

  final Map<String, dynamic> rawResponseItem;
  final String? summaryText;

  @override
  String get persistenceKind => 'reasoning';

  @override
  int get estimatedCharacters =>
      jsonEncode(rawResponseItem).length + (summaryText?.length ?? 0);

  @override
  Map<String, dynamic> toJson() => {
    'kind': persistenceKind,
    'raw_response_item': rawResponseItem,
    if (summaryText?.isNotEmpty == true) 'summary_text': summaryText,
  };
}

/// Preserves output item types not yet rendered by ServerBox.
@immutable
class AskAiRawResponseItem extends AskAiConversationItem {
  const AskAiRawResponseItem({required this.rawResponseItem});

  factory AskAiRawResponseItem.fromJson(Map<String, dynamic> json) {
    return AskAiRawResponseItem(
      rawResponseItem: _mapOrNull(json['raw_response_item']) ?? const {},
    );
  }

  final Map<String, dynamic> rawResponseItem;

  @override
  String get persistenceKind => 'raw_response';

  @override
  int get estimatedCharacters => jsonEncode(rawResponseItem).length;

  @override
  Map<String, dynamic> toJson() => {
    'kind': persistenceKind,
    'raw_response_item': rawResponseItem,
  };
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
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

  factory AskAiCommand.fromJson(Map<String, dynamic> json) {
    return AskAiCommand(
      id: json['id'] as String? ?? 'run-shell-command',
      command: json['command'] as String? ?? '',
      description: json['description'] as String? ?? '',
      toolName: json['tool_name'] as String? ?? 'run_shell_command',
      rawArguments: json['raw_arguments'] as String? ?? '',
      modelSafeToRun: json['model_safe_to_run'] as bool? ?? false,
    );
  }

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'command': command,
    'description': description,
    'tool_name': toolName,
    'raw_arguments': rawArguments,
    'model_safe_to_run': modelSafeToRun,
  };

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

  Map<String, dynamic> toResponsesFunctionCallJson({String? itemId}) {
    final arguments = rawArguments.isNotEmpty
        ? rawArguments
        : jsonEncode({
            'command': command,
            'description': description,
            'safe_to_run': modelSafeToRun,
          });
    return {
      if (itemId != null && itemId.isNotEmpty) 'id': itemId,
      'type': 'function_call',
      'call_id': id,
      'name': toolName,
      'arguments': arguments,
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

    bool isReadOnlySegment(String segment) {
      final stripped = segment
          .trim()
          .replaceFirst(RegExp(r'^sudo\s+'), '')
          .replaceFirst(RegExp(r'^(env\s+)?([a-z_][a-z0-9_]*=[^\s]+\s+)+'), '');
      return readOnlyStarts.any((pattern) => pattern.hasMatch(stripped));
    }

    final chainCandidate = normalized.replaceAll(RegExp(r'\d*>&\d+'), '');
    if (RegExp(r'&&|\|\||[;\r\n]|&').hasMatch(chainCandidate)) {
      return AskAiCommandRisk.caution;
    }

    final pipelineSegments = normalized.split('|');
    if (pipelineSegments.every(
      (segment) => segment.trim().isNotEmpty && isReadOnlySegment(segment),
    )) {
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

  static AskAiCommandResult? tryFromToolMessage(
    String message, {
    required String fallbackCommand,
  }) {
    try {
      final json = Map<String, dynamic>.from(jsonDecode(message) as Map);
      if (!json.containsKey('stdout') && !json.containsKey('stderr')) {
        return null;
      }
      final exitCode = json['exit_code'];
      final durationMs = json['duration_ms'];
      return AskAiCommandResult(
        command: json['command'] as String? ?? fallbackCommand,
        exitCode: exitCode is num ? exitCode.toInt() : null,
        stdout: json['stdout'] as String? ?? '',
        stderr: json['stderr'] as String? ?? '',
        duration: Duration(
          milliseconds: durationMs is num ? durationMs.toInt() : 0,
        ),
        cancelled: json['cancelled'] as bool? ?? false,
        timedOut: json['timed_out'] as bool? ?? false,
        truncated: json['output_truncated'] as bool? ?? false,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

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
      'duration_ms': duration.inMilliseconds,
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
    required this.outputItems,
    required this.protocol,
    this.reasoningContent,
    this.responseId,
  });

  final String fullText;
  final List<AskAiCommand> commands;
  final List<AskAiConversationItem> outputItems;
  final AskAiProtocol protocol;
  final String? reasoningContent;
  final String? responseId;
}

/// Signals that the stream terminated with an error before completion.
class AskAiStreamError extends AskAiEvent {
  const AskAiStreamError(this.error, this.stackTrace);

  final Object error;
  final StackTrace? stackTrace;
}
